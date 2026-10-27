# Migrating to `printer_data` (main / 2.0.0)

**2.0.0** on **`main`** uses Moonraker’s standard **`printer_data`** layout (plus the [CI smoke harness](./ci-smoke.md)). Release notes: [`CHANGELOG.md`](../CHANGELOG.md) · [v2.0.0](https://github.com/dimalo/klipper-web-control-docker/releases/tag/v2.0.0).

If you still run an older image that used `/home/klippy/.config` and `/home/klippy/gcode_files`, update host mounts and configs **before** pulling a current image. Hub tags may differ from git tags — see [README Status / images](../README.md#status--images) (prefer `latest` or a date tag; there is no Hub `2.0.0` tag yet).

## Path mapping

| Role | Old (pre-2.0.0 / Hub `latest` ≤ 2023-06) | New (`main` / 2.0.0) |
| --- | --- | --- |
| Config dir | `/home/klippy/.config` | `/home/klippy/printer_data/config` |
| G-code / virtual SD | `/home/klippy/gcode_files` | `/home/klippy/printer_data/gcodes` |
| Moonraker data dir | (varied) | `-d /home/klippy/printer_data` inside the image |
| Database volume (compose) | `moonraker_data:/home/klippy/.moonraker_database` | `moonraker_data:/home/klippy/printer_data/database` |

Do **not** keep leftover `.config` / `gcode_files` binds with current images.

## Compose changes

Update volume binds to match current [`docker-compose.yml`](../docker-compose.yml):

```yaml
volumes:
  - gcode_files:/home/klippy/printer_data/gcodes
  - ./config:/home/klippy/printer_data/config
  - moonraker_data:/home/klippy/printer_data/database
```

If you previously mounted:

```yaml
- ./config:/home/klippy/.config
- gcode_files:/home/klippy/gcode_files
# and/or:
- moonraker_data:/home/klippy/.moonraker_database
```

switch to the new targets **before** recreating containers. Re-pointing the database volume to `printer_data/database` starts a **new** Moonraker DB location inside the container; copy or accept a fresh DB if you relied on the old path.

## Config file edits

1. **`[virtual_sdcard]`** — set `path:` to `/home/klippy/printer_data/gcodes` (see `config/client.cfg`).
2. **Includes / printer.cfg** — keep files under the mounted config directory (`printer_data/config`).
3. **Moonraker** — prefer the repo’s `config/moonraker.conf`; drop obsolete `config_path` / `database_path` keys if you still carry an ancient conf.
4. **Host MCU** — `config/host_mcu.cfg` still expects `/tmp/klipper_host_mcu` when enabled; that is separate from USB printer serial.

## Convenient migration script

Use [`scripts/migrate-printer-data.sh`](../scripts/migrate-printer-data.sh) to rewrite compose volume targets, `virtual_sdcard` paths, and drop legacy Moonraker `config_path` / `database_path` lines.

```bash
# Preview (no writes)
./scripts/migrate-printer-data.sh

# Stop the stack, then apply (writes + timestamped backups under .migration-backup-*)
docker compose down
./scripts/migrate-printer-data.sh --apply
```

Optional: `--root /path/to/checkout` if you are not running from the repo root. The script does **not** pull images or start containers.

## Upgrade procedure (recommended)

```bash
# 1) Stop stack
docker compose down

# 2) Preview + apply path migration (backs up touched files)
./scripts/migrate-printer-data.sh
./scripts/migrate-printer-data.sh --apply

# Optional extra full-tree backup of config/
cp -a ./config "./config.backup-$(date +%Y%m%d)"

# 3) Update checkout
git pull   # or checkout v2.0.0 / main

# 4) Pull/build images and start (verify Hub digest/date first — README Status)
docker compose pull   # or: docker compose build
docker compose up -d

# 5) Optional no-hardware sanity check (host MCU CI stack — not plain compose)
#    See docs/ci-smoke.md
```

## What this release does *not* do by itself

- Hub publish is separate from the git tag; confirm [Hub tags](https://hub.docker.com/r/dimalo/klipper-moonraker/tags) (or build from this repo) before `docker compose pull` on a printer host.
- Hardware MCU connect, ADXL345, Unraid/Synology UX — see [hardware](./hardware/mcu-serial.md) / [platforms](./platforms/portainer.md); use [CI smoke](./ci-smoke.md) only as a no-USB stack check.

## Related issues

Path/upload/permission tickets that should be retested after 2.0.0: #41, #44, #45, #47, #50, #57, #63.
