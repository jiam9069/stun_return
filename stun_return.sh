#!/usr/bin/env bash

# 当前脚本更新日期 （2025.01.21）

# GitHub 代理地址
GH_PROXY='https://ghfast.top/'

# 工作和临时目录
SERVER_WORK_DIR='/etc/stun_return_server'
CLIENT_WORK_DIR='/etc/stun_return_client'
TMP_DIR='/tmp/stun_return'

# 当脚本被中断时，清理临时文件
trap "rm -rf ${TMP_DIR}; exit" INT

# 项目说明
description() {
  clear
  echo -e "\n项目说明: 通过 STUN 的全球 CDN 网络回源，网络实现高速、稳定的数据传输。"
  echo -e "\n项目地址: https://github.com/fscarmen/stun_return\n"
}

# 检查操作系统类型
check_os() {
  if [ "$(type -p apt)" ]; then
    OS='debian'
  elif [ "$(type -p dnf)" ]; then
    OS='centos'
  elif [ "$(type -p apk)" ]; then
    OS='alpine'
  elif [ "$(type -p opkg)" ]; then
    OS='openwrt'
  else
    [ -s /etc/os-release ] && OS=$(awk -F \" '/^NAME/{print $2}' /etc/os-release)
    echo "Error: 当前操作系统是: ${OS}，只支持 CentOS, Debian, Ubuntu, Alpine, OpenWRT。" && exit 1
  fi
}

# 检查是否已安装服务端或客户端
check_install() {
  [ -d ${SERVER_WORK_DIR} ] && IS_INSTALL_SERVER=installed || IS_INSTALL_SERVER=uninstall
  [ -d ${CLIENT_WORK_DIR} ] && IS_INSTALL_CLIENT=installed || IS_INSTALL_CLIENT=uninstall
}

# 检查系统架构
check_arch() {
  local ARCHITECTURE=$(uname -m)
  case "$ARCHITECTURE" in
    aarch64 | arm64)
      ARCH=arm64
      ;;
    x86_64 | amd64)
      cat /proc/cpuinfo | grep -q avx2 && IS_AMD64V3=v3
      ARCH=amd64
      ;;
    armv7*)
      ARCH=arm
      ;;
    *)
      echo "Error: 当前架构是: ${ARCHITECTURE}，只支持 amd64, armv7 和 arm64" && exit 1
      ;;
  esac
}

