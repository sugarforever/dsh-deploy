#!/usr/bin/env bash
set -Eeuo pipefail

DSH_VERSION=${1:-${DSH_VERSION:-0.1.0-rc.7}}
DSH_PACKAGE=${DSH_PACKAGE:-@deepseek-ai/dsh}
DSH_INSTALL_DIR=/opt/dsh
DSH_ROOT=${DSH_ROOT:-}

root_path() { printf '%s%s' "$DSH_ROOT" "$1"; }

if [[ ${DSH_TEST_MODE:-0} != 1 && $EUID -ne 0 ]]; then
  printf 'Run as root: sudo ./update.sh [version]\n' >&2
  exit 1
fi

[[ -d $(root_path "$DSH_INSTALL_DIR") ]] || { printf 'DSH is not installed at %s\n' "$DSH_INSTALL_DIR" >&2; exit 1; }

cd "$(root_path "$DSH_INSTALL_DIR")"
npm install --omit=dev --save-exact "$DSH_PACKAGE@$DSH_VERSION"
chown -R root:root "$(root_path "$DSH_INSTALL_DIR")"
chmod -R go-w "$(root_path "$DSH_INSTALL_DIR")"
systemctl restart dsh.service
if [[ ${DSH_TEST_MODE:-0} != 1 ]]; then
  systemctl --no-pager --full status dsh.service
fi
