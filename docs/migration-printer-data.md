# Migrating to `printer_data` (main / post-develop ship)

This release brings the long-running **`develop`** line onto **`main`**, including Moonraker’s standard **`printer_data`** layout and the [CI smoke harness](./ci-smoke.md).

If you still run an older image that used `/home/klippy/.config` and `/home/klippy/gcode_files`, update host mounts and configs before pulling `latest`.

## Path mapping

| Role | Old (`main` ≤ 2022 / Hub `latest` ≤ 2023-06) | New (`develop` / this ship) |
| --- | --- | --- |
| Config dir | `/home/klippy/.config` | `/home/klippy/printer_data/config` |
| G-code / virtual SD | `/home/klippy/gcode_files` | `/home/klippy/printer_data/gcodes` |
| Moonraker data dir | (varied) | `-d /home/klippy/printer_data` inside the image |
| Database volume (compose) | `moonraker_data:/home/klippy/.moonraker_database` | same mount path in current compose (unchanged for now) |

## Compose changes

Update volume binds to match current [`docker-compose.yml`](../docker-compose.yml):

```yaml
volumes:
  - gcode_files:/home/klippy/printer_data/gcodes
  - ./config:/home/klippy/printer_data/config
  - moonraker_data:/home/klippy/.moonraker_database
```

If you previously mounted:

```yaml
- ./config:/home/klippy/.config
- gcode_files:/home/klippy/gcode_files
```

switch to the new targets **before** recreating containers.

## Config file edits

1. **`[virtual_sdcard]`** — set `path:` to `/home/klippy/printer_data/gcodes` (see `config/client.cfg`).
2. **Includes / printer.cfg** — keep files under the mounted config directory (now `printer_data/config`).
3. **Moonraker** — prefer the repo’s `config/moonraker.conf`; drop obsolete `config_path` / `database_path` keys if you still carry an ancient conf.
4. **Host MCU** — `config/host_mcu.cfg` still expects `/tmp/klipper_host_mcu` when enabled; that is separate from USB printer serial.

## Upgrade procedure (recommended)

```bash
# 1) Stop stack
docker compose down

# 2) Backup host config + gcodes
cp -a ./config "./config.backup-$(date +%Y%m%d)"
# if you used a named volume for gcodes, back it up too

# 3) Pull this release (after merge) or rebuild
git pull   # or checkout the shipped main
# Edit compose mounts as above if you have a custom override

# 4) Pull/build images and start
docker compose pull   # or: docker compose build
docker compose up -d

# 5) Optional no-MCU sanity check (no printer required)
DOCKER_BUILDKIT=1 docker build -f klipper/Dockerfile -t kwc-klipper:ci .
DOCKER_BUILDKIT=1 docker build -f frontend/Dockerfile -t kwc-fluidd:ci ./frontend
docker compose -f docker-compose.ci.yml up -d
bash scripts/ci-smoke.sh
docker compose -f docker-compose.ci.yml down -v
```

## What this ship does *not* do by itself

- Publish to Docker Hub happens via the existing multiarch workflows when `main`/`develop` builds succeed with Hub credentials configured.
- Hardware MCU connect, ADXL345, Unraid/Synology UX — see follow-up milestones / issue triage; use the [hardware smoke checklist](./ci-smoke.md) ideas after upgrade.

## Related issues

Path/upload/permission tickets that should be retested after this ship: #41, #44, #45, #47, #50, #57, #63 (see project issue triage).