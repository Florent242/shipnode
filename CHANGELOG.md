# Changelog

All notable changes to ShipNode will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### ORM Detection
- **ORM auto-detection**: `detect_orm()` identifies Prisma, Drizzle, TypeORM, Sequelize, Knex, Mongoose, and AdonisJS Lucid from package.json dependencies
- **Migration command generation**: Returns ORM-specific migration and generate commands for deployment hooks

#### Smart Deployment Hooks
- **Auto-generated hooks**: `shipnode init` creates `.shipnode/pre-deploy.sh` and `post-deploy.sh` with ORM-aware templates
- **ORM-specific migrations**: Pre-deploy hook includes commented migration commands for 6 ORMs, auto-uncommented for detected ORM
- **Shared environment access**: Hooks can access `$SHARED_ENV_PATH` for database credentials

#### User Provisioning
- `create_remote_user()`: Creates deployment users on remote server
- `setup_user_ssh_dir()`: Configures SSH directory with correct permissions
- `add_user_ssh_key()`: Adds authorized SSH keys for user access
- `grant_deploy_permissions()`: Sets up deploy path ownership
- `grant_sudo_access()`: Configures passwordless sudo for PM2 and Caddy
- `revoke_user_access()`: Removes users and cleans up SSH keys

#### Interactive Initialization Wizard
- **Framework auto-detection**: Automatically detects Express, NestJS, Fastify, Koa, Hapi, Hono, AdonisJS, Next.js, Nuxt, Remix, Astro, React, React Router, TanStack Router, Vue, Svelte, SolidJS, and Angular from package.json dependencies
- **Smart defaults**: Auto-suggests app type (backend/frontend) based on detected framework
- **Port detection**: Attempts to detect application port from package.json scripts
- **Guided prompts**: Step-by-step configuration with validation and helpful defaults
- **Input validation**: Real-time validation for IP addresses, hostnames, ports, domains, and PM2 app names
- **Configuration summary**: Review all settings before creating shipnode.conf
- **User-friendly interface**: Colored output, clear instructions, and error messages
- **Integrated users.yml wizard**: Optionally set up deployment users in one flow
- **Backward compatible**: Use `shipnode init --non-interactive` for legacy non-interactive behavior

#### Framework Detection Functions
- `detect_framework()`: Parses package.json to identify framework and suggest app type
- `parse_package_json()`: Safely extracts dependencies using jq
- `suggest_app_type()`: Determines backend vs frontend based on dependencies
- `suggest_port()`: Auto-detects port from npm scripts patterns

#### Validation Functions
- `validate_ip_or_hostname()`: Validates IPv4 addresses and hostnames
- `validate_port()`: Ensures valid port range (1-65535)
- `validate_domain()`: Validates domain names (no protocol prefix)
- `validate_pm2_app_name()`: Ensures valid PM2 process names
- `test_ssh_connection()`: Optional SSH connectivity test

#### Interactive Prompt Helpers
- `prompt_with_default()`: Generic prompt with default value support
- `prompt_with_validation()`: Prompt with automatic validation retry loop

