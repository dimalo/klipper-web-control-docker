# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - Unreleased

Proposed patch after 2.0.0: correct Docker update UX. **Do not cut a git tag
until the maintainer confirms** the version number (2.0.1 vs 2.1.0).

### Fixed

- Disable Moonraker **Update Manager** in stock and CI `moonraker.conf` so
  Fluidd/Mainsail no longer offer in-container git updates for Klipper,
  Moonraker, or `klipper_z_calibration` (those fight image pins in
  `upstream.lock`).

### Added

- [docs/updates.md](./docs/updates.md) — how to update this stack
  (`docker compose pull` / rebuild; bump pins via PR + CI smoke).

### Version rationale

- Prefer **2.0.1** (patch): behavior/docs fix for an already-documented
  non-feature (“automatic updates” were never supported); no mount or API
  layout break.
- Prefer **2.1.0** only if you want to treat “Update Manager removed from
  stock conf” as a user-visible capability change rather than a bugfix.

## [2.0.0] - 2026-10-27

Major revive of the Docker stack on `main`: Moonraker **`printer_data`** layout,
host-MCU CI smoke, platform/hardware docs, and dependency hygiene for reproducible builds.

### Breaking

- Config, gcodes, and Moonraker database mounts now use Moonraker’s **`printer_data`**
  layout (`/home/klippy/printer_data/{config,gcodes,database}`) instead of legacy
  `~/.config`, `~/gcode_files`, and `~/.moonraker_database`.
- Upgrade path: [docs/migration-printer-data.md](./docs/migration-printer-data.md) and
  [`scripts/migrate-printer-data.sh`](./scripts/migrate-printer-data.sh) (dry-run, then `--apply`).
- Default [`docker-compose.yml`](./docker-compose.yml) no longer maps host serial devices.
  For a real printer, merge the hardware override:
  `docker compose -f docker-compose.yml -f docker-compose.hw.yml up -d`
  (see [docs/hardware/mcu-serial.md](./docs/hardware/mcu-serial.md)).

### Added

- CI smoke harness with Linux **host MCU** (`klipper_mcu`), restart/management API checks,
  and GitHub Actions workflow [`.github/workflows/ci-smoke.yml`](./.github/workflows/ci-smoke.yml)
  ([docs/ci-smoke.md](./docs/ci-smoke.md)).
- `scripts/migrate-printer-data.sh` helper for path upgrades.
- Platform docs: Portainer, multi-printer/Fluidd, Unraid, Synology under `docs/platforms/`.
- Hardware docs: MCU serial mapping, ADXL345 / input shaper under `docs/hardware/`.
- README status banner when Hub `latest` may lag git `main`.
- `upstream.lock` — pinned Klipper / Moonraker / z_calibration SHAs and frontend release URLs.
- `docker-compose.hw.yml` — serial device override split from the default compose file.
- [docs/frontend-strategy.md](./docs/frontend-strategy.md) — custom UI pins vs official GHCR path.

### Fixed

- Moonraker DB / gcode **upload path** alignment (`printer_data/database`, gcodes volume)
  so file API and UI uploads hit the mounted paths.

### Changed

- **D1 Actions hygiene:** `actions/checkout@v4`, `$GITHUB_OUTPUT` (no `::set-output`),
  `docker/login-action@v3`, `docker/build-push-action@v5`, QEMU/Buildx `@v3` (no `@master`).
  Publish workflows still push only on non-PR events.
- **D2 Compose:** obsolete `version:` already absent; hardware `devices:` moved to override;
  README prefers `docker compose` (v2 plugin).
- **D3 Base image:** core and builder stages pin **Python 3.11 on Debian bookworm**
  (`python:3.11-bookworm` / `python:3.11-slim-bookworm`).
- **D4 Upstream pins:** Dockerfile build-args `KLIPPER_REF` / `MOONRAKER_REF` /
  `Z_CALIBRATION_REF` default to SHAs in `upstream.lock` (no floating `master` clone tip).
- **D5 Frontend pins:** Fluidd/Mainsail zip URLs use release tags from `upstream.lock`
  (`fluidd-core` / `mainsail-crew`); default Fluidd zip updated accordingly.

### Verification

- Gate for this release line: **CI smoke (host MCU)** on pull requests and pushes to `main`.

[2.0.0]: https://github.com/dimalo/klipper-web-control-docker/releases/tag/v2.0.0
