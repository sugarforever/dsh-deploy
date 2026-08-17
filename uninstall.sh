#!/usr/bin/env bash
set -Eeuo pipefail

DSH_ROOT=${DSH_ROOT:-}
DSH_USER=${DSH_USER:-dsh}
root_path() { printf '%s%s' "$DSH_ROOT" "$1"; }

if [[ ${DSH_TEST_MODE:-0} != 1 && $EUID -ne 0 ]]; then
  printf 'Run as root: sudo ./uninstall.sh [--purge]\n' >&2
  exit 1
fi

purge=false
case ${1:-} in
  '') ;;
  --purge) purge=true ;;
  *) printf 'Usage: sudo ./uninstall.sh [--purge]\n' >&2; exit 2 ;;
esac

systemctl disable --now dsh.service 2>/dev/null || true
rm -f "$(root_path /etc/systemd/system/dsh.service)"
systemctl daemon-reload
rm -rf "$(root_path /opt/dsh)"

if [[ $purge == true ]]; then
  rm -rf "$(root_path /var/lib/dsh)" "$(root_path /etc/dsh)"
  userdel "$DSH_USER" 2>/dev/null || true
  printf 'Removed DSH, its configuration, data, and system user.\n'
else
  printf 'Removed DSH. Preserved /var/lib/dsh and /etc/dsh.\n'
  printf 'Use --purge to remove preserved data and the dsh user.\n'
fi
