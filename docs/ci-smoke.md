# CI smoke harness (no MCU)

Verification loop for this repo: **build images → compose up → assert HTTP, supervisor, file/upload paths, management APIs, and restarts**, without a printer.

## What “green” means

| Check | Pass criteria |
| --- | --- |
| Moonraker | `GET /server/info` → HTTP 200 + JSON |
| Fluidd UI | `GET /` → HTTP 200 |
| Nginx → Moonraker | `GET /server/info` via UI port → HTTP 200 |
| Supervisor | `klipper` and `moonraker` programs **RUNNING** |
| Logs | No permission errors on `moonraker.conf` / stale `.config/` paths (`.bkp` write noise ignored) |
| Files API | `GET /server/files/list?root=config` and `?root=gcodes` → HTTP 200 + JSON (#41/#63 path gates) |
| Upload (soft) | `POST /server/files/upload` of a tiny gcode → logs OK/soft-fail (not a hard gate yet) |
| Machine info | `GET /machine/system_info` → HTTP 200 + JSON |
| Restart Klipper | `POST /machine/services/restart` `{"service":"klipper"}` → accepted; then `/server/info` 200 and supervisor RUNNING again |
| Restart Moonraker | `POST /server/restart` → process recovers; `/server/info` 200 and supervisor RUNNING again |
| Proxied restart | Same Klipper restart through Fluidd Nginx (`UI/machine/services/restart`) |

**Out of scope (no MCU / not asserted):**

- `klippy_state == ready`
- Homing, printing, extrusion, bed mesh
- ADXL345 / SPI / GPIO
- Webcam / mjpg-streamer healthy
- Host reboot/shutdown (`/machine/reboot`, `/machine/shutdown`)
- Firmware flash / update_manager installs

## CI Moonraker machine provider

`config/ci/moonraker.conf` sets:

```ini
[machine]
provider: supervisord_cli
supervisord_config_path: /etc/supervisor/supervisord.conf
```

`provider: none` disables `/machine/services/*` (Fluidd “Restart Klipper”), so CI uses `supervisord_cli` like the shipped compose stack.

## Why a standalone compose file?

`docker-compose.ci.yml` is **standalone** (not merged with `docker-compose.yml`) so host `devices:` (e.g. `/dev/ttyUSB0`) are never required on GitHub Actions runners.

Fluidd uses `network_mode: service:klipper` with `KLIPPER_HOST=127.0.0.1` so the Nginx→Moonraker proxy is exercised without depending on Docker bridge inter-container connectivity. Port **8010** is published on the `klipper` service for that shared network namespace.

## Local run

From the repo root (needs Docker + Compose v2, `curl`, `jq`):

```bash
DOCKER_BUILDKIT=1 docker build -f klipper/Dockerfile -t kwc-klipper:ci .
DOCKER_BUILDKIT=1 docker build -f frontend/Dockerfile -t kwc-fluidd:ci ./frontend
docker compose -f docker-compose.ci.yml up -d
bash scripts/ci-smoke.sh
docker compose -f docker-compose.ci.yml down -v
```

## GitHub Actions

Workflow: `.github/workflows/ci-smoke.yml` — runs on pushes/PRs to `develop` / `main` and `cursor/**` branches. Builds both images, brings the stack up, runs `scripts/ci-smoke.sh`, dumps logs on failure.

Core image builds clone upstream Klipper/Moonraker and can take **tens of minutes** on a cold runner.
