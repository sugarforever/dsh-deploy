#!/usr/bin/env bash

DSH_PACKAGE=${DSH_PACKAGE:-@deepseek-ai/dsh}
DSH_VERSION=${DSH_VERSION:-0.1.0-rc.7}
DSH_USER=${DSH_USER:-dsh}
DSH_GROUP=${DSH_GROUP:-dsh}
DSH_INSTALL_DIR=${DSH_INSTALL_DIR:-/opt/dsh}
DSH_HOME_DIR=${DSH_HOME_DIR:-/var/lib/dsh}
DSH_CONFIG_DIR=${DSH_CONFIG_DIR:-/etc/dsh}
DSH_ENV_FILE=${DSH_ENV_FILE:-$DSH_CONFIG_DIR/dsh.env}
DSH_NODE_BIN_DIR=${DSH_NODE_BIN_DIR:-/usr/bin}

require_supported_node() {
  local version=${1#v} major minor patch
  IFS=. read -r major minor patch <<<"$version"

  [[ $major =~ ^[0-9]+$ && $minor =~ ^[0-9]+$ && $patch =~ ^[0-9]+$ ]] || return 1
  if (( major == 22 && minor >= 19 )); then
    return 0
  fi
  (( major >= 24 ))
}

render_systemd_unit() {
  cat <<EOF
[Unit]
Description=DeepSeek Harness Web
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=10

[Service]
Type=simple
User=$DSH_USER
Group=$DSH_GROUP
WorkingDirectory=$DSH_INSTALL_DIR
EnvironmentFile=-$DSH_ENV_FILE
Environment=DSH_HOME=$DSH_HOME_DIR
Environment=PATH=$DSH_NODE_BIN_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
ExecStart=$DSH_INSTALL_DIR/node_modules/.bin/dsh web
Restart=always
RestartSec=5
TimeoutStopSec=30
KillSignal=SIGTERM
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=$DSH_HOME_DIR

[Install]
WantedBy=multi-user.target
EOF
}
