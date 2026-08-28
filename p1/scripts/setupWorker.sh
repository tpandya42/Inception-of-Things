#!/usr/bin/env bash

set -e
apt-get update -y && apt-get install -y curl iptables

IP="192.168.56.111"
IFACE=$(ip -4 -o addr show | awk "/${IP}/ {print \$2}")

while [ ! -f /vagrant/confs/node-token ]; do
    sleep 2
done

NODETOKEN=$(cat /vagrant/confs/node-token)

curl -sfL https://get.k3s.io | \
	K3S_URL="https://192.168.56.110:6443" \
	K3S_TOKEN="${NODETOKEN}" \
	INSTALL_K3S_EXEC="agent \
	--node-ip=${IP} \
	--flannel-iface=${IFACE}" sh -