# 服务端安装函数
server_install() {
  echo "$OS" | egrep -qiv "CentOS|Debian|OpenWrt" && echo "Error: 当前操作系统是: ${OS}，服务端只支持 CentOS, Debian, Ubuntu 和 OpenWRT。" && exit 1

  [ ! -d ${TMP_DIR} ] && mkdir -p ${TMP_DIR}

  [ "$(type -p ss)" ] && local CMD=ss || local CMD=netstat

  echo ""
  until [[ "$STUN_PORT" =~ ^[0-9]+$ ]]; do
    [ -z "$STUN_PORT_INPUT" ] && read -rp "请输入 STUN 回源的目标端口 [20000-65535]，确保与 Lucky 上设置的一致: " STUN_PORT_INPUT
    if [[ ! "$STUN_PORT_INPUT" =~ ^[2-6][0-9]{4}$ || "$STUN_PORT_INPUT" -lt 20000 || "$STUN_PORT_INPUT" -gt 65535 ]]; then
      echo -e "\nError: 请输入 20000-65535 之间的端口。"
      unset STUN_PORT_INPUT
    elif $CMD -nlutp | grep -q ":$STUN_PORT_INPUT"; then
      echo -e "\nError: 端口 $STUN_PORT_INPUT 已被占用，请更换。"
      unset STUN_PORT_INPUT
    else
      echo -e "\n端口 $STUN_PORT_INPUT 可用。"
      STUN_PORT=$STUN_PORT_INPUT
    fi
  done

  echo ""
  [[ -z "$STUN_DOMAIN_V4_INPUT" && "$IGNORE_STUN_DOMAIN_V4_INPUT" != 'ignore_stun_domain_v4_input' ]] && read -rp "请输入 IPv4 DDNS 回源域名，不使用请留空: " STUN_DOMAIN_V4_INPUT
  STUN_DOMAIN_V4=$(echo "$STUN_DOMAIN_V4_INPUT" | sed 's/^[ ]*//; s/[ ]*$//')

  echo ""
  [[ -z "$STUN_DOMAIN_V6_INPUT" && "$IGNORE_STUN_DOMAIN_V6_INPUT" != 'ignore_stun_domain_v6_input' ]] && read -rp "请输入 IPv6 DDNS 回源域名，不使用请留空: " STUN_DOMAIN_V6_INPUT
  STUN_DOMAIN_V6=$(echo "$STUN_DOMAIN_V6_INPUT" | sed 's/^[ ]*//; s/[ ]*$//')

  [ -z "$STUN_DOMAIN_V4" ] && [ -z "$STUN_DOMAIN_V6" ] && echo -e "\nError: 请至少填写一个 IPv4 或 IPv6 的 DDNS 回源域名。\n" && exit 1

  echo ""
  WS_PATH_DEFAULT=$(cat /proc/sys/kernel/random/uuid)
  [ -z "$WS_PATH_INPUT" ] && read -rp "请输入 ws 路径 [默认为 $WS_PATH_DEFAULT]: " WS_PATH_INPUT
  WS_PATH=$(echo $WS_PATH_INPUT | sed 's#^/##')
  [ -z "$WS_PATH" ] && WS_PATH=$WS_PATH_DEFAULT

  local GOST_API_URL="https://api.github.com/repos/go-gost/gost/releases/latest"

  local GOST_URL_DEFAULT="https://github.com/go-gost/gost/releases/download/v3.0.0/gost_3.0.0_linux_${ARCH}${IS_AMD64V3}.tar.gz"

  echo -e "\n下载 gost"
  if [ "$(type -p wget)" ]; then
    local GOST_URL=$(wget --no-check-certificate -qO- ${GH_PROXY}${GOST_API_URL} | sed -n "s/.*browser_download_url.*\"\(https:.*linux_${ARCH}${IS_AMD64V3}.tar.gz\)\"/\1/gp")
    GOST_URL=${GOST_URL:-${GOST_URL_DEFAULT}}
    wget --no-check-certificate -O- ${GH_PROXY}${GOST_URL} | tar xzv -C ${TMP_DIR} gost
  elif [ "$(type -p curl)" ]; then
    local GOST_URL=$(curl -sSL ${GH_PROXY}${GOST_API_URL} | sed -n "s/.*browser_download_url.*\"\(https:.*linux_${ARCH}${IS_AMD64V3}.tar.gz\)\"/\1/gp")
    GOST_URL=${GOST_URL:-${GOST_URL_DEFAULT}}
    curl -L ${GH_PROXY}${GOST_URL} | tar xzv -C ${TMP_DIR} gost
  fi

  [ -s ${TMP_DIR}/gost ] && chmod +x ${TMP_DIR}/gost && mkdir -p ${SERVER_WORK_DIR} && mv ${TMP_DIR}/gost ${SERVER_WORK_DIR}/gost && rm -rf ${TMP_DIR} || { echo "Error: 下载 gost 失败。" && exit 1; }

  if echo "$OS" | grep -qi 'openwrt'; then
    cat >/etc/init.d/stun_server <<EOF
#!/bin/sh /etc/rc.common

START=99
STOP=10

NAME="STUN-return"

STUN_PORT=${STUN_PORT}
WS_PATH=${WS_PATH}
GOST_PROG="${SERVER_WORK_DIR}/gost"
GOST_ARGS="-D -L relay+ws://:\${STUN_PORT}?path=/\${WS_PATH}&bind=true"
GOST_PID="/var/run/stun_gost.pid"

start_progs() {
  echo -e "\nStarting gost listener on port \${STUN_PORT}..."
  \$GOST_PROG \$GOST_ARGS >/dev/null 2>&1 &
  echo \$! > \$GOST_PID
}

stop_progs() {
  echo "Stopping gost listener on port \${STUN_PORT}..."
  {
    kill \$(cat \$GOST_PID)
    rm \$GOST_PID
  }
}

start() {
  start_progs
}

stop() {
  stop_progs
}

restart(){
 stop
 start
}
EOF
    chmod +x /etc/init.d/stun_server

  elif echo "$OS" | egrep -qi 'debian|centos'; then
    cat >/etc/systemd/system/stun_server.service <<EOF
[Unit]
Description=STUN Return Service
After=network.target

[Service]
Type=forking
ExecStart=${SERVER_WORK_DIR}/gost -D -L relay+ws://:${STUN_PORT}?path=/${WS_PATH}&bind=true

[Install]
WantedBy=multi-user.target
EOF
  fi

  cat >${SERVER_WORK_DIR}/config.json <<EOF
{
EOF
  [ -n "$STUN_DOMAIN_V4" ] && cat >>${SERVER_WORK_DIR}/config.json <<EOF
  "STUN_DOMAIN_V4": "${STUN_DOMAIN_V4}",
EOF
  [ -n "$STUN_DOMAIN_V6" ] && cat >>${SERVER_WORK_DIR}/config.json <<EOF
  "STUN_DOMAIN_V6": "${STUN_DOMAIN_V6}",
EOF
  cat >>${SERVER_WORK_DIR}/config.json <<EOF
  "WS_PATH": "${WS_PATH}",
  "STUN_PORT": ${STUN_PORT}
}
EOF
}

