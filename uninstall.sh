#!/usr/bin/env bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    ShipNode Uninstaller v1.1.2     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_DIR="$HOME/.shipnode"

# Remove symlink
if [ -L "/usr/local/bin/shipnode" ]; then
    echo -e "${BLUE}→${NC} Removing symlink from /usr/local/bin..."
    sudo rm -f /usr/local/bin/shipnode
    echo -e "${GREEN}✓${NC} Symlink removed"
fi

# Portable sed -i that works on both Linux and macOS
portable_sed_inplace() {
    local pattern=$1
    local file=$2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS requires empty string after -i
        sed -i '' "$pattern" "$file"
    else
        # Linux
        sed -i "$pattern" "$file"
    fi
}

# Remove from shell configs
remove_from_config() {
    local config_file=$1
    local config_name=$2

    if [ -f "$config_file" ]; then
        if grep -q "$INSTALL_DIR" "$config_file"; then
            echo -e "${BLUE}→${NC} Removing from $config_name..."
            # Remove the ShipNode comment and export line
            portable_sed_inplace '/# ShipNode/d' "$config_file"
            portable_sed_inplace "\|$INSTALL_DIR|d" "$config_file"
            echo -e "${GREEN}✓${NC} Removed from $config_name"
        fi
    fi
}

remove_from_config ~/.bashrc "~/.bashrc"
remove_from_config ~/.zshrc "~/.zshrc"

echo
echo -e "${GREEN}✓${NC} ShipNode uninstalled"
echo
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓${NC} Removed $INSTALL_DIR"
else
    echo -e "${YELLOW}⚠${NC} $INSTALL_DIR not found"
fi

echo
echo -e "${GREEN}Uninstallation complete!${NC}"
echo "Restart your terminal for changes to take effect."
echo
