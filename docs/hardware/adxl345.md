# ADXL345 / input shaper (host SPI)

Checklist for running accelerometer / input-shaper hardware with this Docker stack. Use the dedicated Compose file; do **not** add SPI devices to the default [`docker-compose.yml`](../../docker-compose.yml).

Related: [#54](https://github.com/dimalo/klipper-web-control-docker/issues/54). Example file: [`docker-compose-adxl345.yml`](../../docker-compose-adxl345.yml).

## Important limits

- **GitHub Actions cannot validate ADXL/SPI.** CI smoke uses a Linux host MCU path only ([docs/ci-smoke.md](../ci-smoke.md)) and does not assert accelerometer hardware.
- Retest on a **real Raspberry Pi (or similar)** with the ADXL wired and the ADXL Compose file after using a **current git `main` image** (Hub `latest` may still lag git — build locally or verify Hub dates).

## Compose file highlights

[`docker-compose-adxl345.yml`](../../docker-compose-adxl345.yml) already mounts **`printer_data`** (`config`, `gcodes`, `database`) and adds:

| Setting | Purpose |
| --- | --- |
| `cap_add: [SYS_NICE, SYS_RAWIO]` | Nice + raw I/O for SPI/GPIO |
| `group_add` | Example GIDs (`996`, `998`, `5`, `20`) — **replace with your host’s** `ls -l` groups for spidev/gpio |
| `devices` | `/dev/spidev0.0`, `/dev/gpiomem`, `/dev/gpiochip0` (adjust indices) |
| Serial | Printer USB often commented out in the example — add your MCU device when printing |

```bash
docker compose -f docker-compose-adxl345.yml pull   # or build
docker compose -f docker-compose-adxl345.yml up -d
```

## Host checklist

1. Enable SPI (and relevant overlays) on the Pi; reboot if needed.
2. Confirm nodes exist:
   ```bash
   ls -l /dev/spidev* /dev/gpiomem /dev/gpiochip*
   ```
3. Note owning group GIDs; set `group_add` in the ADXL Compose file to match (do not copy example GIDs blindly).
4. Map the same device paths into the container under `devices:`.
5. Configure `[adxl345]` / resonance tester in `printer.cfg` per [Klipper docs](https://www.klipper3d.org/Measuring_Resonances.html); paths and chip names must match the **container** device nodes.
6. If open fails with EPERM/EACCES, revisit `group_add`, `SYS_RAWIO`, and whether the device is present **inside** the container (`docker exec klipper ls -l /dev/spidev*`).

## What not to do

- Do not merge SPI/`SYS_RAWIO` into the default compose used by people without ADXL.
- Do not expect CI or Hub automated tests to prove shaper calibration.

## Also see

- [MCU serial](./mcu-serial.md) — USB printer permissions (`group_add` pattern is the same idea)
- [Migrating to printer_data](../migration-printer-data.md)