# 服务端卸载函数
server_uninstall() {
  if echo "$OS" | grep -qi 'openwrt'; then
    [ -s /etc/init.d/stun_server ] && {
      /etc/init.d/stun_server stop
      /etc/init.d/stun_server disable
      rm -f /etc/init.d/stun_server
    }
    [ -d ${SERVER_WORK_DIR} ] && rm -rf ${SERVER_WORK_DIR}
  elif echo "$OS" | egrep -qi 'debian|centos'; then
    [ -s /etc/systemd/system/stun_server.service ] && {
      systemctl disable --now stun_server
      rm -f /etc/systemd/system/stun_server.service
    }
    [ -d ${SERVER_WORK_DIR} ] && rm -rf ${SERVER_WORK_DIR}
  else
    echo "Error: 未知的操作系统。" && exit 1
  fi
  echo "stun_return 服务端已卸载。"
}

# 服务端启动函数
server_start() {
  if echo "$OS" | grep -qi 'openwrt'; then
    /etc/init.d/stun_server enable
    /etc/init.d/stun_server start
  elif echo "$OS" | egrep -qi 'debian|centos'; then
    systemctl enable --now stun_server
  else
    echo "Error: 未知的操作系统。" && exit 1
  fi
  echo -e "\n服务端已启动。"
  show_client_cmd
}

# 服务端停止函数
server_stop() {
  if echo "$OS" | grep -qi 'openwrt'; then
    /etc/init.d/stun_server stop
    /etc/init.d/stun_server disable
  elif echo "$OS" | egrep -qi 'debian|centos'; then
    systemctl stop stun_server
    systemctl disable stun_server
  else
    echo "Error: 未知的操作系统。" && exit 1
  fi
  echo -e "\n服务端已停止。"
}

# 获取配置信息
get_config() {
  if [ -s ${SERVER_WORK_DIR}/config.json ]; then
    CONFIG=$(cat ${SERVER_WORK_DIR}/config.json)
    STUN_DOMAIN_V4=$(echo "$CONFIG" | awk -F '"' '/STUN_DOMAIN_V4/{print $4}')
    STUN_DOMAIN_V6=$(echo "$CONFIG" | awk -F '"' '/STUN_DOMAIN_V6/{print $4}')
    WS_PATH=$(echo "$CONFIG" | awk -F '"' '/WS_PATH/{print $4}')
    STUN_PORT=$(echo "$CONFIG" | sed -n "/STUN_PORT/s/.*: \([^,]\+\),/\1/gp")
  else
    echo "Error: 未找到配置文件。" && exit 1
  fi
}

# 显示客户端安装命令
show_client_cmd() {
  get_config
  echo -e "\n客户端安装命令:\n"
  [[ -n "$STUN_DOMAIN_V4" && -n "$STUN_DOMAIN_V6" ]] && echo -e "IPv4 + IPv6: bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -c -w $WS_PATH -4 $STUN_DOMAIN_V4 -r <映射服务端使用的 IPv4 SOCKS5 端口> -6 $STUN_DOMAIN_V6 -e <映射服务端使用的 IPv6 SOCKS5 端口>\n"
  [ -n "$STUN_DOMAIN_V4" ] && echo -e "IPv4: bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -c -w $WS_PATH -4 $STUN_DOMAIN_V4 -r <映射服务端使用的 IPv4 SOCKS5 端口>\n"
  [ -n "$STUN_DOMAIN_V6" ] && echo -e "IPv6: bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -c -w $WS_PATH -6 $STUN_DOMAIN_V6 -e <映射服务端使用的 IPv6 SOCKS5 端口>\n"
}

