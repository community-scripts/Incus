#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/incus/vm-core.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/incus/vm-core.func")

# Copyright (c) 2021-2026 community-scripts ORG
# License: MIT | https://github.com/community-scripts/Incus/raw/main/LICENSE
# Source: https://mikrotik.com/download

# ==============================================================================
# MikroTik RouterOS CHR VM on an Incus host.
#
# The other VM scripts in this folder launch an alias from the images: remote.
# There is none for RouterOS: MikroTik publishes the Cloud Hosted Router only as
# a disk image, so this downloads one and hands the file to incus_vm_create,
# which imports it as an Incus image before creating the instance.
#
# CHR boots from an MBR, not from UEFI, so this is the one script here that
# defaults to legacy BIOS (security.csm). The Proxmox counterpart gets the same
# result by simply not passing -bios ovmf, since SeaBIOS is the Proxmox default;
# on Incus UEFI is the default and has to be turned off explicitly.
#
# RouterOS ships no incus-agent and cannot be given one. `incus exec` will not
# work and `incus list` shows no address - use the console, or look the lease up
# on your DHCP server.
#
# The defaults below are a starting point, not a finished router. Put a second
# NIC on it and move the LAN side off the host's DHCP range before letting it
# route anything.
# ==============================================================================

APP="MikroTik RouterOS"
APP_TYPE="vm"
NSAPP="mikrotik-routeros"
var_os="${var_os:-mikrotik}"
# Only used when the release feed cannot be reached.
var_version="${var_version:-7.20}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-8G}"
var_bridge="${var_bridge:-incusbr0}"

load_functions
header_info
check_root
pve_check
arch_check
# Before any prompting: without KVM this host cannot run a VM at all, and
# answering a dozen questions first only wastes the user's time.
kvm_check

case "$(uname -m)" in
x86_64 | amd64) ;;
*) fatal "The RouterOS CHR image is x86_64 only - this host is $(uname -m)" ;;
esac

# The stable release feed. Deliberately not the changelog page the Proxmox
# script falls back to: that parse needs GNU grep -P, which an Incus host is not
# guaranteed to have.
mikrotik_latest_stable() {
  local rss version
  rss=$(curl -fsSL --max-time 20 "https://cdn.mikrotik.com/routeros/latest-stable.rss" 2>/dev/null) || return 1
  version=$(printf '%s\n' "$rss" | sed -n 's/.*<title>RouterOS \([0-9][0-9.]*\) \[.*/\1/p' | head -1)
  [[ "$version" =~ ^[0-9]+\.[0-9]+ ]] || return 1
  printf '%s' "$version"
}

msg_info "Looking up the latest stable RouterOS release"
if MIK_VERSION="$(mikrotik_latest_stable)"; then
  msg_ok "Latest stable RouterOS is ${CL}${BL}${MIK_VERSION}${CL}"
else
  MIK_VERSION="$var_version"
  msg_warn "Could not read the MikroTik release feed - falling back to ${MIK_VERSION}"
fi
var_version="$MIK_VERSION"
URL="https://download.mikrotik.com/routeros/${MIK_VERSION}/chr-${MIK_VERSION}.img.zip"

function default_settings() {
  HN="${var_hostname:-mikrotik-routeros-chr}"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  DISK_SIZE="$var_disk"
  BRG="$var_bridge"
  MAC=""
  VLAN=""
  MTU=""
  NIC_IPV4=""
  DISK_BUS="virtio-blk"
  DISK_CACHE="none"
  EXTRA_DISK_SIZE=""
  SECUREBOOT="no"
  CSM="yes"
  VTPM="no"
  GPU_PASSTHROUGH="no"
  GPU_PCI=""
  AUTOSTART="no"
  SNAPSHOT_SCHEDULE=""
  PROFILES=""
  CLUSTER_TARGET=""
  VM_DESCRIPTION="${APP} - community-scripts.org"
  GUEST_OS="Linux"
  AGENT_DISK="no"
  INSTANCE_TYPE=""
  DELETE_PROTECTION="no"
  CLOUDINIT_VENDOR_DATA=""
  USB_DEVICES=""
  PCI_DEVICES=""
  BIND_MOUNTS=""
  PROXY_PORTS=""
  STATEFUL="no"
  AUTOSTART_DELAY=""
  SNAPSHOT_PATTERN=""
  EXTRA_CONFIG=""
  USE_CLOUD_INIT="no"
  START_VM="yes"
  STORAGE="${var_storage:-default}"

  echo -e "${OS}${BOLD}${DGN}Version: ${BGN}${MIK_VERSION}${CL}"
  echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${HN}${CL}"
  echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}${DISK_SIZE}${CL}"
  echo -e "${BRIDGE}${BOLD}${DGN}Network: ${BGN}${BRG}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Storage: ${BGN}${STORAGE}${CL}"
}

