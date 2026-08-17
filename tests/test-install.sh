#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

FAKE_BIN="$TEST_DIR/bin"
ROOT="$TEST_DIR/root"
LOG="$TEST_DIR/commands.log"
mkdir -p "$FAKE_BIN" "$ROOT"

cat >"$FAKE_BIN/node" <<'EOF'
#!/usr/bin/env bash
printf 'v22.19.0\n'
EOF

cat >"$FAKE_BIN/npm" <<'EOF'
#!/usr/bin/env bash
set -e
printf 'npm %s\n' "$*" >>"$DSH_TEST_LOG"
mkdir -p node_modules/.bin
cat >node_modules/.bin/dsh <<'BIN'
#!/usr/bin/env bash
exit 0
BIN
chmod +x node_modules/.bin/dsh
EOF

cat >"$FAKE_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$DSH_TEST_LOG"
EOF

cat >"$FAKE_BIN/id" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == -gn && -f $DSH_TEST_USER_STATE ]]; then
  printf 'dsh\n'
  exit 0
fi
[[ -f $DSH_TEST_USER_STATE ]]
EOF

cat >"$FAKE_BIN/useradd" <<'EOF'
#!/usr/bin/env bash
[[ ! -f $DSH_TEST_USER_STATE ]] || exit 9
printf 'useradd %s\n' "$*" >>"$DSH_TEST_LOG"
touch "$DSH_TEST_USER_STATE"
EOF

cat >"$FAKE_BIN/getent" <<'EOF'
#!/usr/bin/env bash
[[ -f $DSH_TEST_GROUP_STATE ]]
EOF

cat >"$FAKE_BIN/groupadd" <<'EOF'
#!/usr/bin/env bash
printf 'groupadd %s\n' "$*" >>"$DSH_TEST_LOG"
touch "$DSH_TEST_GROUP_STATE"
EOF

cat >"$FAKE_BIN/chown" <<'EOF'
#!/usr/bin/env bash
printf 'chown %s\n' "$*" >>"$DSH_TEST_LOG"
EOF

chmod +x "$FAKE_BIN"/*

run_installer() {
  PATH="$FAKE_BIN:/usr/bin:/bin" \
    DSH_TEST_MODE=1 \
    DSH_TEST_LOG="$LOG" \
    DSH_TEST_USER_STATE="$TEST_DIR/user-created" \
    DSH_TEST_GROUP_STATE="$TEST_DIR/group-created" \
    DSH_ROOT="$ROOT" \
    bash "$REPO_DIR/install.sh"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f $1 ]] || fail "missing file: $1"
}

assert_contains() {
  grep -Fq "$2" "$1" || fail "expected $1 to contain: $2"
}

run_installer

assert_file "$ROOT/opt/dsh/node_modules/.bin/dsh"
assert_file "$ROOT/etc/dsh/dsh.env"
assert_file "$ROOT/etc/systemd/system/dsh.service"
assert_contains "$ROOT/etc/systemd/system/dsh.service" 'ExecStart=/opt/dsh/node_modules/.bin/dsh web'
assert_contains "$ROOT/etc/systemd/system/dsh.service" 'Restart=always'
assert_contains "$ROOT/etc/systemd/system/dsh.service" "Environment=PATH=$FAKE_BIN:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
assert_contains "$LOG" 'npm install --omit=dev --save-exact @deepseek-ai/dsh@0.1.0-rc.7'
assert_contains "$LOG" 'systemctl enable dsh.service'
assert_contains "$LOG" 'systemctl restart dsh.service'
assert_contains "$LOG" "chown -R root:root $ROOT/opt/dsh"

printf 'CUSTOM_SETTING=keep-me\n' >"$ROOT/etc/dsh/dsh.env"
run_installer
assert_contains "$ROOT/etc/dsh/dsh.env" 'CUSTOM_SETTING=keep-me'
[[ $(grep -c '^useradd ' "$LOG") -eq 1 ]] || fail 'useradd should run exactly once'
[[ $(grep -c '^groupadd ' "$LOG") -eq 1 ]] || fail 'groupadd should run exactly once'

printf 'PASS: idempotent installer behavior\n'
