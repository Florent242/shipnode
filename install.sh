#!/usr/bin/env bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ShipNode Installer v1.1.2      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SHIPNODE_BIN="$SCRIPT_DIR/shipnode"
INSTALL_DIR="$HOME/.shipnode"

# Check if shipnode exists
if [ ! -f "$SHIPNODE_BIN" ]; then
    echo -e "${RED}Error: shipnode binary not found at $SHIPNODE_BIN${NC}"
    exit 1
fi

# Install to ~/.shipnode
echo -e "${BLUE}→${NC} Installing to $INSTALL_DIR..."

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠${NC} Removing existing installation..."
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR"

cp "$SCRIPT_DIR/shipnode" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/shipnode.conf.example" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/LICENSE" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/INSTALL.md" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/templates" "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR/shipnode"
echo -e "${GREEN}✓${NC} Files installed"

# Setup PATH (bashrc always, zshrc if present)
EXPORT_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""
ADDED_TO=""

if [ ! -f ~/.bashrc ]; then
    touch ~/.bashrc
fi

if ! grep -q "$INSTALL_DIR" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# ShipNode" >> ~/.bashrc
    echo "$EXPORT_LINE" >> ~/.bashrc
    ADDED_TO="~/.bashrc"
fi

if [ -f ~/.zshrc ]; then
    if ! grep -q "$INSTALL_DIR" ~/.zshrc 2>/dev/null; then
        echo "" >> ~/.zshrc
        echo "# ShipNode" >> ~/.zshrc
        echo "$EXPORT_LINE" >> ~/.zshrc
        [ -n "$ADDED_TO" ] && ADDED_TO="$ADDED_TO and ~/.zshrc" || ADDED_TO="~/.zshrc"
    fi
fi

if [ -n "$ADDED_TO" ]; then
    echo -e "${GREEN}✓${NC} Added to PATH in $ADDED_TO"
else
    echo -e "${YELLOW}⚠${NC} Already in PATH"
fi

# Verify in current shell
export PATH="$INSTALL_DIR:$PATH"
if command -v shipnode &> /dev/null; then
    echo -e "${GREEN}✓${NC} shipnode is available"
else
    echo -e "${YELLOW}⚠${NC} shipnode not found in PATH yet"
fi

echo
echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Installation Complete! 🎉      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
echo
echo "Quick start:"
echo -e "  ${BLUE}shipnode help${NC}       # View all commands"
echo -e "  ${BLUE}shipnode init${NC}       # Initialize a project"
echo -e "  ${BLUE}shipnode deploy${NC}     # Deploy your app"
echo
echo "Documentation: $INSTALL_DIR/README.md"
echo
