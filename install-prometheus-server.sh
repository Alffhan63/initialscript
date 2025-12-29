#!/usr/bin/env bash
set -e

PROM_VERSION="2.49.1"
PROM_USER="prometheus"
INSTALL_DIR="/etc/prometheus"
DATA_DIR="/var/lib/prometheus"
BIN_DIR="/usr/local/bin"

### OS
. /etc/os-release
OS=$ID

ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  *) echo "Unsupported arch"; exit 1 ;;
esac

echo "OS      : $OS"
echo "ARCH    : $ARCH"
echo "VERSION : $PROM_VERSION"

### Deps
apt update
apt install -y curl wget tar

### User
id prometheus &>/dev/null || useradd --no-create-home --shell /sbin/nologin prometheus

### Download
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz
tar xzf prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz

systemctl stop prometheus 2>/dev/null || true

install -m 0755 prometheus-${PROM_VERSION}.linux-${ARCH}/prometheus ${BIN_DIR}/prometheus
install -m 0755 prometheus-${PROM_VERSION}.linux-${ARCH}/promtool ${BIN_DIR}/promtool

mkdir -p ${INSTALL_DIR} ${DATA_DIR}
cp -r prometheus-${PROM_VERSION}.linux-${ARCH}/{consoles,console_libraries} ${INSTALL_DIR}
chown -R prometheus:prometheus ${INSTALL_DIR} ${DATA_DIR}

# =========================
# GCP DISCOVERY
# =========================

echo "== GCP metadata =="

META="http://metadata.google.internal/computeMetadata/v1"
HDR="Metadata-Flavor: Google"

PROJECT_ID=$(curl -sf -H "$HDR" $META/project/project-id)
ZONE_SELF=$(curl -sf -H "$HDR" $META/instance/zone | awk -F/ '{print $NF}')
REGION="${ZONE_SELF%-*}"

echo "Project : $PROJECT_ID"
echo "Zone    : $ZONE_SELF"
echo "Region  : $REGION"

# Try Compute API
ZONES=""
TOKEN=$(curl -sf -H "$HDR" $META/instance/service-accounts/default/token \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p') || true

if [[ -n "$TOKEN" ]]; then
  ZONES=$(curl -sf -H "Authorization: Bearer $TOKEN" \
    "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones" \
    | sed -n 's/.*"name": "\([^"]*\)".*/\1/p' \
    | grep "^${REGION}-" || true)
fi

# Fallback
if [[ -z "$ZONES" ]]; then
  echo "⚠️ Compute API not accessible, fallback to local zone"
  ZONES="$ZONE_SELF"
fi

echo "Zones:"
echo "$ZONES"

# =========================
# GENERATE CONFIG
# =========================

echo "== Generate prometheus.yml =="

mkdir -p ${INSTALL_DIR}

{
cat <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "gcp-node"
    gce_sd_configs:
EOF

for z in $ZONES; do
cat <<EOF
      - project: "$PROJECT_ID"
        zone: "$z"
        port: 9100
EOF
done

cat <<'EOF'

    relabel_configs:
      - source_labels: [__meta_gce_label_monitoring]
        regex: true
        action: keep

      - source_labels: [__meta_gce_private_ip]
        target_label: __address__
        replacement: "$1:9100"

      - source_labels: [__meta_gce_instance_name]
        target_label: instance

      - source_labels: [__meta_gce_zone]
        target_label: zone
EOF
} > ${INSTALL_DIR}/prometheus.yml

chown prometheus:prometheus ${INSTALL_DIR}/prometheus.yml

# =========================
# SYSTEMD
# =========================

cat <<EOF >/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network-online.target

[Service]
User=prometheus
ExecStart=${BIN_DIR}/prometheus \
  --config.file=${INSTALL_DIR}/prometheus.yml \
  --storage.tsdb.path=${DATA_DIR}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl restart prometheus

echo "✅ Prometheus running"
echo "👉 http://$(hostname -I | awk '{print $1}'):9090"