# 客户端安装函数
client_install() {
  echo "$OS" | egrep -qiv "debian|centos|alpine" && echo "Error: 当前操作系统是: ${OS}，服务端只支持 CentOS, Debian, Ubuntu 和 Alpine。" && exit 1

  echo ""
  [[ -z "$STUN_DOMAIN_V4_INPUT" && "$IGNORE_STUN_DOMAIN_V4_INPUT" != 'ignore_stun_domain_v4_input' ]] && read -rp "请输入回源到服务端的 IPv4 域名，不使用请留空: " STUN_DOMAIN_V4_INPUT
  if [ -n "$STUN_DOMAIN_V4_INPUT" ]; then
    STUN_DOMAIN_V4=$(echo "$STUN_DOMAIN_V4_INPUT" | sed 's/^[ ]*//; s/[ ]*$//')
    until [ -n "$REMOTE_PORT_V4" ]; do
      echo ""
      [ -z "$REMOTE_PORT_INPUT_V4" ] && read -rp "请输入通过 IPv4 映射到服务端的端口: " REMOTE_PORT_INPUT_V4
      [[ "$REMOTE_PORT_INPUT_V4" =~ ^[0-9]+$ && "$REMOTE_PORT_INPUT_V4" -ge 1 && "$REMOTE_PORT_INPUT_V4" -le 65535 ]] && REMOTE_PORT_V4=$REMOTE_PORT_INPUT_V4 && break || unset REMOTE_PORT_INPUT_V4
    done
  fi

  echo ""
  [[ -z "$STUN_DOMAIN_V6_INPUT" && "$IGNORE_STUN_DOMAIN_V6_INPUT" != 'ignore_stun_domain_v6_input' ]] && read -rp "请输入回源到服务端的 IPv6 DDNS 域名，不使用请留空: " STUN_DOMAIN_V6_INPUT
  if [ -n "$STUN_DOMAIN_V6_INPUT" ]; then
    STUN_DOMAIN_V6=$(echo "$STUN_DOMAIN_V6_INPUT" | sed 's/^[ ]*//; s/[ ]*$//')
    until [ -n "$REMOTE_PORT_V6" ]; do
      echo ""
      [ -z "$REMOTE_PORT_INPUT_V6" ] && read -rp "请输入通过 IPv6 映射到服务端的端口: " REMOTE_PORT_INPUT_V6
      [[ "$REMOTE_PORT_INPUT_V6" =~ ^[0-9]+$ && "$REMOTE_PORT_INPUT_V6" -ge 1 && "$REMOTE_PORT_INPUT_V6" -le 65535 ]] && REMOTE_PORT_V6=$REMOTE_PORT_INPUT_V6 && break || unset REMOTE_PORT_INPUT_V6
    done
  fi

  [ -z "$STUN_DOMAIN_V4" ] && [ -z "$STUN_DOMAIN_V6" ] && echo -e "\nError: 请至少填写一个 IPv4 或 IPv6 的 DDNS 回源域名。\n" && exit 1

  echo ""
  [ -z "$WS_PATH_INPUT" ] && read -rp "请输入服务端的 ws 路径: " WS_PATH_INPUT
  WS_PATH=$(echo "$WS_PATH_INPUT" | sed 's/^[ ]*//; s/[ ]*$//')
  [ -z "$WS_PATH" ] && echo "Error: 请输入服务端的 ws 路径。" && exit 1

  [ "$(type -p netstat)" ] && local CMD=netstat || local CMD=ss

  # 查找未被占用的端口
  local START_PORT=10000
  local END_PORT=65535
  local SOCKS5_PORT

  for ((SOCKS5_PORT = $START_PORT; SOCKS5_PORT <= $END_PORT; SOCKS5_PORT++)); do
    ! $CMD -tuln | grep -q ":$SOCKS5_PORT" && break
  done

  local GOST_API_URL="https://api.github.com/repos/go-gost/gost/releases/latest"

  local GOST_URL_DEFAULT="https://github.com/go-gost/gost/releases/download/v3.0.0/gost_3.0.0_linux_${ARCH}${IS_AMD64V3}.tar.gz"

  [ ! -d ${TMP_DIR} ] && mkdir -p ${TMP_DIR}

  if [ "$(type -p wget)" ]; then
    echo -e "\n下载 gost"
    local GOST_URL=$(wget --no-check-certificate -qO- ${GH_PROXY}${GOST_API_URL} | sed -n "s/.*browser_download_url.*\"\(https:.*linux_${ARCH}${IS_AMD64V3}.tar.gz\)\"/\1/gp")
    GOST_URL=${GOST_URL:-${GOST_URL_DEFAULT}}
    wget --no-check-certificate -O- ${GH_PROXY}${GOST_URL} | tar xzv -C ${TMP_DIR} gost

  elif [ "$(type -p curl)" ]; then
    echo -e "\n下载 gost"
    local GOST_URL=$(curl -sSL ${GH_PROXY}${GOST_API_URL} | sed -n "s/.*browser_download_url.*\"\(https:.*linux_${ARCH}${IS_AMD64V3}.tar.gz\)\"/\1/gp")
    GOST_URL=${GOST_URL:-${GOST_URL_DEFAULT}}
    curl -L ${GH_PROXY}${GOST_URL} | tar xzv -C ${TMP_DIR} gost
  fi

  [ -s ${TMP_DIR}/gost ] && chmod +x ${TMP_DIR}/gost && mkdir -p ${CLIENT_WORK_DIR} && mv ${TMP_DIR}/gost ${CLIENT_WORK_DIR}/gost && rm -rf ${TMP_DIR} || { echo "Error: 下载 gost 失败。" && exit 1; }

  if echo "$OS" | grep -qi 'alpine'; then
    cat >/etc/init.d/stun_client <<EOF
#!/sbin/openrc-run

name="stun_client"
description="STUN Return Client Service"

SOCKS5_PORT=${SOCKS5_PORT}
EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>/etc/init.d/stun_client <<EOF
REMOTE_PORT_V4=${REMOTE_PORT_V4}
STUN_DOMAIN_V4=${STUN_DOMAIN_V4}
EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>/etc/init.d/stun_client <<EOF
REMOTE_PORT_V6=${REMOTE_PORT_V6}
STUN_DOMAIN_V6=${STUN_DOMAIN_V6}
EOF
    cat >>/etc/init.d/stun_client <<EOF
WS_PATH=${WS_PATH}

: \${cfgfile:=${CLIENT_WORK_DIR}}

command="${CLIENT_WORK_DIR}/gost"
command_args_local="-D -L socks5://[::1]:\${SOCKS5_PORT}"
EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>/etc/init.d/stun_client <<EOF
command_args_remote_v4="-D -L rtcp://:\${REMOTE_PORT_V4}/[::1]:\${SOCKS5_PORT} -F relay+ws://\${STUN_DOMAIN_V4}:80?path=/\${WS_PATH}&host=\${STUN_DOMAIN_V4}"
EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>/etc/init.d/stun_client <<EOF
command_args_remote_v6="-D -L rtcp://:\${REMOTE_PORT_V6}/[::1]:\${SOCKS5_PORT} -F relay+ws://\${STUN_DOMAIN_V6}:80?path=/\${WS_PATH}&host=\${STUN_DOMAIN_V6}"
EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>/etc/init.d/stun_client <<EOF
pidfile_remote_v4="/var/run/stun-gost-remote-v4.pid"
EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>/etc/init.d/stun_client <<EOF
pidfile_remote_v6="/var/run/stun-gost-remote-v6.pid"
EOF
    cat >>/etc/init.d/stun_client <<EOF
pidfile_local="/var/run/stun-gost-local.pid"

depend() {
  need net
  after firewall
}

start_pre() {
  # 检查进程是否已经在运行
  if [ -f "\$pidfile_local" ] && kill -0 \$(cat "\$pidfile_local") 2>/dev/null; then
    eerror "Local SOCKS5 proxy is already running"
    return 1
  fi
EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>/etc/init.d/stun_client <<EOF
  if [ -f "\$pidfile_remote_v4" ] && kill -0 \$(cat "\$pidfile_remote_v4") 2>/dev/null; then
    eerror "Remote IPv4 RTCP proxy is already running"
    return 1
  fi
EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>/etc/init.d/stun_client <<EOF
  if [ -f "\$pidfile_remote_v6" ] && kill -0 \$(cat "\$pidfile_remote_v6") 2>/dev/null; then
    eerror "Remote IPv6 RTCP proxy is already running"
    return 1
  fi
EOF
    cat >>/etc/init.d/stun_client <<EOF
}

start() {
  ebegin "Starting STUN Return Client"

  # Start local SOCKS5 proxy
  start-stop-daemon --start --background \
    --make-pidfile --pidfile "\$pidfile_local" \
    --exec "\$command" -- \$command_args_local
  local ret1=\$?

EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>/etc/init.d/stun_client <<EOF
  # Start remote IPv4 RTCP proxy
  start-stop-daemon --start --background \
    --make-pidfile --pidfile "\$pidfile_remote_v4" \
    --exec "\$command" -- \$command_args_remote_v4
  local ret2=\$?
EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>/etc/init.d/stun_client <<EOF
  # Start remote IPv6 RTCP proxy
  start-stop-daemon --start --background \
    --make-pidfile --pidfile "\$pidfile_remote_v6" \
    --exec "\$command" -- \$command_args_remote_v6
EOF
    if [ -n "$STUN_DOMAIN_V6" ]; then
      if [ -n "$STUN_DOMAIN_V4" ]; then
        cat >>/etc/init.d/stun_client <<EOF
  local ret3=\$?
EOF
      else
        cat >>/etc/init.d/stun_client <<EOF
  local ret2=\$?
EOF
      fi
    fi
    cat >>/etc/init.d/stun_client <<EOF

  # 检查进程是否都成功启动
EOF
    if [[ -n "$STUN_DOMAIN_V4" && -n "$STUN_DOMAIN_V6" ]]; then
      cat >>/etc/init.d/stun_client <<EOF
  if [ \$ret1 -eq 0 ] && [ \$ret2 -eq 0 ] && [ \$ret3 -eq 0 ]; then
EOF
    else
      cat >>/etc/init.d/stun_client <<EOF
  if [ \$ret1 -eq 0 ] && [ \$ret2 -eq 0 ]; then
EOF
    fi
    cat >>/etc/init.d/stun_client <<EOF
    eend 0
  else
    eend 1
  fi
}

stop() {
  ebegin "Stopping STUN Return Client"

  local ret=0

  # Stop local SOCKS5 proxy
  if [ -f "\$pidfile_local" ]; then
    start-stop-daemon --stop --pidfile "\$pidfile_local" --retry TERM/30/KILL/5
    if [ \$? -eq 0 ]; then
      rm -f "\$pidfile_local"
    else
      ret=1
    fi
  fi

EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>/etc/init.d/stun_client <<EOF
  # Stop remote IPv4 RTCP proxy
  if [ -f "\$pidfile_remote_v4" ]; then
    start-stop-daemon --stop --pidfile "\$pidfile_remote_v4" --retry TERM/30/KILL/5
    if [ \$? -eq 0 ]; then
      rm -f "\$pidfile_remote_v4"
    else
      ret=1
    fi
  fi

EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>/etc/init.d/stun_client <<EOF
  # Stop remote IPv6 RTCP proxy
  if [ -f "\$pidfile_remote_v6" ]; then
    start-stop-daemon --stop --pidfile "\$pidfile_remote_v6" --retry TERM/30/KILL/5
    if [ \$? -eq 0 ]; then
      rm -f "\$pidfile_remote_v6"
    else
      ret=1
    fi
  fi

EOF
    cat >>/etc/init.d/stun_client <<EOF
  eend \$ret
}

status() {
  local ret=0

  if [ -f "\$pidfile_local" ]; then
    einfo "Local SOCKS5 proxy status:"
    if kill -0 \$(cat "\$pidfile_local") 2>/dev/null; then
      einfo "Running"
    else
      ewarn "Not running (stale pidfile)"
      ret=1
    fi
  else
    ewarn "Local SOCKS5 proxy is not running"
    ret=1
  fi

EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>/etc/init.d/stun_client <<EOF
  if [ -f "\$pidfile_remote_v4" ]; then
    einfo "Remote IPv4 RTCP proxy status:"
    if kill -0 \$(cat "\$pidfile_remote_v4") 2>/dev/null; then
      einfo "Running"
    else
      ewarn "Not running (stale pidfile)"
      ret=1
    fi
  else
    ewarn "Remote IPv4 RTCP proxy is not running"
    ret=1
  fi

EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>/etc/init.d/stun_client <<EOF
  if [ -f "\$pidfile_remote_v6" ]; then
    einfo "Remote IPv6 RTCP proxy status:"
    if kill -0 \$(cat "\$pidfile_remote_v6") 2>/dev/null; then
      einfo "Running"
    else
      ewarn "Not running (stale pidfile)"
      ret=1
    fi
  else
    ewarn "Remote IPv6 RTCP proxy is not running"
    ret=1
  fi

EOF
    cat >>/etc/init.d/stun_client <<EOF
  return \$ret
}
EOF
    chmod +x /etc/init.d/stun_client

  elif echo "$OS" | egrep -qi 'debian|centos'; then
    cat >${CLIENT_WORK_DIR}/start.sh <<EOF
#!/bin/bash

SOCKS5_PORT=${SOCKS5_PORT}
EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
REMOTE_PORT_V4=${REMOTE_PORT_V4}
STUN_DOMAIN_V4=${STUN_DOMAIN_V4}
EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
REMOTE_PORT_V6=${REMOTE_PORT_V6}
STUN_DOMAIN_V6=${STUN_DOMAIN_V6}
EOF
    cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
WS_PATH=${WS_PATH}
GOST_PROG="${CLIENT_WORK_DIR}/gost"
GOST_LOCAL_PID="/var/run/gost-local.pid"
EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
GOST_REMOTE_PID_V4="/var/run/gost-remote-v4.pid"
EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
GOST_REMOTE_PID_V6="/var/run/gost-remote-v6.pid"
EOF
    cat >>${CLIENT_WORK_DIR}/start.sh <<EOF

start() {
  echo "Starting local SOCKS5 proxy..."
  \$GOST_PROG -D -L socks5://[::1]:\${SOCKS5_PORT} >/dev/null 2>&1 &
  echo \$! > \$GOST_LOCAL_PID

EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
  echo "Starting remote IPv4 RTCP proxy..."
  \$GOST_PROG -D -L rtcp://:\${REMOTE_PORT_V4}/[::1]:\${SOCKS5_PORT} -F "relay+ws://\${STUN_DOMAIN_V4}:80?path=/\${WS_PATH}&host=\${STUN_DOMAIN_V4}" >/dev/null 2>&1 &
  echo \$! > \$GOST_REMOTE_PID_V4

EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
  echo "Starting remote IPv6 RTCP proxy..."
  \$GOST_PROG -D -L rtcp://:\${REMOTE_PORT_V6}/[::1]:\${SOCKS5_PORT} -F "relay+ws://\${STUN_DOMAIN_V6}:80?path=/\${WS_PATH}&host=\${STUN_DOMAIN_V6}" >/dev/null 2>&1 &
  echo \$! > \$GOST_REMOTE_PID_V6

EOF
    cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
}

stop() {
  echo "Stopping local SOCKS5 proxy..."
  if [ -f "\$GOST_LOCAL_PID" ]; then
    kill \$(cat \$GOST_LOCAL_PID)
    rm \$GOST_LOCAL_PID
  fi

EOF
    [ -n "$STUN_DOMAIN_V4" ] && cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
  echo "Stopping remote IPv4 RTCP proxy..."
  if [ -f "\$GOST_REMOTE_PID_V4" ]; then
    kill \$(cat \$GOST_REMOTE_PID_V4)
    rm \$GOST_REMOTE_PID_V6
  fi

EOF
    [ -n "$STUN_DOMAIN_V6" ] && cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
  echo "Stopping remote IPv6 RTCP proxy..."
  if [ -f "\$GOST_REMOTE_PID_V6" ]; then
    kill \$(cat \$GOST_REMOTE_PID_V6)
    rm \$GOST_REMOTE_PID_V6
  fi

EOF
    cat >>${CLIENT_WORK_DIR}/start.sh <<EOF
}

case "\$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    start
    ;;
  *)
    echo "Usage: \$0 {start|stop|restart}"
    exit 1
    ;;
