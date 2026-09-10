#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/incus/vm-core.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/incus/vm-core.func")

# Copyright (c) 2021-2026 community-scripts ORG
# License: MIT | https://github.com/community-scripts/Incus/raw/main/LICENSE
# Source: https://docs.docker.com/engine/

# ==============================================================================
# Docker VM on an Incus host.
#
# The other VM scripts in this folder launch an alias from the images: remote.
# This one downloads a vendor cloud image instead, because Docker is installed
# into the image with virt-customize before the instance is ever created - the
# machine boots with Docker already on it rather than pulling it in afterwards.
# incus_vm_create takes the prepared file and imports it as an Incus image.
#
# A vendor cloud image carries no incus-agent, so `incus exec` does not work out
# of the box. Incus offers the agent to the guest over a 9p share named config;
# installing it from there is a guest-side step, and the closing message says
# how. The agent config ISO is attached as well (AGENT_DISK), which is Incus'
# documented fallback for guests whose kernel has no 9p driver.
# ==============================================================================

APP="Docker"
APP_TYPE="vm"
NSAPP="docker-vm"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-10G}"
# Left empty on purpose: the engine picks this host's LAN bridge over the
# NATed incusbr0, and asks when more than one is plausible.
var_bridge="${var_bridge:-}"

load_functions
header_info
# check_root, arch_check, pve_check, ssh_check and kvm_check in one call.
# kvm_check runs before any prompting: without KVM this host cannot run a VM at
# all, and answering a dozen questions first only wastes the user's time.
vm_preflight

case "$(uname -m)" in
x86_64 | amd64) IMG_ARCH="amd64" ;;
aarch64 | arm64) IMG_ARCH="arm64" ;;
*) fatal "No cloud image is published for $(uname -m)" ;;
esac

if [[ "${VM_UNATTENDED:-0}" == "1" ]]; then
  OS_CHOICE="${VM_OS_VERSION:-debian13}"
else
  vm_check_dialog_env
  if vm_dialog radiolist "SELECT OS" "Choose the base system for the Docker VM" --cancel-button Exit-Script 14 68 4 \
    "debian13" "Debian 13 (Trixie)" ON \
    "debian12" "Debian 12 (Bookworm)" OFF \
    "ubuntu2404" "Ubuntu 24.04 LTS (Noble)" OFF \
    "ubuntu2204" "Ubuntu 22.04 LTS (Jammy)" OFF; then
    OS_CHOICE="$VM_DIALOG_RESULT"
  else
    exit_script
  fi
fi

case "$OS_CHOICE" in
debian13) OS_TYPE="debian" OS_VERSION="13" OS_CODENAME="trixie" OS_DISPLAY="Debian 13 (Trixie)" ;;
debian12) OS_TYPE="debian" OS_VERSION="12" OS_CODENAME="bookworm" OS_DISPLAY="Debian 12 (Bookworm)" ;;
ubuntu2404) OS_TYPE="ubuntu" OS_VERSION="24.04" OS_CODENAME="noble" OS_DISPLAY="Ubuntu 24.04 LTS (Noble)" ;;
ubuntu2204) OS_TYPE="ubuntu" OS_VERSION="22.04" OS_CODENAME="jammy" OS_DISPLAY="Ubuntu 22.04 LTS (Jammy)" ;;
*) fatal "Unsupported OS '${OS_CHOICE}' (expected debian13, debian12, ubuntu2404 or ubuntu2204)" ;;
esac
var_os="$OS_TYPE"
var_version="$OS_VERSION"

# Debian publishes two variants: nocloud autologs in on the console and carries
# no cloud-init at all, generic gets the full provisioning. Ubuntu publishes the
# cloud image only.
docker_image_url() {
  case "$OS_TYPE" in
  ubuntu)
    printf 'https://cloud-images.ubuntu.com/%s/current/%s-server-cloudimg-%s.img' \
      "$OS_CODENAME" "$OS_CODENAME" "$IMG_ARCH"
    ;;
  *)
    local variant="nocloud"
    [[ "${USE_CLOUD_INIT:-no}" == "yes" ]] && variant="generic"
    printf 'https://cloud.debian.org/images/cloud/%s/latest/debian-%s-%s-%s.qcow2' \
      "$OS_CODENAME" "$OS_VERSION" "$variant" "$IMG_ARCH"
    ;;
  esac
}

function default_settings() {
  HN="${var_hostname:-docker}"
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
  AGENT_DISK="yes"
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
  START_VM="yes"
  STORAGE="${var_storage:-default}"

  echo -e "${OS}${BOLD}${DGN}Base System: ${BGN}${OS_DISPLAY}${CL}"
  echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${HN}${CL}"
  echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}${DISK_SIZE}${CL}"
  echo -e "${BRIDGE}${BOLD}${DGN}Network: ${BGN}${BRG}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Storage: ${BGN}${STORAGE}${CL}"
}

function advanced_settings() {
  # The rest of the Cloud-Init questions. The first one is asked before the
  # settings-mode fork below, so this is where the follow-ups land; it is a
  # no-op when Cloud-Init is off and it only ever runs once.
  vm_prompt_cloud_init_advanced

  # Identity and sizing
  vm_prompt_hostname "docker"
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
  vm_prompt_vendor_data
  vm_prompt_start_vm "yes"

  vm_confirm_advanced_settings "Ready to create ${APP} VM on ${OS_DISPLAY}?" || advanced_settings
}

# Asked before the settings mode split rather than inside advanced_settings:
# it decides which Debian variant gets downloaded, so a default-settings run
# has to answer it too.
vm_prompt_cloud_init "root"
if [[ "$OS_TYPE" == "ubuntu" && "${USE_CLOUD_INIT:-no}" != "yes" ]]; then
  USE_CLOUD_INIT="yes"
  msg_warn "Ubuntu cloud images configure their network from cloud-init only - enabling it"
