#!/usr/bin/env bash
# No-MCU smoke asserts for klipper-web-control-docker.
# Expects kwc-klipper:ci + kwc-fluidd:ci already built and compose stack up.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${ROOT}/docker-compose.ci.yml}"
COMPOSE=(docker compose -f "${COMPOSE_FILE}")
MOONRAKER_URL="${MOONRAKER_URL:-http://127.0.0.1:7125}"
UI_URL="${UI_URL:-http://127.0.0.1:8010}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
RESTART_WAIT_SECONDS="${RESTART_WAIT_SECONDS:-120}"
KLIPPER_CONTAINER="${KLIPPER_CONTAINER:-klipper}"

# Match permission/path failures; callers should strip Moonraker .bkp lines first.
FORBIDDEN_LOG_PATTERN="${FORBIDDEN_LOG_PATTERN:-PermissionError|No such file or directory: '/home/klippy/.config/moonraker.conf'}"

log() { printf ':: %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

json_ok() {
  # Accept Moonraker {"result":...} or bare "ok" / {"result":"ok"}
  local body="$1"
  echo "${body}" | jq -e '
    . == "ok"
    or .result == "ok"
    or (.result != null)
    or (type == "object")
  ' >/dev/null
}

wait_moonraker() {
  local label="${1:-Moonraker}"
  local secs="${2:-${WAIT_SECONDS}}"
  # Logs to stderr so callers can capture JSON-only on stdout.
  log "waiting up to ${secs}s for ${label} ${MOONRAKER_URL}/server/info" >&2
  local deadline=$((SECONDS + secs))
  local body=""
  while (( SECONDS < deadline )); do
    if body="$(curl -sf --max-time 5 "${MOONRAKER_URL}/server/info" 2>/dev/null)"; then
      echo "${body}" | jq -e . >/dev/null || fail "${label}: /server/info not JSON"
      printf '%s\n' "${body}"
      return 0
    fi
    sleep 2
  done
  fail "${label}: /server/info did not return HTTP 200 within ${secs}s"
}

assert_supervisor_running() {
  local label="${1:-supervisor}"
  log "checking supervisorctl status (${label})"
  local status
  status="$(docker exec "${KLIPPER_CONTAINER}" supervisorctl status 2>&1 || true)"
  printf '%s\n' "${status}"
  [[ -n "${status}" ]] || fail "${label}: supervisorctl status empty"
  echo "${status}" | grep -E '^klipper[[:space:]]+' | grep -q RUNNING \
    || fail "${label}: supervisor program 'klipper' not RUNNING"
  echo "${status}" | grep -E '^moonraker[[:space:]]+' | grep -q RUNNING \
    || fail "${label}: supervisor program 'moonraker' not RUNNING"
}

post_json() {
  local url="$1"
  local payload="${2:-}"
  if [[ -n "${payload}" ]]; then
    curl -sf --max-time 15 -X POST \
      -H 'Content-Type: application/json' \
      -d "${payload}" \
      "${url}"
  else
    curl -sf --max-time 15 -X POST "${url}"
  fi
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
  table="$("${COMPOSE[@]}" ps)"
  printf '%s\n' "${table}"
  echo "${table}" | grep -qi klipper || fail "klipper service not listed in compose ps"
  echo "${table}" | grep -qi fluidd || fail "fluidd service not listed in compose ps"
else
  echo "${ps_out}" | jq -s -e '
    (map(select((.Service // .Name // "") | test("klipper"; "i"))) | length) > 0
    and (map(select((.Service // .Name // "") | test("fluidd"; "i"))) | length) > 0
  ' >/dev/null || fail "klipper and/or fluidd missing from compose ps json"
fi

# --- 2/3) wait for Moonraker /server/info ---------------------------------
body="$(wait_moonraker "initial")"
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
sleep 2
assert_supervisor_running "initial"

# --- 7) log gate (pre-management) -----------------------------------------
log "scanning klipper container logs for forbidden patterns (pre-management)"
logs="$(docker logs "${KLIPPER_CONTAINER}" 2>&1 || true)"
filtered="$(echo "${logs}" | grep -v '\.bkp' || true)"
if echo "${filtered}" | grep -E "${FORBIDDEN_LOG_PATTERN}" >/dev/null; then
  echo "${filtered}" | grep -E "${FORBIDDEN_LOG_PATTERN}" | tail -n 20 >&2
  fail "forbidden pattern in container logs: ${FORBIDDEN_LOG_PATTERN}"
fi

# --- 8) hard: config file list (management / file manager) ----------------
log "GET /server/files/list?root=config (hard)"
files="$(curl -sf --max-time 5 "${MOONRAKER_URL}/server/files/list?root=config")" \
  || fail "files/list?root=config failed"
echo "${files}" | jq -e '.result != null or type=="object"' >/dev/null \
  || fail "files/list?root=config unexpected JSON"
if echo "${files}" | jq -e 'tostring | test("moonraker\\.conf|printer\\.cfg|client\\.cfg")' >/dev/null; then
  log "files/list includes expected config filenames"
else
  log "note: listing JSON did not obviously include known filenames (continuing)"
fi


# --- 9) hard: machine/system_info (safe no-MCU) ---------------------------
log "GET /machine/system_info (hard)"
sysinfo="$(curl -sf --max-time 10 "${MOONRAKER_URL}/machine/system_info")" \
  || fail "machine/system_info failed"
echo "${sysinfo}" | jq -e '.result != null or .system_info != null or type=="object"' >/dev/null \
  || fail "machine/system_info unexpected JSON"

# --- 10) hard: restart Klipper via Moonraker machine API ------------------
log "POST /machine/services/restart service=klipper"
RESTART_PAYLOAD='{"service":"klipper"}'
restart_klipper="$(post_json "${MOONRAKER_URL}/machine/services/restart" "${RESTART_PAYLOAD}")" \
  || fail "machine/services/restart klipper failed"
json_ok "${restart_klipper}" || fail "machine/services/restart klipper unexpected body: ${restart_klipper}"
log "restart klipper accepted: ${restart_klipper}"
sleep 3
wait_moonraker "after klipper restart" "${RESTART_WAIT_SECONDS}" >/dev/null
assert_supervisor_running "after klipper restart"
curl -sf --max-time 5 "${UI_URL}/server/info" >/dev/null \
  || fail "UI proxy /server/info failed after klipper restart"

# --- 11) hard: soft-restart Moonraker itself ------------------------------
log "POST /server/restart"
# server/restart often drops the HTTP connection; recover is what matters.
set +e
restart_mr="$(post_json "${MOONRAKER_URL}/server/restart" 2>/dev/null)"
rc=$?
set -e
if [[ ${rc} -eq 0 && -n "${restart_mr}" ]]; then
  log "server/restart response: ${restart_mr}"
else
  log "server/restart returned no body / connection dropped (expected); waiting for recovery"
fi
sleep 3
wait_moonraker "after moonraker restart" "${RESTART_WAIT_SECONDS}" >/dev/null
assert_supervisor_running "after moonraker restart"
curl -sf --max-time 5 "${UI_URL}/server/info" >/dev/null \
  || fail "UI proxy /server/info failed after moonraker restart"

# --- 12) hard: same restart path via Fluidd nginx proxy -------------------
log "POST ${UI_URL}/machine/services/restart service=klipper (via UI proxy)"
proxy_restart="$(post_json "${UI_URL}/machine/services/restart" "${RESTART_PAYLOAD}")" \
  || fail "proxied machine/services/restart klipper failed"
json_ok "${proxy_restart}" || fail "proxied restart unexpected body: ${proxy_restart}"
sleep 3
wait_moonraker "after proxied klipper restart" "${RESTART_WAIT_SECONDS}" >/dev/null
assert_supervisor_running "after proxied klipper restart"

# --- 13) final log gate ---------------------------------------------------
log "scanning klipper container logs for forbidden patterns (final)"
logs="$(docker logs "${KLIPPER_CONTAINER}" 2>&1 || true)"
filtered="$(echo "${logs}" | grep -v '\.bkp' || true)"
if echo "${filtered}" | grep -E "${FORBIDDEN_LOG_PATTERN}" >/dev/null; then
  echo "${filtered}" | grep -E "${FORBIDDEN_LOG_PATTERN}" | tail -n 20 >&2
  fail "forbidden pattern in container logs: ${FORBIDDEN_LOG_PATTERN}"
fi

log "SMOKE OK (no-MCU): info/UI/supervisor + files/list + system_info + klipper restart + moonraker restart + proxied restart"
exit 0
