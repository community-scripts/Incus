<div align="center">
  <img src="https://raw.githubusercontent.com/community-scripts/core/main/images/logo-81x112.png" height="112px" alt="Community Scripts Logo" />

  <h1>Community Scripts — Incus</h1>
  <p><strong>One-command installations for containers on an Incus host</strong><br/>
  The same application scripts as Proxmox VE, running on the Incus backend</p>

  <p>
    <a href="https://community-scripts.org"><img src="https://img.shields.io/badge/Website-community--scripts.org-4c9b3f?style=flat-square" alt="Website" /></a>
    <a href="https://discord.gg/3AnUqsXnmK"><img src="https://img.shields.io/badge/Discord-Join_us-7289da?style=flat-square&logo=discord&logoColor=white" alt="Discord" /></a>
    <a href="https://github.com/community-scripts/Incus/stargazers"><img src="https://img.shields.io/github/stars/community-scripts/Incus?style=flat-square&label=Stars&color=f5a623" alt="Stars" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License" /></a>
  </p>
</div>

---

## What is this?

**Community scripts for Incus hosts.** If you run Incus, point your install
commands at this repository — you should never have to paste a URL with
`ProxmoxVE` in it.

A script only describes *what* to install. Creating the container is the job of
the shared engine in [core](https://github.com/community-scripts/core), which
detects an Incus host and drives the `incus` CLI. Ready-made commands for every
application are on [community-scripts.org](https://community-scripts.org).

---

## Built on Incus

[Incus](https://github.com/lxc/incus) is a system container and virtual machine
manager from the [LinuxContainers](https://linuxcontainers.org/) project. Every
container these scripts create is an Incus instance, configured through the
`incus` CLI — we add the application on top and nothing else.

If something goes wrong it helps to know which layer to ask. Container creation,
storage, networking and images are Incus itself, and its
[documentation](https://linuxcontainers.org/incus/docs/main/) and
[community forum](https://discuss.linuxcontainers.org) are the right places.
Anything about *which* application gets installed, or how, belongs in our
[Issues](https://github.com/community-scripts/Incus/issues) — please don't send
those to the Incus project.

This is an independent community project, not affiliated with or endorsed by
LinuxContainers or the Incus maintainers.

---

## Layout

| Folder | Contents | Source |
| ------ | -------- | ------ |
| `ct/` | Application scripts | mirrored from [ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) |
| `install/` | In-container install scripts | mirrored from ProxmoxVE |
| `vm/` | Virtual machine scripts | maintained here |
| `tools/incus/` | Incus host management | maintained here |
| `json/` | Incus-only metadata | maintained here |

ASCII banners are not in this repository. They are generated from each script's
`APP=` line into [core](https://github.com/community-scripts/core), which serves
them to every script repo at once.

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
| **Incus** (this repo) | The same scripts, pointed at core, plus Incus VMs and host tooling |

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
| Add or fix an Incus VM script | Here, in `vm/` |
| Add Incus host tooling | Here, in `tools/incus/` |
| Report an Incus-specific bug | [Issues](https://github.com/community-scripts/Incus/issues) — say whether it also reproduces on Proxmox VE |
| Ask a question | [Discord](https://discord.gg/3AnUqsXnmK) |

A bug that reproduces on both platforms is an application or engine bug, not an
Incus one.

---

## License

MIT — free to use, modify and redistribute. See [LICENSE](LICENSE).

---

<div align="center">
  <sub>Built on the foundation of <a href="https://github.com/tteck">tteck</a>'s original work · In memory of tteck</sub><br/>
  <sub><i>Incus is a project of <a href="https://linuxcontainers.org/">LinuxContainers</a>. <b>Proxmox</b>® is a registered trademark of <a href="https://www.proxmox.com/en/about/company">Proxmox Server Solutions GmbH</a>.</i></sub>
</div>
