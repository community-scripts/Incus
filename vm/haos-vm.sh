#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/incus/vm-core.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/incus/vm-core.func")

# Copyright (c) 2021-2026 community-scripts ORG
# License: MIT | https://github.com/community-scripts/Incus/raw/main/LICENSE
# Source: https://www.home-assistant.io/

# ==============================================================================
# Home Assistant OS VM on an Incus host.
#
# The other VM scripts in this folder launch an alias from the images: remote.
# There is none for HAOS: it is published only as a vendor disk image, so this
# downloads one and hands the file to incus_vm_create, which imports it as an
# Incus image before creating the instance.
#
# One script for both architectures. The Proxmox collection splits this into
# haos-vm.sh and pimox-haos-vm.sh because "Pimox" means Proxmox on a Raspberry
# Pi; an ARM64 Incus host is just an Incus host, so the only thing left that
# differs is which artifact to download.
#
# HAOS is an appliance with a read-only OS partition and ships no incus-agent,
# and one cannot be added. `incus exec` will not work and `incus list` shows no
# address - use the console, or look the lease up on your DHCP server.
# ==============================================================================

APP="Home Assistant OS"
APP_TYPE="vm"
NSAPP="haos-vm"
var_os="${var_os:-homeassistant}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
# The published image is 32 GiB. Incus refuses a root disk smaller than the
# image it is created from, so this is a floor, not just a default.
var_disk="${var_disk:-32G}"
var_bridge="${var_bridge:-incusbr0}"

load_functions
header_info
check_root
pve_check
arch_check
# Before any prompting: without KVM this host cannot run a VM at all, and
# answering a dozen questions first only wastes the user's time.
kvm_check

HAOS_STABLE=""
HAOS_BETA=""
HAOS_DEV=""
# Three separate files, not three keys in one: home-assistant/version publishes
# stable.json, beta.json and dev.json independently.
for _channel in stable beta dev; do
  _version=$(curl -fsSL --max-time 30 "https://raw.githubusercontent.com/home-assistant/version/master/${_channel}.json" |
    grep '"ova"' | cut -d '"' -f 4) || _version=""
  printf -v "HAOS_${_channel^^}" '%s' "$_version"
done
[[ -n "$HAOS_STABLE" ]] || fatal "Could not determine the current Home Assistant OS release"
HAOS_BETA="${HAOS_BETA:-$HAOS_STABLE}"
HAOS_DEV="${HAOS_DEV:-$HAOS_STABLE}"

if [[ "${VM_UNATTENDED:-0}" == "1" ]]; then
  BRANCH="${VM_OS_VERSION:-$HAOS_STABLE}"
else
  vm_check_dialog_env
  if vm_dialog radiolist "HOME ASSISTANT OS VERSION" "Choose the Home Assistant OS release to install" --cancel-button Exit-Script 12 62 3 \
    "$HAOS_STABLE" "Stable" ON \
    "$HAOS_BETA" "Beta" OFF \
    "$HAOS_DEV" "Dev" OFF; then
    BRANCH="$VM_DIALOG_RESULT"
  else
    exit_script
  fi
fi
var_version="$BRANCH"

case "$(uname -m)" in
aarch64 | arm64) HAOS_ARTIFACT="haos_generic-aarch64-${BRANCH}.qcow2.xz" ;;
*) HAOS_ARTIFACT="haos_ova-${BRANCH}.qcow2.xz" ;;
esac

# Dev builds never get a GitHub release, they only exist as artifacts. The
# equality tests matter because a channel file that could not be read falls back
# to the stable version above, and a stable build does have a release.
if [[ "$BRANCH" == "$HAOS_DEV" && "$BRANCH" != "$HAOS_STABLE" && "$BRANCH" != "$HAOS_BETA" ]]; then
  URL="https://os-artifacts.home-assistant.io/${BRANCH}/${HAOS_ARTIFACT}"
else
  URL="https://github.com/home-assistant/operating-system/releases/download/${BRANCH}/${HAOS_ARTIFACT}"
fi

function default_settings() {
  HN="${var_hostname:-haos}"
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
  CSM="no"
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

  echo -e "${OS}${BOLD}${DGN}Version: ${BGN}${BRANCH}${CL}"
  echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${HN}${CL}"
  echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}${DISK_SIZE}${CL}"
  echo -e "${BRIDGE}${BOLD}${DGN}Network: ${BGN}${BRG}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Storage: ${BGN}${STORAGE}${CL}"
}

function advanced_settings() {
  # Identity and sizing
  vm_prompt_hostname "haos"
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
  vm_prompt_csm
  # Guarded: a false test would abort the function under set -e.
  if [[ "${CSM:-no}" == "no" ]]; then vm_prompt_secureboot; fi
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

  vm_confirm_advanced_settings "Ready to create ${APP} ${BRANCH} VM?" || advanced_settings
}

function start() {
  vm_confirm_new_vm "New VM" "This will create a new ${APP} VM. Proceed?" || exit_script
  if vm_choose_settings_mode; then
    default_settings
  else
    advanced_settings
  fi
  # Not offered by the wizard: HAOS cannot run cloud-init or the incus-agent,
  # so both would be configuration that never takes effect.
  USE_CLOUD_INIT="no"
  AGENT_DISK="no"
}

start

command -v xz >/dev/null 2>&1 || fatal "xz is required to unpack the Home Assistant OS image - install xz-utils"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

msg_info "Retrieving the ${APP} ${BRANCH} disk image"
msg_ok "${CL}${BL}${URL}${CL}"
CACHE_FILE="$(vm_image_cache_path "$URL")"
vm_fetch_image "$URL" "$CACHE_FILE" --cache --verify-xz --min-bytes $((5 * 1024 * 1024)) || exit 115

IMAGE_FILE="${WORK_DIR}/$(basename "${CACHE_FILE%.xz}")"
msg_info "Decompressing $(basename "$CACHE_FILE")"
# Out of the cache into the work directory: decompressing over it would destroy
# the cached copy every other run.
xz -dc "$CACHE_FILE" >"$IMAGE_FILE"
msg_ok "Decompressed $(basename "$IMAGE_FILE")"

# The default is three minutes of waiting for an agent this guest will never run.
VM_AGENT_TIMEOUT="${VM_AGENT_TIMEOUT:-15}"
incus_vm_create "$IMAGE_FILE" "$HN" "$DISK_SIZE"

msg_ok "Completed successfully!"
echo -e "\n${CREATING}${GN}${APP} ${BRANCH} VM is ready.${CL}"
if [[ -n "${VM_IP:-}" ]]; then
  echo -e "${TAB}${GATEWAY}${BGN}Address: ${VM_IP}${CL}"
  echo -e "${TAB}${GATEWAY}${BGN}Web UI:  ${CL}http://${VM_IP}:8123"
else
  echo -e "${TAB}${GATEWAY}${BGN}Address: ${CL}not known yet - run: incus list ${HN}"
  echo -e "${TAB}${GATEWAY}${BGN}Web UI:  ${CL}port 8123 on that address"
fi
echo -e "${TAB}${GATEWAY}${BGN}Console: ${CL}incus console ${HN}"
