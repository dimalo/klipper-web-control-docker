# Frontend image strategy

Hub vs git tags: see [README Status / images](../README.md#status--images).

Near-term (2.0.x): keep custom Hub images `dimalo/fluidd` and `dimalo/mainsail`
(Alpine unzip + Nginx template for `KLIPPER_HOST` / mjpg upstreams).

## Pins

Release zips are pinned in [`upstream.lock`](../upstream.lock) and as
`FRONTEND_ZIP_URL` defaults / workflow build-args — **not** only
`…/releases/latest/download/…` — so rebuilds are reproducible.

| UI | Upstream | Locked release (see lock file) |
| --- | --- | --- |
| Fluidd | [fluidd-core/fluidd](https://github.com/fluidd-core/fluidd) | `FLUIDD_RELEASE` |
| Mainsail | [mainsail-crew/mainsail](https://github.com/mainsail-crew/mainsail) | `MAINSAIL_RELEASE` |

Bump by editing `upstream.lock`, the frontend Dockerfile default (Fluidd),
and the Fluidd/Mainsail multiarch workflow `build-args`, then run CI smoke.

## Later options (not default)

- Official GHCR images (`ghcr.io/fluidd-core/fluidd`, `ghcr.io/mainsail-crew/mainsail`)
  once Nginx/`client.conf` multi-printer and mjpg assumptions are inventoried.
- Compose profiles (`ui-custom` vs `ui-official`) as a migration path.

Do not flip compose defaults to official images without a smoke-verified spike.