fi

vm_start_script

URL="$(docker_image_url)"
msg_info "Retrieving the ${OS_DISPLAY} cloud image"
msg_ok "${CL}${BL}${URL}${CL}"
CACHE_FILE="$(vm_image_cache_path "$URL")"
vm_fetch_image "$URL" "$CACHE_FILE" --cache --min-bytes $((100 * 1024 * 1024)) || exit 115

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Work on a copy: everything below rewrites the image, and the cache has to stay
# the untouched vendor download for the next run.
IMAGE_FILE="${WORK_DIR}/docker-${OS_CODENAME}.qcow2"
cp -f "$CACHE_FILE" "$IMAGE_FILE"

# Incus sizes the root volume, but nothing inside the guest grows the partition
# when cloud-init is not there to do it, so expand it offline first.
if [[ "${USE_CLOUD_INIT:-no}" != "yes" ]]; then
  msg_info "Expanding the root filesystem to ${DISK_SIZE}"
  vm_expand_image "$IMAGE_FILE" "$DISK_SIZE" || true
fi

DOCKER_PREINSTALLED="no"
if vm_ensure_virt_customize; then
  # libguestfs runs its appliance on an isolated network and inherits no
  # resolver from the host.
  export LIBGUESTFS_BACKEND_SETTINGS=dns=8.8.8.8,1.1.1.1

  msg_info "Installing Docker into the image (this takes a few minutes)"
  if virt-customize -q -a "$IMAGE_FILE" --install curl,ca-certificates >/dev/null 2>&1 &&
    virt-customize -q -a "$IMAGE_FILE" --run-command "curl -fsSL https://get.docker.com | sh" >/dev/null 2>&1 &&
    virt-customize -q -a "$IMAGE_FILE" --run-command "systemctl enable docker" >/dev/null 2>&1; then
    virt-customize -q -a "$IMAGE_FILE" --run-command 'mkdir -p /etc/docker; cat > /etc/docker/daemon.json << EOF
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF' >/dev/null 2>&1 || true
    DOCKER_PREINSTALLED="yes"
    msg_ok "Installed Docker into the image"
  else
    msg_warn "Could not install Docker offline - falling back to a first-boot install"
  fi
fi

vm_prepare_cloud_image "$IMAGE_FILE" "$HN" || true

if command -v virt-customize >/dev/null 2>&1 && [[ "${USE_CLOUD_INIT:-no}" != "yes" ]]; then
  # The nocloud image has no cloud-init to set a password, so the console is the
  # only way in and it has to log in by itself.
  virt-customize -q -a "$IMAGE_FILE" --run-command 'mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d /etc/systemd/system/getty@tty1.service.d
for d in /etc/systemd/system/serial-getty@ttyS0.service.d /etc/systemd/system/getty@tty1.service.d; do
  printf "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin root --noclear %%I \$TERM\n" > "$d/autologin.conf"
done' >/dev/null 2>&1 || true
fi

if [[ "$DOCKER_PREINSTALLED" == "no" ]] && command -v virt-customize >/dev/null 2>&1; then
  msg_info "Adding a first-boot Docker installer to the image"
  if virt-customize -q -a "$IMAGE_FILE" --run-command 'cat > /root/install-docker.sh << "DOCKERSCRIPT"
#!/bin/bash
exec > /var/log/install-docker.log 2>&1
set -x
apt-get update
apt-get install -y curl ca-certificates
curl -fsSL https://get.docker.com | sh
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << DAEMON
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
DAEMON
systemctl enable --now docker
touch /root/.docker-installed
DOCKERSCRIPT
chmod +x /root/install-docker.sh
cat > /etc/systemd/system/install-docker.service << "DOCKERSERVICE"
[Unit]
Description=Install Docker on first boot
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/root/.docker-installed

[Service]
Type=oneshot
ExecStart=/root/install-docker.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
DOCKERSERVICE
systemctl enable install-docker.service' >/dev/null 2>&1; then
    msg_ok "Docker will install itself on first boot"
  else
    msg_warn "Docker is not in the image and no first-boot installer could be added"
    msg_warn "Install it in the guest with: curl -fsSL https://get.docker.com | sh"
  fi
fi

# The default is three minutes of waiting for an agent that is on the config
# drive but not yet installed in this guest.
VM_AGENT_TIMEOUT="${VM_AGENT_TIMEOUT:-30}"
incus_vm_create "$IMAGE_FILE" "$HN" "$DISK_SIZE"

msg_ok "Completed successfully!"
echo -e "\n${CREATING}${GN}${APP} VM is ready.${CL}"
echo -e "${TAB}${OS}${BGN}Base:    ${OS_DISPLAY}${CL}"
if [[ -n "${VM_IP:-}" ]]; then
  echo -e "${TAB}${GATEWAY}${BGN}Address: ${VM_IP}${CL}"
fi
echo -e "${TAB}${GATEWAY}${BGN}Console: ${CL}incus console ${HN}"
if [[ "$DOCKER_PREINSTALLED" == "yes" ]]; then
  echo -e "${TAB}${GATEWAY}${BGN}Docker:  ${CL}already installed"
else
  echo -e "${TAB}${GATEWAY}${BGN}Docker:  ${CL}installing on first boot, see /var/log/install-docker.log"
fi
echo -e "${TAB}${GATEWAY}${BGN}Agent:   ${CL}for 'incus exec', in a root shell in the guest: mount -t 9p config /mnt && cd /mnt && ./install.sh"
