# Portainer stack example

Deploy this repo’s published images with **Portainer Stacks** (or any Compose UI). This is **not** a separate Docker Hub “Portainer image” — you pull the same `dimalo/klipper-moonraker` and `dimalo/fluidd` tags used elsewhere.

Related: [#31](https://github.com/dimalo/klipper-web-control-docker/issues/31).

## Images / tags

Git **`main` / `v2.0.0`** ships the `printer_data` layout. Hub tags may lag or differ from git tags — see [README Status / images](../../README.md#status--images) (verify Hub last-pushed / digest; use `latest` or a date tag; no Hub `2.0.0` tag yet).

| Goal | Suggestion |
| --- | --- |
| Match current git `main` | Pull a verified Hub `latest` / date tag, **or** build from this repo |
| Frontend | `dimalo/fluidd` (or build `frontend/`) |

## Stack YAML (paste into Portainer)

A pull-only example lives at [`examples/portainer-stack.yml`](../../examples/portainer-stack.yml). Summary:

- **Moonraker API:** host port **7125** → container `7125`
- **Fluidd UI:** host port **8010** → container `80`
- **No `build:`** — images are pulled
- Volumes use **`printer_data`**: `…/config`, `…/gcodes`, `…/database`
- Serial via `devices:` (edit the host path); optional `group_add` for dialout/tty GIDs

In Portainer: **Stacks → Add stack → Web editor** → paste the YAML → set the bind path for config (or use a named volume) → **Deploy**.

### Serial / permissions

1. On the host: `ls -l /dev/ttyUSB0` (or your device) and note the group GID.
2. Uncomment `group_add` in the stack with that GID if the container user cannot open the device.
3. Put the **container** device path in `printer.cfg` (`[mcu] serial:`). Prefer `/dev/serial/by-id/…` on the host mapped into the container — see [MCU serial checklist](../hardware/mcu-serial.md).

Do **not** leave `privileged: true` on by default; use it only if device cgroup rules/`group_add` are insufficient on your host.

## After deploy

1. Open `http://<host>:8010`
2. Upload or edit `printer.cfg` under the mounted config dir
3. Confirm Moonraker at `http://<host>:7125/server/info`

## Also see

- [Unraid](./unraid.md) / [Synology](./synology.md) — same images, NAS-specific path notes
- [Multi-printer Fluidd](./multi-printer.md) — more than one Moonraker
- [Migrating to printer_data](../migration-printer-data.md)
