# ShipNode TODO

## Scope
- Focus on new UX and safety features not already present in the codebase.
- Avoid duplicating existing commands/config validation (see `lib/commands/doctor.sh`, `lib/commands/init.sh`, `lib/commands/config.sh`).

## Planned Features

### 1) GitHub Actions Generator ✅ COMPLETED
- Add `shipnode ci github` to scaffold a minimal deploy workflow.
- Output a workflow that:
  - Installs dependencies.
  - Runs build (if defined).
  - Uses `shipnode deploy` via SSH.
- Document required secrets (SSH key, host, user, port).
- **Bonus**: Added `shipnode ci env-sync` to sync shipnode.conf and .env to GitHub secrets with auto-installation of gh CLI.

### 2) Security Hardening (Minimal) ✅ COMPLETED
- Add `shipnode harden` to apply basic server hardening:
  - SSH: non-default port (optional), disable password auth (optional), disable root login (optional).
  - Firewall: allow SSH + 80/443; deny all other inbound.
  - Install and configure fail2ban (optional).
- Ensure all changes are opt-in with clear prompts and rollback hints.

### 3) Doctor Security Audit ✅ COMPLETED
- Add `shipnode doctor --security` for non-destructive checks:
  - SSH config posture (root login, password auth, port).
  - Firewall status and allowed ports.
  - Fail2ban status (if installed).
  - File permissions for `shipnode.conf` and `.env` (if local).
- Output actionable warnings with recommended commands.

### 4) Config UX Improvements ✅ COMPLETED
- Support `--config <path>` for all commands (default `shipnode.conf`).
- Allow profile configs: `shipnode.<env>.conf` (e.g., staging, prod).
- Add `shipnode init --print` to emit config without writing a file.

### 5) Deploy Dry Run ✅ COMPLETED
- Add `shipnode deploy --dry-run` to show:
  - Resolved config values (redacting secrets).
  - Local build commands to be executed.
  - Remote commands and rsync targets.
  - Zero-downtime flow steps if enabled.
  - Supports both backend and frontend apps, zero-downtime and legacy modes.
## Docs Updates ✅ COMPLETED
- Update `README.md` with new command flags and examples.
  - Added all new flags: --dry-run, --security, --print, --config
  - Added new commands: ci github, ci env-sync, harden
  - Added comprehensive examples for each feature
- Add a short "Security Baseline" section.
  - Documented `shipnode harden` command with opt-in hardening options
  - Documented `shipnode doctor --security` audit with checks for SSH, firewall, fail2ban
  - Added configuration profiles section with --config flag usage
  - Moved zero-downtime deployment docs to proper section
  - Added CI/CD Integration section with GitHub Actions workflow generator
  - Added Deploy Preview (dry-run) documentation with example output