function advanced_settings() {
  # Identity and sizing
  vm_prompt_hostname "mikrotik-routeros-chr"
  vm_prompt_description
  vm_prompt_guest_os
  vm_prompt_cpu_cores "$var_cpu"
  vm_prompt_ram "$var_ram"
  vm_prompt_instance_type

  # Storage
  vm_select_storage
  vm_prompt_disk_size "$var_disk"
  vm_prompt_disk_bus
  vm_prompt_disk_cache
  vm_prompt_extra_disk
  vm_prompt_bind_mounts

  # Network
  vm_prompt_bridge "$var_bridge"
  vm_prompt_mac
  vm_prompt_vlan
  vm_prompt_mtu
  vm_prompt_static_lease
  vm_prompt_proxy

  # Firmware and passthrough
  # No BIOS prompt here: the CHR image has no EFI bootloader, so UEFI is not a
  # choice the operator can usefully make.
  vm_prompt_vtpm
  vm_prompt_gpu
  vm_prompt_usb
  vm_prompt_pci

  # Placement and lifecycle
  vm_prompt_profiles
  vm_prompt_cluster_target
  vm_prompt_autostart
  vm_prompt_snapshots
  vm_prompt_stateful
  vm_prompt_delete_protection
  vm_prompt_extra_config

  # Guest configuration
  vm_prompt_start_vm "yes"

  vm_confirm_advanced_settings "Ready to create ${APP} ${MIK_VERSION} VM?" || advanced_settings
}

function start() {
  vm_confirm_new_vm "New VM" "This will create a new ${APP} CHR VM. Proceed?" || exit_script
  if vm_choose_settings_mode; then
    default_settings
  else
    advanced_settings
  fi
  CSM="yes"
  SECUREBOOT="no"
  # Not offered by the wizard: RouterOS runs neither cloud-init nor the
  # incus-agent, so both would be configuration that never takes effect.
  USE_CLOUD_INIT="no"
  AGENT_DISK="no"
}

start

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

msg_ok "${CL}${BL}${URL}${CL}"
# A mirror serving an error page returns 200, so size decides whether this is an
# image. Anything real here is far above 5 MB.
CACHE_FILE="$(vm_image_cache_path "$URL")"
vm_fetch_image "$URL" "$CACHE_FILE" --cache --min-bytes $((5 * 1024 * 1024)) || exit 115

IMAGE_FILE="${WORK_DIR}/chr-${MIK_VERSION}.img"
msg_info "Extracting $(basename "$CACHE_FILE")"
if command -v unzip >/dev/null 2>&1; then
  unzip -p "$CACHE_FILE" >"$IMAGE_FILE"
elif command -v gunzip >/dev/null 2>&1; then
  # gzip reads a zip archive that holds a single deflated member, which is what
  # MikroTik ships. -S names the suffix so it does not refuse the file outright.
  gunzip -c -S .zip "$CACHE_FILE" >"$IMAGE_FILE"
else
  fatal "Neither unzip nor gunzip is available to extract the CHR image"
fi
msg_ok "Extracted $(basename "$IMAGE_FILE")"

# The default is three minutes of waiting for an agent this guest will never run.
VM_AGENT_TIMEOUT="${VM_AGENT_TIMEOUT:-15}"
incus_vm_create "$IMAGE_FILE" "$HN" "$DISK_SIZE"

msg_ok "Completed successfully!"
echo -e "\n${CREATING}${GN}${APP} ${MIK_VERSION} VM is ready.${CL}"
if [[ -n "${VM_IP:-}" ]]; then
  echo -e "${TAB}${GATEWAY}${BGN}Address: ${VM_IP}${CL}"
fi
echo -e "${TAB}${GATEWAY}${BGN}Console: ${CL}incus console ${HN}"
echo -e "${TAB}${GATEWAY}${BGN}Login:   ${CL}admin, with an empty password"
