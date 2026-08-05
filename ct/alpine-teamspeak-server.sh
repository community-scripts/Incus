#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/shared/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/shared/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: tremor021 (Slaviša Arežina)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://teamspeak.com/en/

APP="Alpine-TeamSpeak-Server"
var_tags="${var_tags:-alpine;communication}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-256}"
var_disk="${var_disk:-2}"
var_os="${var_os:-alpine}"
var_version="${var_version:-3.24}"
var_arm64="${var_arm64:-no}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info

  if [[ ! -d /opt/teamspeak-server ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -fsSL https://teamspeak.com/en/downloads/#server | sed -n 's/.*teamspeak3-server_linux_amd64-\([0-9.]*[0-9]\).*/\1/p' | awk 'NR==1')

  if [ "${RELEASE}" != "$(cat ~/.teamspeak-server)" ] || [ ! -f ~/.teamspeak-server ]; then
    msg_info "Updating ${APP} LXC"
    $STD apk -U upgrade
    $STD service teamspeak stop
    curl -fsSL "https://files.teamspeak-services.com/releases/server/${RELEASE}/teamspeak3-server_linux_amd64-${RELEASE}.tar.bz2" -o ts3server.tar.bz2
    tar -xf ./ts3server.tar.bz2
    cp -ru teamspeak3-server_linux_amd64/* /opt/teamspeak-server/
    rm -f ~/ts3server.tar.bz*
    rm -rf teamspeak3-server_linux_amd64
    echo "${RELEASE}" >~/.teamspeak-server
    $STD service teamspeak start
    msg_ok "Updated successfully!"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit 0
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following IP:${CL}"
echo -e "${GATEWAY}${BGN}${IP}:9987${CL}"
