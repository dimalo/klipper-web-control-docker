# Synology NAS (Container Manager)

Run Klipper + Moonraker + Fluidd on DSM with **Container Manager** (Docker) and Compose. There is **no** Synology-specific package or Hub image for this project.

Related: [#53](https://github.com/dimalo/klipper-web-control-docker/issues/53).

## Prerequisites

- DSM with Container Manager (or Docker package) and Compose support
- Shared folder for config/gcodes, e.g. `/volume1/docker/klipper`
- USB printer attached to the NAS (if DSM exposes the serial device — see caveats below)

## Images / tags

Git **`main` / `v2.0.0`** ships `printer_data`. Hub tags may lag git — see [README Status / images](../../README.md#status--images). Build from this repository on an amd64/arm64 host and load the image onto the NAS if you prefer not to trust Hub.

Frontend: `dimalo/fluidd`.

## Compose / Container Manager

Create a project from Compose (same shape as [Unraid](./unraid.md) and [`examples/portainer-stack.yml`](../../examples/portainer-stack.yml)):

| Role | Host port | Notes |
| --- | --- | --- |
| Moonraker | **7125** | Required for API / Fluidd proxy |
| Fluidd | **8010** → `80` | Web UI |

Volume targets (`printer_data`):

```yaml
volumes:
  - /volume1/docker/klipper/gcodes:/home/klippy/printer_data/gcodes
  - /volume1/docker/klipper/config:/home/klippy/printer_data/config
  - moonraker_data:/home/klippy/printer_data/database
```

Do **not** use legacy `/home/klippy/.config` mounts with current images. Migration: [printer_data](../migration-printer-data.md).

### Ownership

Synology shared-folder ACLs often leave bind mounts not writable by the container user. Align ownership/`chmod` on the host paths (same class of issue as Unraid appdata — see [Unraid](./unraid.md)). Retest uploads after fixing ownership ([#41](https://github.com/dimalo/klipper-web-control-docker/issues/41) / [#63](https://github.com/dimalo/klipper-web-control-docker/issues/63)).

## USB / serial on DSM

Device passthrough on Synology is **host- and DSM-version dependent**:

1. Confirm the device exists on the NAS OS: `ls -l /dev/ttyUSB* /dev/ttyACM* /dev/serial/by-id/` (SSH).
2. Map it under `devices:` in Compose (Container Manager → project → edit).
3. Match GIDs with `group_add` if permission denied — [MCU serial](../hardware/mcu-serial.md).
4. Some DSM builds restrict USB serial to containers; if the device never appears in the container, that is a platform limit — not fixed by a different Hub tag.

Prefer `/dev/serial/by-id/…` on the host so reconnects keep a stable path.

## After deploy

1. Open `http://<nas-ip>:8010`
2. Place `printer.cfg` in the mounted config directory
3. Confirm `http://<nas-ip>:7125/server/info`

Retest on images from current **`main`** (or a Hub tag you verified). Hardware and DSM USB behavior are **not** covered by GitHub Actions smoke.

## Also see

- [Unraid](./unraid.md) — Compose Manager notes and community volume tips
- [Portainer](./portainer.md) — if you run Portainer on the NAS instead of Container Manager UI
