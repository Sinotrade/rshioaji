#!/bin/sh
# Install shioaji CLI binary
# Usage: curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh
# Pre-release: curl -fsSL ... | CHANNEL=prerelease sh
# Specific version: curl -fsSL ... | VERSION=v1.5.0b2 sh
set -e

REPO="sinotrade/rshioaji"
BINARY_NAME="shioaji"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux)  OS_NAME="Linux" ;;
    Darwin) OS_NAME="macOS" ;;
    *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)   ARCH_NAME="x86_64" ;;
    aarch64|arm64)   ARCH_NAME="aarch64" ;;
    *)               echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get version
# Set CHANNEL=prerelease to install pre-release versions
CHANNEL="${CHANNEL:-stable}"
if [ -z "$VERSION" ]; then
    if [ "$CHANNEL" = "prerelease" ]; then
        VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases" | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    else
        VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    fi
    if [ -z "$VERSION" ]; then
        echo "Failed to determine latest version"
        exit 1
    fi
fi

echo "Installing $BINARY_NAME $VERSION ($OS_NAME $ARCH_NAME)..."

# Download
ARCHIVE="$BINARY_NAME-$VERSION-$OS_NAME-$ARCH_NAME.tar.gz"
URL="https://github.com/$REPO/releases/download/$VERSION/$ARCHIVE"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading $URL..."
curl -fsSL "$URL" -o "$TMP_DIR/$ARCHIVE"

# Extract
tar xzf "$TMP_DIR/$ARCHIVE" -C "$TMP_DIR"

# Install
mkdir -p "$INSTALL_DIR"
mv "$TMP_DIR/$BINARY_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "Installed $BINARY_NAME to $INSTALL_DIR/$BINARY_NAME"

# Check PATH
case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
        echo ""
        echo "Add $INSTALL_DIR to your PATH:"
        echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
        ;;
esac

echo "Run '$BINARY_NAME --help' to get started."
