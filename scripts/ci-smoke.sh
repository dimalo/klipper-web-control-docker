#!/usr/bin/env bash
# Phase 0 / M0 no-MCU smoke asserts for klipper-web-control-docker.
# Expects kwc-klipper:ci + kwc-fluidd:ci already built and compose stack up
# (or set SKIP_COMPOSE_CHECK=1 after manual up).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${ROOT}/docker-compose.ci.yml}"
COMPOSE=(docker compose -f "${COMPOSE_FILE}")
MOONRAKER_URL="${MOONRAKER_URL:-http://127.0.0.1:7125}"
UI_URL="${UI_URL:-http://127.0.0.1:8010}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
KLIPPER_CONTAINER="${KLIPPER_CONTAINER:-klipper}"

FORBIDDEN_LOG_PATTERN="${FORBIDDEN_LOG_PATTERN:-PermissionError|No such file or directory: '/home/klippy/.config/moonraker.conf'}"

log() { printf ':: %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

need_cmd docker
need_cmd curl
need_cmd jq

log "compose file: ${COMPOSE_FILE}"
log "moonraker: ${MOONRAKER_URL}"
log "ui: ${UI_URL}"

# --- 1) containers present -------------------------------------------------
log "checking containers are up"
ps_out="$("${COMPOSE[@]}" ps --format json 2>/dev/null || true)"
if [[ -z "${ps_out}" ]]; then
  # older compose: table format fallback
  table="$("${COMPOSE[@]}" ps)"
  printf '%s\n' "${table}"
  echo "${table}" | grep -qi klipper || fail "klipper service not listed in compose ps"
  echo "${table}" | grep -qi fluidd || fail "fluidd service not listed in compose ps"
else
  # compose may emit one JSON object per line
  echo "${ps_out}" | jq -s -e '
    (map(select((.Service // .Name // "") | test("klipper"; "i"))) | length) > 0
    and (map(select((.Service // .Name // "") | test("fluidd"; "i"))) | length) > 0
  ' >/dev/null || fail "klipper and/or fluidd missing from compose ps json"
fi

# --- 2/3) wait for Moonraker /server/info ---------------------------------
log "waiting up to ${WAIT_SECONDS}s for Moonraker /server/info"
deadline=$((SECONDS + WAIT_SECONDS))
body=""
while (( SECONDS < deadline )); do
  if body="$(curl -sf --max-time 5 "${MOONRAKER_URL}/server/info" 2>/dev/null)"; then
    break
  fi
  sleep 2
done
[[ -n "${body}" ]] || fail "Moonraker /server/info did not return HTTP 200 within ${WAIT_SECONDS}s"

echo "${body}" | jq -e . >/dev/null || fail "Moonraker /server/info body is not JSON"
# Print useful fields when present (schema varies by Moonraker version)
log "Moonraker /server/info:"
echo "${body}" | jq '{
  klippy_connected: (.result.klippy_connected // .klippy_connected // null),
  klippy_state: (.result.klippy_state // .klippy_state // null),
  moonraker_version: (.result.moonraker_version // .moonraker_version // null)
}' || true

# --- 4) frontend proxies /server/info -------------------------------------
log "checking UI proxy ${UI_URL}/server/info"
proxy_body="$(curl -sf --max-time 5 "${UI_URL}/server/info")" \
  || fail "UI proxy /server/info failed (frontend→Moonraker wiring)"
echo "${proxy_body}" | jq -e . >/dev/null || fail "UI proxy /server/info not JSON"

# --- 5) UI static ---------------------------------------------------------
log "checking UI static ${UI_URL}/"
code="$(curl -sf -o /dev/null -w '%{http_code}' --max-time 5 "${UI_URL}/")" \
  || fail "UI root request failed"
[[ "${code}" == "200" ]] || fail "UI root expected HTTP 200, got ${code}"

# --- 6) supervisor programs RUNNING ---------------------------------------
log "checking supervisorctl status in ${KLIPPER_CONTAINER}"
# Allow a short settle after Moonraker HTTP became ready
sleep 2
status="$(docker exec "${KLIPPER_CONTAINER}" supervisorctl status)" || fail "supervisorctl status failed"
printf '%s\n' "${status}"

echo "${status}" | grep -E '^klipper\s+' | grep -q RUNNING \
  || fail "supervisor program 'klipper' not RUNNING"
echo "${status}" | grep -E '^moonraker\s+' | grep -q RUNNING \
  || fail "supervisor program 'moonraker' not RUNNING"

# --- 7) log gate ----------------------------------------------------------
log "scanning klipper container logs for forbidden patterns"
logs="$(docker logs "${KLIPPER_CONTAINER}" 2>&1 || true)"
if echo "${logs}" | grep -E "${FORBIDDEN_LOG_PATTERN}" >/dev/null; then
  echo "${logs}" | grep -E "${FORBIDDEN_LOG_PATTERN}" | tail -n 20 >&2
  fail "forbidden pattern in container logs: ${FORBIDDEN_LOG_PATTERN}"
fi

# --- 8) optional file API (soft) ------------------------------------------
log "optional: config file list API (soft)"
if files="$(curl -sf --max-time 5 "${MOONRAKER_URL}/server/files/list?root=config" 2>/dev/null)"; then
  echo "${files}" | jq -e . >/dev/null && log "files/list?root=config OK" || log "files/list returned non-JSON (soft)"
else
  log "files/list?root=config not available yet (soft — not failing)"
fi

log "SMOKE OK (no-MCU): Moonraker HTTP 200, UI 200, proxy /server/info 200, supervisor RUNNING, log gates clean"
exit 0
