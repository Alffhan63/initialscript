#!/usr/bin/env bash
set -e

PROM_VERSION="2.49.1"
PROM_USER="prometheus"
INSTALL_DIR="/etc/prometheus"
DATA_DIR="/var/lib/prometheus"
BIN_DIR="/usr/local/bin"


if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "OS      : $OS"
echo "ARCH    : $ARCH"
echo "VERSION : $PROM_VERSION"


if [[ "$OS" =~ (ubuntu|debian) ]]; then
    apt update
    apt install -y curl tar wget
elif [[ "$OS" =~ (centos|rhel|rocky|almalinux) ]]; then
    yum install -y curl tar wget
else
    echo "Unsupported OS: $OS"
    exit 1
fi


if ! id "$PROM_USER" &>/dev/null; then
    useradd --no-create-home --shell /sbin/nologin $PROM_USER
fi


cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz

tar xzf prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz


cp prometheus-${PROM_VERSION}.linux-${ARCH}/prometheus $BIN_DIR/
cp prometheus-${PROM_VERSION}.linux-${ARCH}/promtool $BIN_DIR/


mkdir -p $INSTALL_DIR $DATA_DIR

cp -r prometheus-${PROM_VERSION}.linux-${ARCH}/{consoles,console_libraries} $INSTALL_DIR/
cp prometheus-${PROM_VERSION}.linux-${ARCH}/prometheus.yml $INSTALL_DIR/

chown -R $PROM_USER:$PROM_USER $INSTALL_DIR $DATA_DIR


cat <<EOF >/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=${PROM_USER}
Group=${PROM_USER}
Type=simple
ExecStart=${BIN_DIR}/prometheus \\
  --config.file=${INSTALL_DIR}/prometheus.yml \\
  --storage.tsdb.path=${DATA_DIR} \\
  --web.console.templates=${INSTALL_DIR}/consoles \\
  --web.console.libraries=${INSTALL_DIR}/console_libraries

Restart=always

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reexec
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus


rm -rf /tmp/prometheus-${PROM_VERSION}.linux-${ARCH}*

echo "Prometheus installed & running 🚀"
echo "Access: http://$(hostname -I | awk '{print $1}'):9090"
