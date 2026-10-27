# How to update this Docker stack

Fluidd and Mainsail expose Moonraker’s **Update Manager**. That path is for
native installs (KIAUH / MainsailOS) where Klipper and Moonraker live as git
checkouts on the host. **It is the wrong update path for this image.**

This stack pins Klipper, Moonraker, `klipper_z_calibration`, and frontend
release zips in [`upstream.lock`](../upstream.lock). The core image checks out
those SHAs at **build time** (often detached HEAD). In-container `git pull` /
UI “Update” fights those pins, does not refresh the published Hub image, and
can leave a broken or drifted container.

Stock [`config/moonraker.conf`](../config/moonraker.conf) therefore **omits**
`[update_manager]` (and the old `z_calibration` git client). The Fluidd/Mainsail
Update panel should not offer component upgrades. If you still see Update
controls, your mounted `moonraker.conf` still enables the manager — remove those
sections and restart Moonraker (or align with the stock config).

## Update the running stack

1. **Pull published images** (when Hub matches the git line you want):

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.hw.yml pull
   docker compose -f docker-compose.yml -f docker-compose.hw.yml up -d
   ```

   Omit `-f docker-compose.hw.yml` if you are not using the serial override.
   Check Hub **last-pushed / digest** before trusting `latest` — see
   [README Status / images](../README.md#status--images).

2. **Or rebuild from this repo** (known git SHA / local pins):

   ```bash
   docker compose build --pull
   docker compose -f docker-compose.yml -f docker-compose.hw.yml up -d
   ```

Host config, gcodes, and database volumes are preserved across image updates.
Path layout changes still need the migration guide:
[docs/migration-printer-data.md](./migration-printer-data.md).

## Bump upstream versions (maintainers / contributors)

1. Edit [`upstream.lock`](../upstream.lock) (and matching Dockerfile / workflow
   defaults — see [docs/frontend-strategy.md](./frontend-strategy.md)).
2. Open a PR; let **CI smoke (host MCU)** pass ([docs/ci-smoke.md](./ci-smoke.md)).
3. After merge, republish Hub images via the multiarch workflows, then users
   `docker compose pull` as above.

Do **not** use Fluidd/Mainsail Update to change Klipper, Moonraker, or
`z_calibration` inside a running container.
