#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

pushd $SCRIPT_DIR/../../ > /dev/null

./scripts/install.py -f /home/ubuntu/.kube/config \
--configure=true \
--defaults=true \
--dark-mode=true \
--opensearch=elasticsearch-remote \
--opensearch-url=http://elasticsearch:9200 \
--opensearch-ssl-verify=false \
--opensearch-memory=16g \
--logstash-memory=6g \
--logstash-workers=6 \
--delete-old-pcap=true \
--delete-index-threshold="80%" \
--auto-suricata=true \
--suricata-rule-update=false \
--auto-zeek=true \
--zeek-ics=true \
--zeek-ics-best-guess=true \
--reverse-dns=false \
--auto-oui=true \
--auto-freq=true \
--file-extraction=none \
--netbox=true \
--netbox-enrich=true \
--netbox-autopopulate=true \
--netbox-site-name=infrastructure \
--https=false \
--live-capture-iface=ens192 \
--live-capture-arkime=true \
--live-capture-zeek=true \
--live-capture-suricata=true

./scripts/auth_setup --auth-noninteractive --auth-admin-username=ubuntu --auth-admin-password-htpasswd="$2y$05$0Eh6brjca6d6Om9BIMTz8eUXmOKnb2U44m5iHmLj.y1y6CqUUH9XW" --auth-admin-password-openssl="$1$epSHjq7y$4VIdB5iKOmahDY/hbsNYA/"
./scripts/start -f /home/ubuntu/.kube/config

popd > /dev/null