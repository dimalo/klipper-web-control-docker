# MCU serial / device mapping

Host checklist when Klipper cannot open the printer MCU (`Unable to connect to MCU`, permission errors, missing `/dev/…`).

Related: [#59](https://github.com/dimalo/klipper-web-control-docker/issues/59). Community device-mapping tips on that issue are folded in here.

## CI note

**CI smoke intentionally does not assert MCU ready.** The harness uses a Linux host MCU / no printer USB path ([docs/ci-smoke.md](../ci-smoke.md)). A green Actions run does **not** mean your USB serial mapping works.

## MacOS Docker

Docker Desktop on Mac **cannot** expose serial devices into Linux containers ([docker/for-mac#900](https://github.com/docker/for-mac/issues/900)). Use a Linux host (Pi, NUC, NAS with working USB passthrough) for real printers.

## Checklist

### 1. Device on the host

```bash
ls -l /dev/ttyUSB0 /dev/ttyACM0 2>/dev/null
ls -l /dev/serial/by-id/
```

Prefer a stable **`/dev/serial/by-id/usb-…`** symlink so ports do not jump after replug.

### 2. Map into Compose

Default [`docker-compose.yml`](../../docker-compose.yml) has **no** host `devices:` (so CI and Portainer can validate without USB). Put serial mapping in [`docker-compose.hw.yml`](../../docker-compose.hw.yml) (or your Portainer/NAS stack) and merge:

`docker compose -f docker-compose.yml -f docker-compose.hw.yml up -d`

```yaml
devices:
  # host_path : container_path
  - /dev/serial/by-id/usb-Klipper_…-if00:/dev/ttyUSB0
```

Put the **container** path in `printer.cfg`:

```ini
[mcu]
serial: /dev/ttyUSB0
```

If you map by-id to the same path inside the container, use that path in `serial:` instead.

Missing `devices:` entries (or a Portainer stack that never published them) are a common cause of “no serial” — see also [Portainer](../platforms/portainer.md) (#31 called out missing **7125**; always map the serial device too).

### 3. Permissions / `group_add`

```bash
ls -l /dev/ttyUSB0
# e.g. crw-rw---- 1 root dialout 188, 0 …  → note group name/GID
getent group dialout tty
```

This project’s hardware override uses runtime **`group_add`** with numeric GIDs (see comments in [`docker-compose.hw.yml`](../../docker-compose.hw.yml) / [`docker-compose-adxl345.yml`](../../docker-compose-adxl345.yml)). Uncomment and set GIDs to match the host — **do not** rely on outdated README “build-arg `DEVICE_GID` then rebuild” as the primary fix (legacy image build args may still exist in Dockerfiles; prefer `group_add` on current compose).

```yaml
group_add:
  - "20"    # example — use your host dialout/tty GID
```

Recreate the container after changing `group_add` (`docker compose up -d`).

### 4. Privileged mode (last resort)

Some hosts need `privileged: true` or broad device cgroup rules. Prefer explicit `devices:` + `group_add`. If you use privileged + by-id mapping, note that Compose may fail to start when the printer is unplugged (device missing). Community recipes on #59 document tradeoffs (single-device map vs `/dev` bind).

### 5. Confirm inside the container

```bash
docker exec -it klipper ls -l /dev/ttyUSB0
docker logs klipper 2>&1 | tail -50
```

### 6. Config location

Current images expect config under **`/home/klippy/printer_data/config`** (2.0.0). Ensure `printer.cfg` is that mount, not a leftover `.config` bind — [migration](../migration-printer-data.md).

## Also see

- [README Status / images](../../README.md#status--images) — Hub vs git tags
- [ADXL345](./adxl345.md) — SPI/`SYS_RAWIO` when using accelerometers
- [Unraid](../platforms/unraid.md) / [Synology](../platforms/synology.md) — NAS USB quirks
