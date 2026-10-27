# CI smoke harness (no MCU)

Phase 0 verification loop for this repo: **build images → compose up → assert HTTP + supervisor**, without a printer.

## What “green” means

| Check | Pass criteria |
| --- | --- |
| Moonraker | `GET http://127.0.0.1:7125/server/info` → HTTP 200 + JSON |
| Fluidd UI | `GET http://127.0.0.1:8010/` → HTTP 200 |
| Nginx → Moonraker | `GET http://127.0.0.1:8010/server/info` → HTTP 200 |
| Supervisor | `klipper` and `moonraker` programs **RUNNING** |
| Logs | No `PermissionError` / stale `.config/moonraker.conf` path errors |

**Not** asserted in CI: `klippy_state == ready`, homing, printing, ADXL, webcams.

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

CI configs live under `config/ci/` (dummy MCU serial path, `provider: none` for Moonraker).

## GitHub Actions

Workflow: `.github/workflows/ci-smoke.yml` — runs on pushes/PRs to `develop` / `main` and `cursor/**` branches. Builds both images, brings the stack up, runs `scripts/ci-smoke.sh`, dumps logs on failure.

Core image builds clone upstream Klipper/Moonraker and can take **tens of minutes** on a cold runner.
