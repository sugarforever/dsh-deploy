# DSH Cloud Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide an idempotent one-command installer that runs DeepSeek Harness continuously on Ubuntu or Debian with systemd, plus safe update and uninstall workflows.

**Architecture:** A self-contained `install.sh` creates a dedicated service account, installs a pinned npm package under `/opt/dsh`, persists application state in `/var/lib/dsh`, and writes a hardened systemd unit. Small shared shell functions keep validation and unit rendering testable without root; update and uninstall scripts preserve user data by default.

**Tech Stack:** POSIX-oriented Bash, npm/Node.js, systemd, shell integration tests.

## Global Constraints

- Support Ubuntu and Debian with systemd.
- Run DSH as a dedicated unprivileged `dsh` user.
- Pin `@deepseek-ai/dsh` to `0.1.0-rc.7` by default while allowing an explicit override.
- Persist DSH state at `/var/lib/dsh` and configuration at `/etc/dsh/dsh.env`.
- Bind the service lifecycle to systemd with automatic restart and restart-rate limiting.
- Re-running installation must preserve an existing environment file and application data.
- Uninstallation must preserve application data unless the user explicitly requests its removal.

---

### Task 1: Testable deployment primitives

**Files:**
- Create: `tests/test-common.sh`
- Create: `lib/common.sh`

**Interfaces:**
- Produces: `require_supported_node`, `render_systemd_unit`, and shared path/version defaults.

- [ ] Write tests that exercise accepted/rejected Node versions and assert the rendered unit's runtime user, paths, command, and restart policy.
- [ ] Run `bash tests/test-common.sh` and confirm it fails because `lib/common.sh` is absent.
- [ ] Implement the minimal shared functions.
- [ ] Re-run the test and confirm it passes.

### Task 2: Idempotent installer and service lifecycle scripts

**Files:**
- Create: `tests/test-install.sh`
- Create: `install.sh`
- Create: `update.sh`
- Create: `uninstall.sh`
- Create: `config/dsh.env.example`

**Interfaces:**
- Consumes: functions and defaults from `lib/common.sh` when locally available.
- Produces: root-only installer/update/uninstaller commands and the `dsh.service` systemd unit.

- [ ] Write a sandboxed integration test using fake system commands and a temporary root, covering first install, repeat install, environment preservation, and generated service configuration.
- [ ] Run the integration test and confirm it fails because the installer is absent.
- [ ] Implement the smallest safe, idempotent install/update/uninstall workflows that satisfy the test.
- [ ] Run both test files and shell syntax checks.

### Task 3: Reader-facing deployment documentation

**Files:**
- Create: `README.md`

**Interfaces:**
- Documents the scripts and operational commands produced by Tasks 1 and 2.

- [ ] Document prerequisites, the auditable download-first path, and the requested direct command: `curl -fsSL https://raw.githubusercontent.com/sugarforever/dsh-deploy/main/install.sh | sudo bash`.
- [ ] Document configuration, service control, logs, upgrades, uninstall behavior, network safety, paths, and troubleshooting.
- [ ] Run all automated tests, `bash -n` over every shell file, and inspect the final diff against the referenced design.
