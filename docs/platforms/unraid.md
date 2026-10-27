# Unraid (Compose Manager)

Run this stack on Unraid with the **Docker Compose Manager** plugin (or Portainer). There is **no** separate Unraid-only image or Community Apps template required.

Related: [#52](https://github.com/dimalo/klipper-web-control-docker/issues/52). Community success notes adapted from **@rmcmilli** (2025-01-28) on that issue; thanks also **@nrgbistro** for pointing at Compose Manager / Portainer.

## Prerequisites

- [Docker Compose Manager](https://forums.unraid.net/topic/114415-plugin-docker-compose-manager/) (or [Portainer](./portainer.md))
- A host share for persistence, e.g. `/mnt/user/appdata/klipper`
- Printer USB/serial visible on the Unraid host (`ls -l /dev/serial/by-id` or `/dev/ttyUSB*`)

## Images

Git **`main`** has the M1 `printer_data` layout. Hub **`dimalo/klipper-moonraker:latest` may still lag** git until republish — check Hub dates, build from this repo into a local registry (as @rmcmilli did), or use a tag you trust.

`dimalo/fluidd` usually pulls fine without a local build.

## Path mappings (`printer_data`)

Prefer mounts that match current [`docker-compose.yml`](../../docker-compose.yml):

| Host (example) | Container |
| --- | --- |
| `/mnt/user/appdata/klipper/config` | `/home/klippy/printer_data/config` |
| named volume or share for gcodes | `/home/klippy/printer_data/gcodes` |
| named volume for Moonraker DB | `/home/klippy/printer_data/database` |

Older community snippets still bind `/home/klippy/.config` — that matches **pre-M1** images only. After upgrading, use `printer_data` and see [migration](../migration-printer-data.md).

Ensure the Unraid user/share permissions allow the container user to read/write the config and gcode paths (ownership/`chmod` on the appdata folder is a common footgun on NAS).

## Compose sketch

```yaml
services:
  klipper:
    image: dimalo/klipper-moonraker:latest   # or local-registry/... if you build
    container_name: klipper
    restart: unless-stopped
    ports:
      - "7125:7125"
    cap_add:
      - SYS_NICE
    # group_add: ["20"]   # host dialout/tty GID from ls -l on the device
    volumes:
      - gcode_files:/home/klippy/printer_data/gcodes
      - /mnt/user/appdata/klipper/config:/home/klippy/printer_data/config
      - moonraker_data:/home/klippy/printer_data/database
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
    # privileged: true   # last resort only; prefer devices + group_add

  fluidd:
    image: dimalo/fluidd:latest
    container_name: fluidd
    restart: unless-stopped
    ports:
      - "8010:80"
    depends_on:
      - klipper
    links:
      - klipper:klipper

volumes:
  gcode_files:
  moonraker_data:
```

Web UI: `http://<unraid-ip>:8010` · Moonraker: port **7125**. Avoid port clashes with other containers.

USB cameras in Fluidd are best-effort on Unraid (reported exception in the 2025 notes); device passthrough for `/dev/video*` is optional and separate from printing.

## Serial / privileges

See [MCU serial checklist](../hardware/mcu-serial.md). Prefer explicit `devices:` + `group_add` over blanket `privileged: true`.

## Uploads / paths after M1

G-code upload and config-path bugs tracked in [#41](https://github.com/dimalo/klipper-web-control-docker/issues/41) / [#63](https://github.com/dimalo/klipper-web-control-docker/issues/63) should be retested on **post-M1 git `main`** (and Hub `latest` once republished). If you still run an old image with `.config` mounts, migrate first.

## Also see

- [Synology](./synology.md) — shared NAS ownership tips
- [Portainer](./portainer.md) — paste-ready stack YAML
