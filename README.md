<div align="center">
  <img src="https://raw.githubusercontent.com/community-scripts/core/main/images/logo-81x112.png" height="112px" alt="Community Scripts Logo" />

  <h1>Community Scripts — Incus</h1>
  <p><strong>One-command installations for containers on an Incus host</strong><br/>
  The same application scripts as Proxmox VE, running on the Incus backend</p>

  <p>
    <a href="https://community-scripts.org"><img src="https://img.shields.io/badge/Website-community--scripts.org-4c9b3f?style=flat-square" /></a>
    <a href="https://discord.gg/3AnUqsXnmK"><img src="https://img.shields.io/badge/Discord-Join_us-7289da?style=flat-square&logo=discord&logoColor=white" /></a>
    <a href="https://github.com/community-scripts/Incus/stargazers"><img src="https://img.shields.io/github/stars/community-scripts/Incus?style=flat-square&label=Stars&color=f5a623" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" /></a>
  </p>
</div>

---

## What is this?

**Community scripts for Incus hosts.** If you run Incus, this is the repository
you point your install commands at — you should never have to paste a URL with
`ProxmoxVE` in it.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/Incus/main/ct/debian.sh)"
```

Run that in your Incus host shell. The script picks up the shared engine from
[core](https://github.com/community-scripts/core), which detects that it is on
an Incus host and creates the container with the `incus` CLI.

---

## This is a mirror, not a fork

The application scripts are **platform-agnostic**. A `ct/` script describes what
to install, not how to create a container — that part lives in the engine, which
has one backend per platform. So the scripts here are the same files as in
[ProxmoxVE](https://github.com/community-scripts/ProxmoxVE), with one difference:
the bootstrap line loads the engine from core instead of ProxmoxVE's own `misc/`.

```
ProxmoxVE/ct/debian.sh   →  source .../ProxmoxVE/main/misc/build.func   (monolith, PVE only)
Incus/ct/debian.sh       →  source .../core/main/shared/build.func      (detects the host)
```

They are kept in sync automatically — see [`.github/workflows/sync-scripts.yml`](.github/workflows/sync-scripts.yml).

**Do not fix application bugs here.** A fix made in this repository is overwritten
by the next sync. Send it to ProxmoxVE (or ProxmoxVED for new scripts) and it
arrives here on its own.

---

## Layout

| Folder | Contents | Source |
| ------ | -------- | ------ |
| `ct/` | 577 application scripts | mirrored from ProxmoxVE |
| — | ASCII banners | served from [core](https://github.com/community-scripts/core), generated for all repos at once |
| `install/` | in-container install scripts | mirrored from ProxmoxVE |
| `tools/incus/` | Incus host management | maintained here |
| `json/` | Incus-only metadata | maintained here |

Folder names deliberately match ProxmoxVE. The engine resolves
`install/<app>-install.sh` by that exact path, so renaming it would mean making
the engine's paths platform-dependent — new divergence for a cosmetic gain.

### What is not here, and why

| Not mirrored | Reason |
| ------------ | ------ |
| `vm/` | All 16 VM scripts call `qm` and `pvesm` directly. They are Proxmox VE tooling, not portable. Incus VM support lives in the engine (`incus/vm-core.func`) and needs its own scripts. |
| `turnkey/` | TurnKey Linux templates are a Proxmox VE feature. |
| `tools/pve/` | Host management through `pve*` binaries. The Incus counterpart is `tools/incus/`. |
| `misc/` | The old in-repo engine. It lives in [core](https://github.com/community-scripts/core) now. |
| `ct/headers/` | Headers are generated artifacts derived from each script's `APP=` line, and identical on both platforms. core generates them once for every script repo. |

---

## Requirements

| Component | Details |
| --------- | ------- |
| **Incus** | Installed and usable — `incus info` must work for your user |
| **Storage** | Free space on the **storage pool**, not just the host disk. Default loop-backed pools are often ~10 GiB — check with `incus storage list` |
| **Network** | Access to the `images:` remote and to GitHub |

Non-root users are supported. Defaults, diagnostics and build logs go to
`~/.config/community-scripts` instead of `/usr/local/community-scripts`;
override with `COMMUNITY_SCRIPTS_STATE_DIR`.

See the [Incus host setup guide](https://community-scripts.org/docs/guides/incus)
for storage pools, networking, GPU passthrough and the update path.

---

## Repository map

| Repository | Contains |
| ---------- | -------- |
| [core](https://github.com/community-scripts/core) | The engine — one codebase, one backend per platform |
| [ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) | Canonical application scripts, plus `tools/pve/`, `vm/`, `turnkey/` |
| [ProxmoxVED](https://github.com/community-scripts/ProxmoxVED) | Where new scripts are tested first |
| **Incus** (this repo) | The same scripts, pointed at core, plus Incus host tooling |

---

## Testing a fork or branch

Engine and scripts resolve independently, so either can point at a fork:

```bash
export COMMUNITY_SCRIPTS_CORE_URL=https://raw.githubusercontent.com/YOU/core/my-branch
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/Incus/main/ct/debian.sh)"
```

A local checkout wins over both. Clone core as a sibling and just run the script
— no configuration, no network:

```bash
git clone https://github.com/community-scripts/core
git clone https://github.com/community-scripts/Incus
cd Incus && bash ct/debian.sh
```

Put core elsewhere with `COMMUNITY_SCRIPTS_CORE_DIR`.

---

## Contributing

| I want to… | Go here |
| ---------- | ------- |
| Fix an application script | [ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) — fixes made here are overwritten by the sync |
| Add a new application script | [ProxmoxVED](https://github.com/community-scripts/ProxmoxVED) |
| Change how containers are built | [core](https://github.com/community-scripts/core) |
| Add Incus host tooling | Here, in `tools/incus/` |
| Report an Incus-specific bug | [Issues](https://github.com/community-scripts/Incus/issues) — say whether it also reproduces on Proxmox VE |
| Ask a question | [Discord](https://discord.gg/3AnUqsXnmK) |

A bug that reproduces on both platforms is an application or engine bug, not an
Incus one. Only the Incus backend and `tools/incus/` are maintained here.

---

## License

MIT — free to use, modify and redistribute. See [LICENSE](LICENSE).

---

<div align="center">
  <sub>Built on the foundation of <a href="https://github.com/tteck">tteck</a>'s original work · In memory of tteck</sub><br/>
  <sub><i>Incus is a project of <a href="https://linuxcontainers.org/">LinuxContainers</a>. <b>Proxmox</b>® is a registered trademark of <a href="https://www.proxmox.com/en/about/company">Proxmox Server Solutions GmbH</a>.</i></sub>
</div>
