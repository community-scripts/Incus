#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/incus/vm-core.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/incus/vm-core.func")

# Copyright (c) 2021-2026 community-scripts ORG
# License: MIT | https://github.com/community-scripts/Incus/raw/main/LICENSE
# Source: https://openwrt.org/

# ==============================================================================
# OpenWrt VM on an Incus host.
#
# A router/firewall appliance rather than a general purpose guest, so it runs as
# a VM: a firewall wants its own kernel, its own netfilter state and its own
# interfaces, none of which a container gets when it shares the host's kernel.
#
# The defaults below are a starting point, not a finished router. OpenWrt
# expects a network layout of its own - typically a WAN uplink plus a separate
# LAN bridge, with the LAN side unmanaged by the host - and this script only
# attaches the single bridge the rest of the collection uses. Attach the second
# NIC and move the LAN bridge off the host's DHCP range before putting the VM
# in front of anything.
# ==============================================================================

APP="OpenWrt"
APP_TYPE="vm"
var_os="${var_os:-openwrt}"
var_version="${var_version:-snapshot}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-2G}"
# Plain images:openwrt/snapshot has no cloud-init. incus_vm_create switches to
# the /cloud variant automatically when cloud-init is enabled.
var_image="${var_image:-images:openwrt/snapshot}"
var_bridge="${var_bridge:-incusbr0}"

load_functions
header_info
check_root
pve_check
arch_check
# Before any prompting: without KVM this host cannot run a VM at all, and
# answering a dozen questions first only wastes the user's time.
kvm_check

function default_settings() {
  HN="${var_hostname:-openwrt}"
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

  echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${HN}${CL}"
  echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}${DISK_SIZE}${CL}"
  echo -e "${BRIDGE}${BOLD}${DGN}Network: ${BGN}${BRG}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Storage: ${BGN}${STORAGE}${CL}"
}

function advanced_settings() {
  # Identity and sizing
  vm_prompt_hostname "openwrt"
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
  vm_prompt_agent_disk

  # Placement and lifecycle
  vm_prompt_profiles
  vm_prompt_cluster_target
  vm_prompt_autostart
  vm_prompt_snapshots
  vm_prompt_stateful
  vm_prompt_delete_protection
  vm_prompt_extra_config

  # Guest configuration
  vm_prompt_cloud_init "root"
  vm_prompt_vendor_data
  vm_prompt_start_vm "yes"

  vm_confirm_advanced_settings "Ready to create ${APP} VM?" || advanced_settings
}

function start() {
  vm_confirm_new_vm "New VM" "This will create a new ${APP} VM. Proceed?" || exit_script
  if vm_choose_settings_mode; then
    default_settings
  else
    advanced_settings
  fi
}

start
incus_vm_create "$var_image" "$HN" "$DISK_SIZE"

msg_ok "Completed successfully!"
echo -e "\n${CREATING}${GN}${APP} VM is ready.${CL}"
if [[ -n "${VM_IP:-}" ]]; then
  echo -e "${TAB}${GATEWAY}${BGN}Address: ${VM_IP}${CL}"
fi
echo -e "${TAB}${GATEWAY}${BGN}Console: ${CL}incus console ${HN}"
echo -e "${TAB}${GATEWAY}${BGN}Shell:   ${CL}incus exec ${HN} -- sh"
