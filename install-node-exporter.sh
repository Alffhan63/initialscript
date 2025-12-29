#!/usr/bin/env bash
set -e

NODE_EXPORTER_VERSION="latest"
INSTALL_DIR="/opt/node_exporter"
USER="node_exporter"

echo "==> Detecting OS and architecture..."

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_FAMILY=$ID
else
  echo "Cannot detect OS"
  exit 1
fi

echo "OS: $OS_FAMILY"
echo "ARCH: $ARCH"

echo "==> Installing dependencies..."
case "$OS_FAMILY" in
  ubuntu|debian)
    apt-get update -y
    apt-get install -y curl tar
    ;;
  centos|rhel|rocky|almalinux|amzn)
    yum install -y curl tar
    ;;
  *)
    echo "Unsupported OS: $OS_FAMILY"
    exit 1
    ;;
esac

echo "==> Creating user..."
id $USER &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin $USER

cd /tmp

if [ "$NODE_EXPORTER_VERSION" = "latest" ]; then
  NODE_EXPORTER_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest \
    | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
fi

echo "==> Installing Node Exporter v$NODE_EXPORTER_VERSION"

TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${TARBALL}"

curl -LO "$URL"
tar -xzf "$TARBALL"

mkdir -p $INSTALL_DIR
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter $INSTALL_DIR/
chown -R $USER:$USER $INSTALL_DIR

echo "==> Creating systemd service..."

cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=$USER
ExecStart=$INSTALL_DIR/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "==> Starting service..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable node_exporter
systemctl restart node_exporter

echo "==> Node Exporter installed and running 🚀"
systemctl status node_exporter --no-pager
