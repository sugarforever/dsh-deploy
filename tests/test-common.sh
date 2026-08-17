#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1 needle=$2
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_success() {
  "$@" >/dev/null 2>&1 || fail "expected success: $*"
}

assert_failure() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

assert_success require_supported_node 22.19.0
assert_success require_supported_node 22.20.1
assert_success require_supported_node 24.0.0
assert_success require_supported_node 25.3.1
assert_failure require_supported_node 22.18.9
assert_failure require_supported_node 23.9.0
assert_failure require_supported_node invalid

unit=$(render_systemd_unit)
assert_contains "$unit" 'User=dsh'
assert_contains "$unit" 'WorkingDirectory=/opt/dsh'
assert_contains "$unit" 'EnvironmentFile=-/etc/dsh/dsh.env'
assert_contains "$unit" 'Environment=DSH_HOME=/var/lib/dsh'
assert_contains "$unit" 'Environment=PATH=/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin'
assert_contains "$unit" 'ExecStart=/opt/dsh/node_modules/.bin/dsh web'
assert_contains "$unit" 'Restart=always'
assert_contains "$unit" 'RestartSec=5'
assert_contains "$unit" 'StartLimitIntervalSec=300'
assert_contains "$unit" 'StartLimitBurst=10'

printf 'PASS: common deployment behavior\n'
