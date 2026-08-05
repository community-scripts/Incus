# Incus — Community Scripts

Incus-specific pieces of the [community-scripts](https://github.com/community-scripts) project.

This repository is deliberately **thin**. It does not contain `ct/` or `install/`
scripts, and it never should: the application scripts are platform-agnostic and
already run on Incus unchanged.

## How the pieces fit

```
community-scripts/core        the engine — build.func, core.func, tools.func,
                              install.func, and the platform backends
                              (shared/, PVE/, Incus/)

community-scripts/ProxmoxVE   the application scripts — ct/, install/, vm/, json/
                              plus Proxmox host tooling in tools/pve/

community-scripts/Incus       this repo — Incus host tooling in tools/incus/,
                              Incus documentation, and the Incus issue tracker
```

`misc/build.func` in core detects the host at runtime (`lxc-platform.func`) and
loads `Incus/incus-build.func` or `PVE/pve-backend.func` accordingly. One script
tree, two backends — so a `ct/` script duplicated into this repo would mean two
copies to maintain and would defeat the detection entirely.

## What belongs here

| Belongs here | Does **not** belong here |
| ------------ | ------------------------ |
| `tools/incus/` — Incus host management (storage pools, profiles, image remotes, cleanup, GPU setup) | `ct/`, `install/`, `vm/` — shared, live in ProxmoxVE |
| Incus-specific documentation | `incus-*.func` — engine, lives in core under `Incus/` |
| Incus issues, discussions, host-setup guidance | Anything that also applies to Proxmox VE |

`tools/incus/` is the counterpart to `tools/pve/` in ProxmoxVE: those scripts
call `pve*` binaries and have no Incus equivalent, and vice versa.

## Running the application scripts on an Incus host

Nothing special — the same one-liner works, because core resolves the backend
for you:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/debian.sh)"
```

See the [Incus host setup guide](https://community-scripts.org/docs/guides/incus)
for storage pools, networking, GPU passthrough and non-root state directories.

## Testing a fork or branch

Engine and scripts resolve independently, so either can be pointed at a fork:

```bash
export COMMUNITY_SCRIPTS_CORE_URL=https://raw.githubusercontent.com/YOU/core/my-branch
export COMMUNITY_SCRIPTS_URL=https://raw.githubusercontent.com/YOU/ProxmoxVE/my-branch
```

A local checkout wins over both: `COMMUNITY_SCRIPTS_CORE_DIR` for the engine,
and the script repo is derived from the script you invoke.

## License

MIT