esac

exit 0
EOF
    chmod +x ${CLIENT_WORK_DIR}/start.sh

    cat >/etc/systemd/system/stun_client.service <<EOF
[Unit]
Description=STUN Return Client Service
After=network.target

[Service]
Type=forking
ExecStart=${CLIENT_WORK_DIR}/start.sh start
ExecStop=${CLIENT_WORK_DIR}/start.sh stop
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  fi
}

# 客户端卸载函数
client_uninstall() {
  client_stop
  if echo "$OS" | grep -qi 'alpine'; then
    [ -d ${CLIENT_WORK_DIR} ] && rm -rf ${CLIENT_WORK_DIR} /etc/init.d/stun_client
  elif echo "$OS" | egrep -qi 'debian|centos'; then
    [ -s /etc/systemd/system/stun_client.service ] && rm -f /etc/systemd/system/stun_client.service
    [ -d ${CLIENT_WORK_DIR} ] && rm -rf ${CLIENT_WORK_DIR}
  else
    echo "Error: 未知的操作系统。" && exit 1
  fi
  echo "stun_return 客户端已卸载。"
}

# 客户端启动函数
client_start() {
  if echo "$OS" | grep -qi 'alpine'; then
    rc-update add stun_client default
    rc-service stun_client start
  elif echo "$OS" | egrep -qi 'debian|centos'; then
    systemctl enable --now stun_client
  else
    echo "Error: 未知的操作系统。" && exit 1
  fi
  echo -e "\n客户端已启动。"
}

