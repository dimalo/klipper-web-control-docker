# CI smoke harness (Linux host MCU, no printer)

Verification loop for this repo (gate for PRs / pushes to **`main`**): **build images → compose up → assert HTTP, Linux host MCU, healthier Klippy, file/upload paths, management APIs, and restarts**, without USB printer hardware.

This harness does **not** prove Docker Hub digests match git — see [README Status / images](../README.md#status--images). Prefer building local `:ci` tags (below) or retagging a Hub image you already verified.

**No-hardware getting started:** use this stack when you need Fluidd ↔ Moonraker with **Klippy Ready**. Plain `docker compose up` (default compose, no host MCU override) is not a reliable ready-UI path — see README Quickstart.

## Host MCU in CI

CI does **not** use a dummy missing serial. Instead:

| Piece | CI behavior |
| --- | --- |
| `klipper_mcu` | Started by supervisord (`ci/supervisor/klipper_mcu.ini`). Runs **without** `-r` because many CI/Docker hosts reject `sched_setscheduler` even with `SYS_NICE`. |
| Socket | `/tmp/klipper_host_mcu` (same path as `config/host_mcu.cfg`) |
| `config/ci/printer.cfg` | Primary `[mcu]` → `serial: /tmp/klipper_host_mcu`, `kinematics: none` |
| Klipper start order | `ci/supervisor/klipper.ini` waits for `klipper_mcu:running` before starting Klipper |

## What “green” means

| Check | Pass criteria |
| --- | --- |
| Moonraker | `GET /server/info` → HTTP 200 + JSON |
| Supervisor | `klipper_mcu`, `klipper`, and `moonraker` programs **RUNNING** |
| Host MCU socket | `/tmp/klipper_host_mcu` exists inside the klipper container |
| Klippy healthy | `klippy_connected == true` **and** `klippy_state` in `{ready, startup}` (script prefers `ready`; accepts `startup` at deadline) — asserted after boot **and** after each restart recovery |
| Fluidd UI | `GET /` → HTTP 200 |
| Nginx → Moonraker | `GET /server/info` via UI port → HTTP 200 |
| Logs | No permission errors on `moonraker.conf` / stale `.config/` paths (`.bkp` write noise ignored) |
| Files API | `GET /server/files/list?root=config` and `?root=gcodes` → HTTP 200 + JSON (#41/#63 path gates) |
| Upload (soft) | `POST /server/files/upload` of a tiny gcode → logs OK/soft-fail (not a hard gate yet) |
| Machine info | `GET /machine/system_info` → HTTP 200 + JSON |
| Restart Klipper | `POST /machine/services/restart` `{"service":"klipper"}` → accepted; then Moonraker up, supervisor RUNNING, host MCU socket present, Klippy healthy again |
| Restart Moonraker | `POST /server/restart` → process recovers; Klippy healthy again |
| Proxied restart | Same Klipper restart through Fluidd Nginx (`UI/machine/services/restart`) + Klippy healthy |

**Out of scope (not asserted):**

- Homing, printing, extrusion, bed mesh
- ADXL345 / SPI / GPIO bit-banging beyond host MCU process stay-up
- Webcam / mjpg-streamer healthy
- Host reboot/shutdown (`/machine/reboot`, `/machine/shutdown`)
- Firmware flash / Update Manager installs (stock conf omits `[update_manager]`; see [docs/updates.md](./updates.md))
- Realtime scheduling for `klipper_mcu` (`-r` / `SCHED_FIFO`)
- Full printer macros — CI mounts `config/ci/`, whose `client_macros.cfg` is a stub (no `CANCEL_PRINT`). Fluidd may warn about missing macros; that is expected for this demo, not a Moonraker outage. Default `./config` mounts include the real macros.

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

To exercise published Hub images instead of a local build, pull + retag then run the same compose/smoke commands:

```bash
docker pull dimalo/klipper-moonraker:latest
docker pull dimalo/fluidd:latest
docker tag dimalo/klipper-moonraker:latest kwc-klipper:ci
docker tag dimalo/fluidd:latest kwc-fluidd:ci
```

## GitHub Actions

Workflow: `.github/workflows/ci-smoke.yml` — runs on pushes/PRs to `develop` / `main` and `cursor/**` branches. Builds both images, brings the stack up, runs `scripts/ci-smoke.sh`, dumps logs on failure. A green Actions run validates the **git tree under test**, not Hub tag freshness.

Core image builds clone upstream Klipper/Moonraker and can take **tens of minutes** on a cold runner.
