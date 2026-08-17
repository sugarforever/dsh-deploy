#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
FAKE_BIN="$TEST_DIR/bin"
ROOT="$TEST_DIR/root"
LOG="$TEST_DIR/commands.log"
mkdir -p "$FAKE_BIN" "$ROOT/opt/dsh" "$ROOT/var/lib/dsh" "$ROOT/etc/dsh" "$ROOT/etc/systemd/system"
touch "$ROOT/opt/dsh/old" "$ROOT/var/lib/dsh/data" "$ROOT/etc/dsh/dsh.env" "$ROOT/etc/systemd/system/dsh.service"

cat >"$FAKE_BIN/npm" <<'EOF'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >>"$DSH_TEST_LOG"
EOF
for command in systemctl chown userdel; do
  cat >"$FAKE_BIN/$command" <<EOF
#!/usr/bin/env bash
printf '$command %s\\n' "\$*" >>"\$DSH_TEST_LOG"
EOF
done
chmod +x "$FAKE_BIN"/*

env_args=(PATH="$FAKE_BIN:/usr/bin:/bin" DSH_TEST_MODE=1 DSH_TEST_LOG="$LOG" DSH_ROOT="$ROOT")

env "${env_args[@]}" bash "$REPO_DIR/update.sh" 9.8.7
grep -Fq 'npm install --omit=dev --save-exact @deepseek-ai/dsh@9.8.7' "$LOG"
grep -Fq "chown -R root:root $ROOT/opt/dsh" "$LOG"
grep -Fq 'systemctl restart dsh.service' "$LOG"

env "${env_args[@]}" bash "$REPO_DIR/uninstall.sh"
[[ ! -e $ROOT/opt/dsh ]]
[[ -e $ROOT/var/lib/dsh/data ]]
[[ -e $ROOT/etc/dsh/dsh.env ]]

mkdir -p "$ROOT/opt/dsh"
env "${env_args[@]}" bash "$REPO_DIR/uninstall.sh" --purge
[[ ! -e $ROOT/var/lib/dsh ]]
[[ ! -e $ROOT/etc/dsh ]]
grep -Fq 'userdel dsh' "$LOG"

printf 'PASS: update and uninstall lifecycle behavior\n'