# 客户端停止函数
client_stop() {
  if echo "$OS" | grep -qi 'alpine'; then
    rc-service stun_client stop
    rc-update del stun_client default
  elif echo "$OS" | egrep -qi 'debian|centos'; then
    systemctl disable --now stun_client
  else
    echo "Error: 未知的操作系统。" && exit 1
  fi
  echo -e "\n客户端已停止。"
}

# 主程序开始

# 检查系统环境
check_os
check_install
check_arch

# 处理命令行参数
while getopts ":uhscn4:6:p:w:r:e:" OPTNAME; do
  case "${OPTNAME,,}" in
    'h')
      echo -e "\n用法: bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) [选项]"
      echo -e "\n选项:"
      echo -e "  -h\t\t显示帮助信息"
      echo -e "  -u\t\t卸载 stun_return (服务端和客户端)"
      echo -e "  -w\t\t服务端的 ws 路径 (服务端和客户端)"
      echo -e "  -4\t\t服务端的 IPv4 DDNS tunnel 域名 (服务端和客户端)"
      echo -e "  -6\t\t服务端的 IPv6 DDNS tunnel 域名 (服务端和客户端)"
      echo -e "  -r\t\tIPv4 映射服务端使用的 socks5 端口 (服务端和客户端)"
      echo -e "  -e\t\tIPv6 映射服务端使用的 socks5 端口 (服务端和客户端)"
      echo -e "  -s\t\t安装服务端"
      echo -e "  -p\t\t服务端的端口 (服务端)"
      echo -e "  -n\t\t显示客户端安装命令 (服务端)"
      echo -e "  -c\t\t安装客户端"
      echo -e "\n示例:"
      echo -e "  安装服务端: bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -s -p 20000 -4 v4.stun.com -6 v6.stun.com -w 3b451552-e776-45c5-9b98-bde3ab99bf75"
      echo -e "\n  安装客户端: bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -c -4 v4.stun.com -r 30000 -6 v6.stun.com -e 30001 -w 3b451552-e776-45c5-9b98-bde3ab99bf75"
      echo -e "\n  卸载 stun_return: bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -u"
      echo ""
      exit 0
      ;;
    'u')
      echo $IS_INSTALL_SERVER | grep -q 'installed' && server_uninstall
      echo $IS_INSTALL_CLIENT | grep -q 'installed' && client_uninstall
      exit 0
      ;;
    's')
      CHOOSE=1
      ;;
    'c')
      CHOOSE=2
      ;;
    '4')
      IGNORE_STUN_DOMAIN_V6_INPUT=ignore_stun_domain_v6_input
      STUN_DOMAIN_V4_INPUT="$OPTARG"
      ;;
    '6')
      IGNORE_STUN_DOMAIN_V4_INPUT=ignore_stun_domain_v4_input
      STUN_DOMAIN_V6_INPUT="$OPTARG"
      ;;
    'p')
      STUN_PORT_INPUT="$OPTARG"
      ;;
    'w')
      WS_PATH_INPUT="$OPTARG"
      ;;
    'r')
      REMOTE_PORT_INPUT_V4="$OPTARG"
      ;;
    'e')
      REMOTE_PORT_INPUT_V6="$OPTARG"
      ;;
    'n')
      show_client_cmd
      exit 0
      ;;
  esac
