#!/bin/bash

repstatsd() {
	cat <<EOF >/etc/systemd/system/statsd_exporter.service
[Unit]
Description=Statsd Exporter

[Service]
User=root
Restart=always
ExecStart=/usr/local/bin/statsd_exporter-0.28.0.linux-amd64/statsd_exporter --statsd.listen-udp=":8125" --statsd.relay.address=localhost:9999

[Install]
WantedBy=multi-user.target

EOF
}

repdogstad() {
	sed -i '/dogstatsd_port/s/8125/9999/g' /etc/datadog-agent/datadog.yaml
}

restart() {
	systemctl daemon-reload
	systemctl restart datadog-agent
	systemctl restart statsd_exporter.service
}

repstatsd
repdogstad
restart
