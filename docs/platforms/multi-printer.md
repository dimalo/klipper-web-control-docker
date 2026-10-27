# Multiple Klipper / Moonraker instances with Fluidd

How to run more than one printer with this stack — and what the default Fluidd image does **not** do.

Related: [#34](https://github.com/dimalo/klipper-web-control-docker/issues/34).

## What the default frontend does

The bundled Fluidd/Mainsail Nginx image proxies **one** Moonraker upstream:

- Env defaults: `KLIPPER_HOST=klipper`, `KLIPPER_API_PORT=7125` ([`frontend/Dockerfile`](../../frontend/Dockerfile))
- Template: [`frontend/upstreams.conf.template`](../../frontend/upstreams.conf.template) → a single `apiserver` upstream

Compose `links:` / DNS name `klipper` matches that default. There is **no** multi-upstream Nginx rewrite in this milestone; do not expect one Fluidd container to reverse-proxy several Moonrakers on different Compose service names without custom Nginx.

## Supported patterns

### 1. Fluidd printer list (UI)

Fluidd can store **multiple printers** (each with its own Moonraker URL) in the UI settings. Typical use:

- Each Klipper/Moonraker stack exposes API port **7125** on the host as **7125**, **7126**, …
- In Fluidd: add printers pointing at `http://<host>:7125`, `http://<host>:7126`, etc. (or LAN IPs)
- The default Nginx proxy still fronts **one** primary instance at `/` for that Fluidd container; extra printers are reached by URL as Fluidd configures them

Use this when instances are reachable on the LAN and you want one browser bookmark with a printer switcher.

### 2. Separate UI ports (one Fluidd per Moonraker)

Run a second Fluidd (or Mainsail) service with its own host port, e.g. **8010** and **8011**, each `KLIPPER_HOST` / `links` aimed at its own `klipper_*` service.

```yaml
  fluidd_printer_b:
    image: dimalo/fluidd
    ports:
      - "8011:80"
    environment:
      KLIPPER_HOST: klipper_another_printer
      KLIPPER_API_PORT: "7125"
    depends_on:
      - klipper_another_printer
    links:
      - klipper_another_printer:klipper_another_printer
```

Each UI talks only to its linked Moonraker via the single-upstream proxy.

### 3. Second Klipper service in Compose (port 7126→7125)

[`docker-compose.yml`](../../docker-compose.yml) includes a **commented** second-printer block. Pattern:

| Item | First printer | Second printer |
| --- | --- | --- |
| Service | `klipper` | `klipper_another_printer` |
| Host API port | `7125:7125` | `7126:7125` |
| Config bind | `./config` → `…/printer_data/config` | `./config_another_printer` → same target |
| Database volume | `moonraker_data` | `moonraker_data_another` |
| Serial | e.g. `/dev/ttyUSB0` | e.g. `/dev/ttyACM0` |
| G-code volume | often shared `gcode_files` | same or separate |

Uncomment and adapt that block; keep mounts on **`printer_data`** (not legacy `.config`). Wire Fluidd via pattern **1** or **2** above.

## Out of scope here

- Rewriting Nginx to load-balance or path-route multiple Moonrakers
- Traefik / prind-style multi-printer products

## Also see

- [README Status / images](../../README.md#status--images) — Hub vs git tags
- [MCU serial](../hardware/mcu-serial.md) — per-instance device mapping
- [Portainer](./portainer.md) — pull-only stacks for NAS/UI hosts
- [Migrating to printer_data](../migration-printer-data.md) — if upgrading mounts
