#!/bin/bash

# Generate development certificates for goServeR package using mkcert
# This script generates locally-trusted development certificates

set -e  # Exit on any error

CERT_DIR="inst/extdata"
PACKAGE_NAME="goServeR"

echo "🔐 Generating development certificates for $PACKAGE_NAME..."

# Check if mkcert is installed
if ! command -v mkcert &> /dev/null; then
    echo "❌ mkcert is not installed. Please install it first:"
    echo ""
    echo "On macOS:"
    echo "  brew install mkcert"
    echo ""
    echo "On Linux (Ubuntu/Debian):"
    echo "  curl -JLO 'https://dl.filippo.io/mkcert/latest?for=linux/amd64'"
    echo "  chmod +x mkcert-v*-linux-amd64"
    echo "  sudo cp mkcert-v*-linux-amd64 /usr/local/bin/mkcert"
    echo ""
    echo "On other systems, see: https://github.com/FiloSottile/mkcert#installation"
    exit 1
fi

# Check if local CA is installed
if ! mkcert -check &> /dev/null; then
    echo "📋 Installing local CA in system trust store..."
    mkcert -install
    echo "✅ Local CA installed"
else
    echo "✅ Local CA already installed"
fi

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Backup existing certificates if they exist
if [[ -f "$CERT_DIR/cert.pem" ]] || [[ -f "$CERT_DIR/key.pem" ]]; then
    BACKUP_DIR="$CERT_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    echo "📁 Backing up existing certificates to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    [[ -f "$CERT_DIR/cert.pem" ]] && cp "$CERT_DIR/cert.pem" "$BACKUP_DIR/"
    [[ -f "$CERT_DIR/key.pem" ]] && cp "$CERT_DIR/key.pem" "$BACKUP_DIR/"
fi

# Generate new certificates
echo "🔑 Generating new certificates..."
cd "$CERT_DIR"

# Generate certificate for common development hostnames
mkcert -cert-file cert.pem -key-file key.pem \
    localhost \
    127.0.0.1 \
    ::1 \
    0.0.0.0 \
    "$(hostname)" \
    "$(hostname).local"

echo "✅ Certificates generated successfully!"
echo ""
echo "📁 Certificate files:"
echo "  Certificate: $CERT_DIR/cert.pem"
echo "  Private Key: $CERT_DIR/key.pem"
echo ""
echo "🌐 Valid for hosts:"
echo "  - localhost"
echo "  - 127.0.0.1"
echo "  - ::1 (IPv6 localhost)"
echo "  - 0.0.0.0"
echo "  - $(hostname)"
echo "  - $(hostname).local"
echo ""
echo "⚠️  Note: These certificates are for development only."
echo "   For production, use certificates from a proper CA like Let's Encrypt."
echo ""
echo "🔧 You can now use these certificates with goServeR:"
echo "   certfile <- system.file('extdata', 'cert.pem', package = 'goServeR')"
echo "   keyfile <- system.file('extdata', 'key.pem', package = 'goServeR')"
echo "   runServer(tls = TRUE, certfile = certfile, keyfile = keyfile, ...)"
