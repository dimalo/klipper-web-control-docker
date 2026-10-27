#!/usr/bin/env bash
# Migrate host compose + Klipper configs from legacy paths to printer_data.
#
# Legacy:
#   /home/klippy/.config
#   /home/klippy/gcode_files
# New:
#   /home/klippy/printer_data/config
#   /home/klippy/printer_data/gcodes
#
# Usage:
#   ./scripts/migrate-printer-data.sh           # dry-run (default)
#   ./scripts/migrate-printer-data.sh --apply  # write changes + backups
#   ./scripts/migrate-printer-data.sh --apply --root /path/to/checkout
#
# Does NOT pull images or restart containers — stop the stack yourself first.
set -euo pipefail

APPLY=0
ROOT=""
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --root) ROOT="${2:?}"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1" >&2; usage 1 ;;
  esac
done

if [[ -z "${ROOT}" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
ROOT="$(cd "${ROOT}" && pwd)"

log() { printf ':: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -d "${ROOT}" ]] || die "root not found: ${ROOT}"

BACKUP_DIR="${ROOT}/.migration-backup-${TIMESTAMP}"
CHANGED=0
PLANNED=0

backup_file() {
  local src="$1"
  local rel="${src#"${ROOT}"/}"
  local dest="${BACKUP_DIR}/${rel}"
  mkdir -p "$(dirname "${dest}")"
  cp -a "${src}" "${dest}"
  log "backup: ${rel} -> ${dest#"${ROOT}"/}"
}

# Rewrite a text file with sed expressions; dry-run prints a unified diff when possible.
rewrite_file() {
  local file="$1"
  shift
  [[ -f "${file}" ]] || return 0

  local tmp
  tmp="$(mktemp)"
  # shellcheck disable=SC2068
  sed "$@" "${file}" >"${tmp}"

  if cmp -s "${file}" "${tmp}"; then
    rm -f "${tmp}"
    return 0
  fi

  PLANNED=$((PLANNED + 1))
  log "change: ${file#"${ROOT}"/}"
  if command -v diff >/dev/null 2>&1; then
    diff -u "${file}" "${tmp}" | sed 's/^/    /' || true
  fi

  if [[ "${APPLY}" -eq 1 ]]; then
    backup_file "${file}"
    cat "${tmp}" >"${file}"
    CHANGED=$((CHANGED + 1))
  fi
  rm -f "${tmp}"
}

log "root: ${ROOT}"
if [[ "${APPLY}" -eq 1 ]]; then
  log "mode: APPLY (backups under ${BACKUP_DIR#"${ROOT}"/})"
  mkdir -p "${BACKUP_DIR}"
else
  log "mode: DRY-RUN (pass --apply to write)"
fi

# --- Compose volume path rewrites ------------------------------------------
compose_files=()
for f in docker-compose.yml docker-compose.yaml docker-compose-adxl345.yml \
         compose.yml compose.yaml; do
  [[ -f "${ROOT}/${f}" ]] && compose_files+=("${ROOT}/${f}")
done

# Also scan custom overrides next to the repo root
shopt -s nullglob
for f in "${ROOT}"/docker-compose*.yml "${ROOT}"/docker-compose*.yaml; do
  case " ${compose_files[*]} " in
    *" ${f} "*) ;;
    *) compose_files+=("${f}") ;;
  esac
done
shopt -u nullglob

if [[ ${#compose_files[@]} -eq 0 ]]; then
  warn "no compose files found under ${ROOT}"
fi

for compose in "${compose_files[@]}"; do
  rewrite_file "${compose}" \
    -e 's|/home/klippy/\.config|/home/klippy/printer_data/config|g' \
    -e 's|/home/klippy/gcode_files|/home/klippy/printer_data/gcodes|g'
done

# --- Klipper config: virtual_sdcard path -----------------------------------
shopt -s nullglob
cfg_files=("${ROOT}/config"/*.cfg "${ROOT}/config"/*.conf)
shopt -u nullglob

for cfg in "${cfg_files[@]:-}"; do
  [[ -f "${cfg}" ]] || continue
  # Only rewrite gcode_files virtual_sdcard paths (and bare legacy absolute paths)
  rewrite_file "${cfg}" \
    -e 's|path:[[:space:]]*/home/klippy/gcode_files|path: /home/klippy/printer_data/gcodes|g' \
    -e 's|path:[[:space:]]*~/gcode_files|path: /home/klippy/printer_data/gcodes|g'
done

# --- Moonraker: drop obsolete path keys that conflict with -d printer_data -
moonraker_conf="${ROOT}/config/moonraker.conf"
if [[ -f "${moonraker_conf}" ]]; then
  tmp="$(mktemp)"
  # Remove standalone config_path / database_path assignment lines (legacy)
  awk '
    BEGIN { skip=0 }
    /^[[:space:]]*config_path[[:space:]]*:/ { next }
    /^[[:space:]]*database_path[[:space:]]*:/ { next }
    { print }
  ' "${moonraker_conf}" >"${tmp}"
  if ! cmp -s "${moonraker_conf}" "${tmp}"; then
    PLANNED=$((PLANNED + 1))
    log "change: config/moonraker.conf (drop legacy config_path/database_path lines)"
    if command -v diff >/dev/null 2>&1; then
      diff -u "${moonraker_conf}" "${tmp}" | sed 's/^/    /' || true
    fi
    if [[ "${APPLY}" -eq 1 ]]; then
      backup_file "${moonraker_conf}"
      cat "${tmp}" >"${moonraker_conf}"
      CHANGED=$((CHANGED + 1))
    fi
  fi
  rm -f "${tmp}"
fi

# --- Summary / next steps --------------------------------------------------
echo
if [[ "${APPLY}" -eq 0 ]]; then
  if [[ "${PLANNED}" -eq 0 ]]; then
    log "DRY-RUN: nothing to change (already migrated or no legacy paths found)"
  else
    log "DRY-RUN: ${PLANNED} file(s) would change. Re-run with --apply after docker compose down."
  fi
else
  log "APPLY: ${CHANGED} file(s) updated; backups in ${BACKUP_DIR#"${ROOT}"/}"
fi

cat <<EOF

Next steps:
  1) docker compose down
  2) Review diffs / backups
  3) docker compose pull   # or build
  4) docker compose up -d
  5) Optional: bash scripts/ci-smoke.sh (after building kwc-*:ci tags)

See docs/migration-printer-data.md for path mapping details.
EOF