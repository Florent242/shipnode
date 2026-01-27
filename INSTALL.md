# ShipNode Installation Guide

## Overview

ShipNode offers two installation workflows:

1. **For Users** - Install the bundled version via installer (recommended)
2. **For Developers** - Clone the repo and use the modular version

---

## For Users: Quick Install (Recommended)

Download and run the self-extracting installer:

```bash
curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
```

Or download manually:

```bash
wget https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh
chmod +x shipnode-installer.sh
./shipnode-installer.sh
```

The interactive installer will:
- Extract the bundled ShipNode to your chosen location
- Set up PATH or create a symlink
- Verify the installation

---

## For Developers: Install from Source

Clone the repository to work with the modular codebase:

```bash
git clone https://github.com/devalade/shipnode.git
cd shipnode
./shipnode help
```

### Why Use the Modular Version?

The modular version (`./shipnode`) sources all modules from `lib/` dynamically:

- **Instant feedback**: Changes to modules take effect immediately
- **Easy debugging**: Test individual modules in isolation
- **Better collaboration**: Work on separate modules without conflicts
- **Clean architecture**: Each module has a single responsibility

### Project Structure

```
shipnode/
├── shipnode              # Main entry point (sources lib/ modules)
├── lib/
│   ├── core.sh          # Core utilities
│   ├── release.sh       # Release management
│   ├── framework.sh     # Framework detection
│   ├── validation.sh    # Input validation
│   ├── prompts.sh       # Interactive prompts
│   └── commands/        # Command implementations
│       ├── init.sh
│       ├── setup.sh
│       ├── deploy.sh
│       └── ...
└── build.sh             # Build bundled version
```

### Development Workflow

**Run the modular version:**
```bash
./shipnode help
./shipnode init
./shipnode deploy
```

**Test individual modules:**
```bash
source lib/core.sh
source lib/validation.sh
validate_port "3000" && echo "Valid"
```

**Build the distributable:**
```bash
./build.sh
# Creates: shipnode-bundled (single file for distribution)
```

---

## Installation Options

## Installation Options

The installer offers several installation locations and PATH setup methods:

### Installation Locations

1. **~/.shipnode** (Default) - No sudo required, recommended for single users
2. **/opt/shipnode** (System-wide) - Requires sudo, for multi-user systems
3. **Custom path** - Specify your own location

### PATH Setup Methods

#### Option 1: Symlink to /usr/local/bin (Recommended)

Creates a system-wide symlink. Requires sudo. `shipnode` will be available globally from any directory.

**Pros:**
- Works in all shells (bash, zsh, fish, etc.)
- No shell config modifications needed
- Clean and standard approach

**Cons:**
- Requires sudo access

#### Option 2: Add to ~/.bashrc

Adds ShipNode to your PATH in bash configuration. After installation, run `source ~/.bashrc` or restart your terminal.

**Pros:**
- No sudo required
- Easy to modify or remove

**Cons:**
- Only works in bash
- Requires sourcing config after install

#### Option 3: Add to ~/.zshrc

Same as option 2, but for zsh users. After installation, run `source ~/.zshrc` or restart your terminal.

#### Option 4: Add to both bash and zsh

If you use both shells or are unsure which one you use.

#### Option 5: Manual Setup

Skip automatic installation and set up manually. The installer will show you the commands to run manually.

## Verification

After installation, verify ShipNode is available:

```bash
shipnode help
```

You should see the ShipNode help menu.

## Troubleshooting

### "command not found: shipnode"

**After symlink installation:**
- Check if /usr/local/bin is in your PATH:
  ```bash
  echo $PATH | grep /usr/local/bin
  ```
- If not, add it to your shell config:
  ```bash
  export PATH="/usr/local/bin:$PATH"
  ```

**After PATH installation:**
- Make sure you sourced your shell config:
  ```bash
  source ~/.bashrc  # or ~/.zshrc
  ```
- Or restart your terminal

### "Permission denied"

Make sure the script is executable:
```bash
chmod +x ~/Code/Labs/shipnode/install.sh
```

### "Already in ~/.bashrc" or "Already in ~/.zshrc"

The installer detected an existing ShipNode entry in your config. This is safe to ignore.

## Building the Installer

If you want to build the self-extracting installer yourself:

```bash
git clone https://github.com/devalade/shipnode.git
cd shipnode
make build
```

This creates `dist/shipnode-installer.sh`.

## Uninstallation

To remove ShipNode:

1. **Remove installation directory:**
   ```bash
   rm -rf ~/.shipnode  # or /opt/shipnode, or your custom path
   ```

2. **Remove symlink (if created):**
   ```bash
   sudo rm /usr/local/bin/shipnode
   ```

3. **Remove from shell config (if added to PATH):**
   Edit `~/.bashrc` or `~/.zshrc` and remove the ShipNode export lines.

Or if installed from source:
```bash
cd /path/to/shipnode
./uninstall.sh
```

## Next Steps

### For Users (Installed via Installer)

1. **Read the documentation**
   ```bash
   cat ~/.shipnode/README.md  # or /opt/shipnode/README.md
   ```

2. **Initialize a project**
   ```bash
   cd /path/to/your/project
   shipnode init
   ```

3. **Deploy**
   ```bash
   shipnode deploy
   ```

### For Developers (Cloned from Source)

1. **Explore the modular structure**
   ```bash
   ls -la lib/
   cat ARCHITECTURE.md
   ```

2. **Run the modular version**
   ```bash
   ./shipnode help
   ./shipnode init
   ```

3. **Make changes and test immediately**
   ```bash
   # Edit lib/commands/deploy.sh
   ./shipnode deploy  # Changes are active immediately
   ```

4. **Build the distributable**
   ```bash
   ./build.sh
   # Creates: shipnode-bundled (for distribution)
   ```

## Updating

### For Users (Installed via Installer)

To update to the latest version, simply download and run the installer again:

```bash
curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
```

### For Developers (Cloned from Source)

Pull the latest changes and continue using the modular version:

```bash
cd shipnode
git pull origin main
./shipnode help
```

---

## Development Workflow

### Quick Start for Contributors

1. **Clone the repository**
   ```bash
   git clone https://github.com/devalade/shipnode.git
   cd shipnode
   ```

2. **Understand the structure**
   ```bash
   cat ARCHITECTURE.md
   ```

3. **Make a change**
   ```bash
   # Edit any file in lib/
   vim lib/commands/deploy.sh
   ```

4. **Test immediately**
   ```bash
   ./shipnode deploy
   # Changes are live without rebuilding!
   ```

5. **Build for distribution (optional)**
   ```bash
   ./build.sh
   # Creates: shipnode-bundled
   ```

### Testing Individual Modules

Test modules in isolation:

```bash
# Test validation module
source lib/core.sh
source lib/validation.sh

validate_port "3000" && echo "Valid port"
validate_port "70000" && echo "Invalid port"

validate_ip_or_hostname "192.168.1.1" && echo "Valid IP"
validate_ip_or_hostname "example.com" && echo "Valid hostname"
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes in `lib/`
4. Test with `./shipnode`
5. Run `./build.sh` to verify bundling works
6. Submit a pull request

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed module documentation.

---

## Support

If you encounter issues:
1. Check the [README.md](README.md)
2. Read [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
3. Report issues: https://github.com/devalade/shipnode/issues
4. Check installation: `which shipnode` and `shipnode help`
