![Mainsail Multiarch Image CI](https://github.com/dimalo/klipper-web-control-docker/workflows/Mainsail%20Multiarch%20Image%20CI/badge.svg)
![Klipper Moonraker Multiarch Image CI](https://github.com/dimalo/klipper-web-control-docker/workflows/Klipper%20Moonraker%20Multiarch%20Image%20CI/badge.svg)

- [klipper-web-control-docker](#klipper-web-control-docker)
  - [Status / images](#status--images)
  - [Quickstart](#quickstart)
  - [Docs map](#docs-map)
  - [Features](#features)
  - [Credits](#credits)

# klipper-web-control-docker

__Klipper with Moonraker shipped with Fluidd and/or Mainsail__

## Status / images

> **Git** [`main`](https://github.com/dimalo/klipper-web-control-docker) / tag [`v2.0.0`](https://github.com/dimalo/klipper-web-control-docker/releases/tag/v2.0.0) is the source of truth for layout, Compose, and docs. Release notes: [`CHANGELOG.md`](./CHANGELOG.md).
>
> **Docker Hub** [`dimalo/klipper-moonraker:latest`](https://hub.docker.com/r/dimalo/klipper-moonraker/tags) was republished with the 2.0.0 line (post-[#75](https://github.com/dimalo/klipper-web-control-docker/pull/75), 2026-10-27). There is **no** Hub tag named `2.0.0` yet — pull **`latest`** or a **date tag** (e.g. `20261027-1727`), and still check Hub **last-pushed / digest** before trusting a printer host. Git tags and Hub tags are not the same channel until a version tag exists on Hub.
>
> Prefer build-from-repo when you need a known git SHA. Frontend Hub tags (`dimalo/fluidd`, `dimalo/mainsail`) can move on a different cadence than the core image — pin/verify **core** explicitly. `:next` is optional interim; date-check it the same way.
>
> Paths use Moonraker’s **`printer_data`** layout. Upgrading from `/home/klippy/.config`? → [docs/migration-printer-data.md](./docs/migration-printer-data.md).

## Quickstart

**Prerequisites:** Linux or MacOS host with Docker Compose v2; printer firmware flashed; serial device known (e.g. `/dev/ttyUSB0`). MacOS cannot pass serial into containers ([docker/for-mac#900](https://github.com/docker/for-mac/issues/900)) — see [docs/hardware/mcu-serial.md](./docs/hardware/mcu-serial.md).

1. Clone this repo and adjust Compose (serial in [`docker-compose.hw.yml`](./docker-compose.hw.yml); optional `printer.cfg` mount under `printer_data/config`).
2. **With a real printer:**

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.hw.yml pull
   docker compose -f docker-compose.yml -f docker-compose.hw.yml up
   ```

   Omit `pull` to build from this repo’s Dockerfiles instead.
3. **Ports:** Moonraker **7125**, Fluidd **8010**. Mainsail **8011** only after you uncomment the `mainsail` service in [`docker-compose.yml`](./docker-compose.yml) (commented out by default).
4. Open http://localhost:8010 — upload/edit `printer.cfg`, confirm Klipper connects to the MCU.

**No printer hardware?** Plain `docker compose up` brings containers up for editing configs, but it is **not** a reliable “Klippy Ready / Fluidd proxy works” path (stock config has no primary printer MCU; default `klipper_mcu` may fail without the CI supervisor override; some hosts break Fluidd→Moonraker over the Docker bridge). For no-hardware verification use the **host-MCU CI stack**: [docs/ci-smoke.md](./docs/ci-smoke.md).

**Not running?** Serial/permissions → [docs/hardware/mcu-serial.md](./docs/hardware/mcu-serial.md). Klipper `libseccomp` / time errors → update libseccomp ([linuxserver FAQ](https://docs.linuxserver.io/faq#libseccomp)).

When things look good, stop the foreground session (`Ctrl+C`) and re-run the same `docker compose … up -d` command.

## Docs map

| Topic | Doc |
| --- | --- |
| Release notes | [`CHANGELOG.md`](./CHANGELOG.md) · [v2.0.0](https://github.com/dimalo/klipper-web-control-docker/releases/tag/v2.0.0) |
| **Updating this stack** (not Fluidd “Update”) | [docs/updates.md](./docs/updates.md) |
| Migration (`.config` → `printer_data`) | [docs/migration-printer-data.md](./docs/migration-printer-data.md) |
| CI smoke / no-hardware host MCU | [docs/ci-smoke.md](./docs/ci-smoke.md) |
| Frontends (Hub vs GHCR) | [docs/frontend-strategy.md](./docs/frontend-strategy.md) |
| Portainer | [docs/platforms/portainer.md](./docs/platforms/portainer.md) · [`examples/portainer-stack.yml`](./examples/portainer-stack.yml) |
| Multi-printer / Fluidd | [docs/platforms/multi-printer.md](./docs/platforms/multi-printer.md) |
| Unraid | [docs/platforms/unraid.md](./docs/platforms/unraid.md) |
| Synology | [docs/platforms/synology.md](./docs/platforms/synology.md) |
| MCU serial | [docs/hardware/mcu-serial.md](./docs/hardware/mcu-serial.md) |
| ADXL345 / input shaper | [docs/hardware/adxl345.md](./docs/hardware/adxl345.md) |

## Features

- Multiarch Hub images: **amd64, arm64, arm/v7** (arm/v6 dropped with the bookworm base — see [#75](https://github.com/dimalo/klipper-web-control-docker/pull/75))
- Multistage builds; supervisord starts Klipper then Moonraker
- Fluidd and optional Mainsail (run both if you enable Mainsail in Compose)
- Config under **`printer_data`** (`config`, `gcodes`, `database`) — mount `printer.cfg` at `/home/klippy/printer_data/config/printer.cfg` or supply it via the UI
- Optional [klipper_z_calibration](https://github.com/protoloft/klipper_z_calibration) extension
- Useful macros in [`config/client_macros.cfg`](./config/client_macros.cfg) and calibration helpers in [`config/calibration_macros.cfg`](./config/calibration_macros.cfg) — review before running on a real printer
- ADXL345 example: [`docker-compose-adxl345.yml`](./docker-compose-adxl345.yml) · [docs/hardware/adxl345.md](./docs/hardware/adxl345.md)

**Not in this image:** compiling `klipper.bin` for your MCU; in-container Fluidd/Mainsail “Update” (Moonraker Update Manager is disabled — [docs/updates.md](./docs/updates.md); pins live in `upstream.lock` / frontend zips — [docs/frontend-strategy.md](./docs/frontend-strategy.md)).

## Credits

- Macro inspiration: [fl0r1s/klipper_config](https://github.com/fl0r1s/klipper_config)
- [Klipper](https://github.com/Klipper3d/klipper) · [Moonraker](https://github.com/Arksine/moonraker) · [Fluidd](https://github.com/fluidd-core/fluidd) · [Mainsail](https://github.com/mainsail-crew/mainsail) · [klipper_z_calibration](https://github.com/protoloft/klipper_z_calibration)
- RepRap / open-source community