done

# 主菜单逻辑
if [[ "${IS_INSTALL_SERVER}@${IS_INSTALL_CLIENT}" =~ 'installed' ]]; then
  # 已安装情况下的菜单选项
  until echo "$CHOOSE" | egrep -qiw '[1-6]'; do
    description
    echo -e "\n检测到已安装 stun_return\n1. 开启服务端\n2. 停止服务端\n3. 开启客户端\n4. 停止客户端\n5. 卸载服务端和服务端\n6. 退出" && read -rp "请选择: " CHOOSE
    echo "$CHOOSE" | egrep -qiw '[1-6]' && break || { echo "Error: 请输入正确的数字。" && sleep 1; }
  done
  case "$CHOOSE" in
    1)
      server_start
      exit 0
      ;;
    2)
      server_stop
      exit 0
      ;;
    3)
      client_start
      exit 0
      ;;
    4)
      client_stop
      exit 0
      ;;
    5)
      echo $IS_INSTALL_SERVER | grep -q 'installed' && server_uninstall
      echo $IS_INSTALL_CLIENT | grep -q 'installed' && client_uninstall
      exit 0
      ;;
    6)
      exit 0
      ;;
  esac
else
  # 未安装情况下的菜单选项
  until echo "$CHOOSE" | egrep -qiw '[1-3]'; do
    description
    echo -e "\n1. 安装服务端\n2. 安装客户端\n3. 退出" && read -rp "请选择: " CHOOSE
    echo "$CHOOSE" | egrep -qiw '[1-3]' && break || { echo "Error: 请输入正确的数字。" && sleep 1; }
  done
  case "$CHOOSE" in
    1)
      server_install
      server_start
      exit 0
      ;;
    2)
      client_install
      client_start
      exit 0
      ;;
    3)
      exit 0
      ;;
  esac
fi