#### Gum UI Framework Integration
- **Enhanced interactive wizard**: Beautiful UI powered by [charmbracelet/gum](https://github.com/charmbracelet/gum) with graceful fallback to classic bash prompts
- **Automatic installation**: Gum is automatically installed during `shipnode setup` on supported platforms (Debian/Ubuntu, RedHat/Fedora, Arch, Alpine, macOS)
- **Multi-platform support**: OS and package manager detection (apt, yum, dnf, brew, apk, pacman)
- **Non-blocking**: Wizard continues with classic prompts if Gum installation fails
- **Gum wrappers**: `gum_input()`, `gum_choose()`, `gum_confirm()`, `gum_style()` functions with automatic fallback

#### Port Conflict Detection
- **Port conflict detection**: Deployment checks if backend port is already in use on remote server
- **Smart redeployment**: Allows redeployment when port is owned by the same PM2 app; blocks when owned by a different process
- **Suggested ports**: Shows available alternative ports when conflict is detected

#### Local .env Support
- **ENV_FILE support**: `load_config()` sources local `.env` before loading `shipnode.conf` — config values can reference env vars (e.g. `DB_PASSWORD=${DB_PASSWORD}`)

### Changed
- **Installer workflow simplified**: Default install now uses `~/.shipnode` with PATH updates in `~/.bashrc` (and `~/.zshrc` if present), removing install location prompts
- **Multi-app Caddy support**: Switched from monolithic `/etc/caddy/Caddyfile` to per-app configs in `/etc/caddy/conf.d/<app>.caddy` — supports multiple apps on one server
- **Development dependencies included**: Dependencies now installed without `--production`/`--prod`/`--omit=dev` flags so build tools (TypeScript, Prisma CLI, etc.) are available during deployment
- **Interactive init by default**: `shipnode init` now launches interactive wizard by default; use `--non-interactive` flag for legacy behavior
- **Expanded pre-deploy template**: Pre-deploy hook template includes commented migration commands for 6 ORMs
- **Hook documentation**: Rewrote hook documentation in `shipnode.conf.example` with `SHARED_ENV_PATH` usage
- **Hooks source server .env**: Deployment hooks now source `shared/.env` on the server before execution — hooks use same env as the running app

### Fixed
- **Hook error handling**: Hook execution now checks SSH exit code instead of grepping output for "SUCCESS" — fixes masked failures
- **Pre-deploy hook validation**: Added missing `return 1` after failed scp in pre-deploy hook template
- **PM2 "Script not found" error**: Fixed ecosystem config template using `script: 'start'` instead of `script: 'npm', args: 'start'`; ecosystem file now always regenerated on deploy
- **PM2 cwd path in zero-downtime deploy**: Fixed working directory pointing to wrong path
- **Hook scp failures visible**: Show scp copy failure output instead of silently continuing

#### GitHub Actions Generator
- **`shipnode ci github`**: Scaffold a minimal GitHub Actions deployment workflow
  - Creates `.github/workflows/deploy.yml` with SSH-based deployment
  - Workflow installs dependencies, runs build, and executes `shipnode deploy`
  - Documents required GitHub secrets (SSH_PRIVATE_KEY, SSH_HOST, SSH_USER, SSH_PORT)
- **`shipnode ci env-sync`**: Sync `shipnode.conf` values to GitHub repository secrets
  - Automatically installs `gh` CLI if not present
  - Syncs SSH_HOST, SSH_USER, and SSH_PORT as individual secrets
  - `--all` flag additionally syncs `.env` file as base64-encoded secret

#### Security Hardening
- **`shipnode harden`**: Interactive server security hardening command
  - **SSH hardening**: Optionally change SSH port, disable password authentication, disable root login
  - **Firewall setup**: Configure UFW to allow only SSH, HTTP, and HTTPS; deny all other inbound traffic
  - **Fail2Ban**: Optionally install and configure fail2ban for brute-force protection
  - All changes are opt-in with clear prompts and summary before application

#### Doctor Security Audit
- **`shipnode doctor --security`**: Non-destructive security posture audit
  - **SSH configuration audit**: Checks root login status, password authentication, and SSH port
  - **Firewall audit**: Verifies UFW status and allowed ports
  - **Fail2Ban audit**: Checks installation and service status
  - **File permissions**: Audits permissions for `shipnode.conf` and local `.env` files
  - Outputs actionable warnings with recommended commands for each issue

#### Config UX Improvements
- **`--config <path>` flag**: Support for custom configuration files across all commands
  - Default remains `shipnode.conf` in project root
  - Profile configs follow naming convention `shipnode.<env>.conf` (e.g., `shipnode.staging.conf`)
  - Enables multi-environment deployments without editing files
- **`shipnode init --print`**: Emit configuration to stdout without writing a file
  - Useful for CI/CD pipelines and configuration validation
  - Shows exactly what would be generated with current settings

#### Deploy Dry Run
- **`shipnode deploy --dry-run`**: Preview deployment steps without executing them
  - **Configuration preview**: Shows resolved config values with secrets redacted
  - **Build preview**: Displays local build commands to be executed (package manager, build command)
  - **Deployment preview**: Lists remote commands, rsync targets, and excluded patterns
  - **Zero-downtime flow**: Shows each step of the deployment flow with health check details
  - Supports both backend and frontend applications
  - Supports both zero-downtime and legacy deployment modes
  - Ideal for validating configuration before first deployment and CI/CD pipeline testing

## [1.1.0] - 2026-01-24

### Added

#### Zero-Downtime Deployment System
- **Release-based deployments**: Each deployment creates a timestamped release in `releases/` directory
- **Atomic symlink switching**: `current` symlink points to active release, switched atomically for zero downtime
- **Release directory structure**:
  - `releases/YYYYMMDDHHMMSS/` - Timestamped release directories
  - `current` - Symlink to active release
  - `shared/` - Shared resources (.env, logs) persisted across releases
  - `.shipnode/` - Deployment metadata (releases.json, deploy.lock)

#### Health Checks
- Automatic health check validation after backend deployments
- Configurable health endpoint, timeout, and retry count
- Automatic rollback to previous release on health check failure
- Health check verification after manual rollbacks

#### Release Management
- `shipnode rollback [N]` - Rollback to previous release or N steps back
- `shipnode releases` - List all available releases with current marker
- `shipnode migrate` - Migrate existing deployments to release structure
- Automatic cleanup of old releases (configurable retention)
- JSON-based release history tracking

#### Deployment Safety
- Deployment lock file prevents concurrent deployments
- Stale lock detection and automatic cleanup
- Per-release dependency installation (isolated node_modules)
- Shared .env file symlinking across releases

#### Configuration Options
- `ZERO_DOWNTIME` - Enable/disable zero-downtime deployment (default: true)
- `KEEP_RELEASES` - Number of releases to retain (default: 5)
- `HEALTH_CHECK_ENABLED` - Enable/disable health checks (default: true)
- `HEALTH_CHECK_PATH` - Health check endpoint path (default: /health)
- `HEALTH_CHECK_TIMEOUT` - Health check timeout in seconds (default: 30)
- `HEALTH_CHECK_RETRIES` - Number of retry attempts (default: 3)

#### Server Setup
- Automatic `jq` installation for JSON manipulation in release tracking

### Changed
- `shipnode setup` now installs `jq` for release management
- Caddy configuration updated to serve from `current/` symlink when zero-downtime is enabled
- `shipnode init` now includes zero-downtime config options in generated `shipnode.conf`
- `shipnode help` updated with new commands and configuration documentation

### Fixed
- Improved error handling for deployment failures
- Better concurrency control with deployment locks

### Documentation
- Comprehensive zero-downtime deployment guide in README
- Health check setup examples for Express and Fastify
- Migration instructions for existing deployments
- Troubleshooting section for new features
- Updated configuration reference
- Example workflows for deployments and rollbacks

### Backward Compatibility
- Fully backward compatible - existing deployments continue to work
- Zero-downtime can be disabled with `ZERO_DOWNTIME=false` for legacy behavior
- Migration command available for gradual adoption

## [1.0.0] - 2024-01-20

### Added
- Initial release of ShipNode
- Backend deployment support (Node.js + PM2)
- Frontend deployment support (static files)
- Automatic server setup (Node.js, PM2, Caddy)
- SSH-based deployment via rsync
- Caddy reverse proxy configuration for backends
- Caddy static file server for frontends
- PM2 process management
- Application status monitoring
- Log streaming for backend apps
- Restart and stop commands for backend apps
- Simple configuration via `shipnode.conf`

[1.1.0]: https://github.com/devalade/shipnode/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/devalade/shipnode/releases/tag/v1.0.0
