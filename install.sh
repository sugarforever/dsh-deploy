#!/usr/bin/env bash
set -Eeuo pipefail

DSH_PACKAGE=${DSH_PACKAGE:-@deepseek-ai/dsh}
DSH_VERSION=${DSH_VERSION:-0.1.0-rc.7}
DSH_USER=${DSH_USER:-dsh}
DSH_GROUP=${DSH_GROUP:-dsh}
DSH_INSTALL_DIR=/opt/dsh
DSH_HOME_DIR=/var/lib/dsh
DSH_CONFIG_DIR=/etc/dsh
DSH_ENV_FILE=$DSH_CONFIG_DIR/dsh.env
DSH_UNIT_FILE=/etc/systemd/system/dsh.service
DSH_ROOT=${DSH_ROOT:-}
DSH_NODE_BIN_DIR=${DSH_NODE_BIN_DIR:-}

log() { printf '[dsh-deploy] %s\n' "$*"; }
die() { printf '[dsh-deploy] ERROR: %s\n' "$*" >&2; exit 1; }
root_path() { printf '%s%s' "$DSH_ROOT" "$1"; }

require_root() {
  if [[ ${DSH_TEST_MODE:-0} != 1 && $EUID -ne 0 ]]; then
    die 'Run this installer as root (for example: sudo bash install.sh).'
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_supported_node() {
  local version=${1#v} major minor patch
  IFS=. read -r major minor patch <<<"$version"
  [[ $major =~ ^[0-9]+$ && $minor =~ ^[0-9]+$ && $patch =~ ^[0-9]+$ ]] || return 1
  (( (major == 22 && minor >= 19) || major >= 24 ))
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

main() {
  require_root
  require_command node
  require_command npm
  require_command systemctl
  require_command install
  require_command getent
  require_command groupadd
  require_command useradd

  local node_version
  node_version=$(node --version)
  require_supported_node "$node_version" || die "Node.js $node_version is unsupported; install Node.js 22.19+ or 24+."
  DSH_NODE_BIN_DIR=${DSH_NODE_BIN_DIR:-$(dirname "$(command -v node)")}
  if [[ ${DSH_TEST_MODE:-0} != 1 && ( $DSH_NODE_BIN_DIR == /root/* || $DSH_NODE_BIN_DIR == /home/* ) ]]; then
    die "Node.js must be installed system-wide; user-local Node found at $DSH_NODE_BIN_DIR."
  fi

  if ! getent group "$DSH_GROUP" >/dev/null 2>&1; then
    log "Creating system group: $DSH_GROUP"
    groupadd --system "$DSH_GROUP"
  fi

  if ! id "$DSH_USER" >/dev/null 2>&1; then
    log "Creating system user: $DSH_USER"
    useradd --system --gid "$DSH_GROUP" --home-dir "$DSH_HOME_DIR" --create-home --shell /usr/sbin/nologin "$DSH_USER"
  elif [[ $(id -gn "$DSH_USER") != "$DSH_GROUP" ]]; then
    die "Existing user $DSH_USER must have $DSH_GROUP as its primary group."
  fi

  install -d -m 0755 "$(root_path "$DSH_INSTALL_DIR")"
  install -d -m 0750 "$(root_path "$DSH_HOME_DIR")"
  install -d -m 0750 "$(root_path "$DSH_CONFIG_DIR")"

  if [[ ! -e $(root_path "$DSH_ENV_FILE") ]]; then
    cat >"$(root_path "$DSH_ENV_FILE")" <<'EOF'
# Environment variables read by DeepSeek Harness.
# Add secrets here, one KEY=value pair per line. Do not use shell `export`.
EOF
  else
    log "Keeping existing configuration: $DSH_ENV_FILE"
  fi

  chmod 0640 "$(root_path "$DSH_ENV_FILE")"
  chown -R "$DSH_USER:$DSH_GROUP" "$(root_path "$DSH_HOME_DIR")"
  chown "root:$DSH_GROUP" "$(root_path "$DSH_CONFIG_DIR")" "$(root_path "$DSH_ENV_FILE")"
  chown -R root:root "$(root_path "$DSH_INSTALL_DIR")"

  log "Installing $DSH_PACKAGE@$DSH_VERSION"
  (
    cd "$(root_path "$DSH_INSTALL_DIR")"
    npm install --omit=dev --save-exact "$DSH_PACKAGE@$DSH_VERSION"
  )
  chown -R root:root "$(root_path "$DSH_INSTALL_DIR")"
  chmod -R go-w "$(root_path "$DSH_INSTALL_DIR")"

  install -d -m 0755 "$(dirname "$(root_path "$DSH_UNIT_FILE")")"
  render_systemd_unit >"$(root_path "$DSH_UNIT_FILE")"
  chmod 0644 "$(root_path "$DSH_UNIT_FILE")"

  systemctl daemon-reload
  systemctl enable dsh.service
  systemctl restart dsh.service

  log "Installed and started dsh.service."
  log "Configuration: $DSH_ENV_FILE"
  log "Logs: journalctl -u dsh.service -f"
}

main "$@"
