#!/bin/bash

repstatsd() {
echo "Replacing statsd daemon"
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
	echo "Replacing port DD"
	sed -i '/dogstatsd_port/s/8125/9999/g' /etc/datadog-agent/datadog.yaml
 	date  >> updatedd.log
 	cat /etc/datadog-agent/datadog.yaml >> updatedd.log
}

restart() {
	systemctl daemon-reload 
	systemctl restart datadog-agent statsd_exporter.service 
 	systemctl status datadog-agent statsd_exporter.service  >> updatedd.log
 	echo "Success Restart datadog-agent statsd_exporter.service"
  	echo ""
   	echo ""
    	cat updatedd.log
}

repstatsd
repdogstad
restart
