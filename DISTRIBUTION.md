# ShipNode Distribution System

This document explains the distribution system for ShipNode, allowing users to install it without cloning the repository.

## Overview

The distribution system packages ShipNode into a single self-extracting installer that users can download and run. This makes installation as simple as:

```bash
curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
```

## How It Works

### Self-Extracting Archive

The installer (`shipnode-installer.sh`) is a **self-extracting archive** that:
1. Contains the installer script at the top
2. Contains a base64-encoded tar.gz archive at the bottom
3. When run, extracts itself and installs ShipNode

### Build Process

```
Source Files → build-dist.sh → dist/shipnode-installer.sh
```

**Files included in distribution:**
- `shipnode` - Main executable script
- `install.sh` - Source installation script
- `uninstall.sh` - Uninstaller
- `shipnode.conf.example` - Configuration example
- `templates/` - PM2 and Caddy templates
- `LICENSE` - MIT license
- `README.md` - Documentation
- `INSTALL.md` - Installation guide

### Installation Flow

```
User downloads installer
         ↓
Runs shipnode-installer.sh
         ↓
Extracts to temp directory
         ↓
Installs to ~/.shipnode
         ↓
Adds PATH entry to ~/.bashrc (and ~/.zshrc if present)
         ↓
Verification & cleanup
         ↓
ShipNode ready to use
```

## Building the Distribution

### Requirements

- bash
- tar
- base64 (from coreutils)

### Build Commands

```bash
# Using make
make build

# Or directly
./build-dist.sh

# Clean dist directory
make clean
```

### Output

Creates `dist/shipnode-installer.sh` (~21KB)

## Distribution Methods

### 1. GitHub Releases (Recommended)

**Automatic:**
- Push a git tag (e.g., `v1.0.0`)
- GitHub Actions automatically builds and creates a release
- Installer uploaded as `shipnode-installer.sh`

**Manual:**
1. Build: `make build`
2. Create release on GitHub
3. Upload `dist/shipnode-installer.sh`

Users install with:
```bash
curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
```

### 2. Direct Download

Host `shipnode-installer.sh` anywhere and users can:

```bash
wget https://your-domain.com/shipnode-installer.sh
chmod +x shipnode-installer.sh
./shipnode-installer.sh
```

### 3. Package Managers (Future)

Future distribution options:
- **Homebrew**: Create a formula
- **APT**: Create .deb package
- **npm**: Publish as global package
- **Snap**: Create snap package

## Files Structure

```
shipnode/
├── shipnode                      # Main executable
├── install.sh                    # Local installer
├── uninstall.sh                  # Uninstaller
├── build-dist.sh                 # Distribution builder
├── Makefile                      # Build automation
├── shipnode.conf.example         # Config template
├── templates/                    # Caddy/PM2 templates
│   ├── ecosystem.config.js.template
│   ├── Caddyfile.backend.template
│   └── Caddyfile.frontend.template
├── .github/
│   └── workflows/
│       └── release.yml           # Auto-release workflow
├── README.md                     # Main documentation
├── INSTALL.md                    # Installation guide
├── RELEASE.md                    # Release process
├── DISTRIBUTION.md               # This file
└── dist/                         # Build output (gitignored)
    └── shipnode-installer.sh     # Self-extracting installer
```

## Installation Defaults

The installer always uses a Linux-safe default:

- **Install path**: `$HOME/.shipnode`
- **Permissions**: No sudo required
- **PATH update**: Adds `export PATH="$HOME/.shipnode:$PATH"` to `~/.bashrc` (and `~/.zshrc` if present)
- **Uninstall**: `rm -rf ~/.shipnode` and remove the PATH entry

## Testing the Installer

Before releasing:

```bash
# Build
make build

# Test in a clean environment
docker run -it --rm -v "$PWD/dist:/dist" ubuntu:latest bash
cd /dist
bash shipnode-installer.sh

# Or test locally
bash dist/shipnode-installer.sh
# Verify it installs to ~/.shipnode
```

## Updating the Installer

When making changes:

1. Update source files (shipnode, templates, etc.)
2. Update version in:
   - `shipnode` (line 13)
   - `install.sh` (line 13)
   - `build-dist.sh` (line 8)
3. Build: `make build`
4. Test: `bash dist/shipnode-installer.sh`
5. Commit and tag: `git tag vX.X.X && git push --tags`

## GitHub Actions Workflow

`.github/workflows/release.yml` automates releases:

```yaml
Trigger: Push tag (v*)
  ↓
Checkout code
  ↓
Build distribution
  ↓
Create GitHub release
  ↓
Upload installer asset
```

## Advantages of This Approach

✅ **Single file download** - Easy to distribute
✅ **No dependencies** - Pure bash, works everywhere
✅ **Self-contained** - Includes everything needed
✅ **Small size** - ~21KB compressed
✅ **Interactive** - Guides users through installation
✅ **Flexible** - Multiple install locations and PATH options
✅ **Automatic** - GitHub Actions handles releases
✅ **Verifiable** - Users can inspect before running

## Security Considerations

1. **Checksum verification** (future):
   ```bash
   curl -fsSL url/shipnode-installer.sh.sha256 | sha256sum -c
   ```

2. **GPG signing** (future):
   ```bash
   gpg --verify shipnode-installer.sh.sig shipnode-installer.sh
   ```

3. **Review before piping to bash**:
   ```bash
   # Download first
   wget https://url/shipnode-installer.sh
   # Review
   less shipnode-installer.sh
   # Then run
   bash shipnode-installer.sh
   ```

## Troubleshooting

### Build fails

- Check bash version: `bash --version`
- Check tar: `tar --version`
- Check base64: `base64 --version`

### Installer fails

- Check extraction: Look for temp directory issues
- Check permissions: Ensure write access to install location
- Check PATH: Verify shell configuration

### Size too large

The installer should be ~20-30KB. If larger:
- Check for unnecessary files in package
- Verify .gitignore excludes node_modules, .git, etc.

## Future Enhancements

- [ ] Checksum verification
- [ ] GPG signing
- [ ] Progress indicators
- [ ] Automatic updates check
- [ ] Homebrew formula
- [ ] APT/RPM packages
- [ ] Docker image
- [ ] npm global package
