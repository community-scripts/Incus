# Incus host tools

Scripts that manage an **Incus host** — the counterpart to `tools/pve/` in the
ProxmoxVE repository, which calls `pve*` binaries and has no Incus equivalent.

Candidates for this folder:

- storage pool creation, resizing and inspection (`incus storage …`)
- profile management and defaults
- image remote configuration and pruning
- bulk container operations (cleanup, batch create, update)
- GPU passthrough helpers using current `gpu` device syntax (`pci=`, `id=`, `vendorid=`)

Anything that also applies to Proxmox VE does **not** belong here — it belongs
in the shared engine (`community-scripts/core`) or in the shared script tree.

Empty for now: everything Incus-specific that exists today is engine code and
lives in `core/Incus/`.
