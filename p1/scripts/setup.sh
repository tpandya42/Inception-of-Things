#!/usr/bin/env bash

set -e
apt-get update -y && apt-get install -y curl iptables

IP="192.168.56.110"
IFACE=$(ip -4 -o addr show | awk "/${IP}/ {print \$2}")

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
	--node-ip=${IP} \
	--advertise-address=${IP} \
	--flannel-iface=${IFACE} \
	--write-kubeconfig-mode=644" sh -

while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
	sleep 2
done

mkdir -p /vagrant/confs
cp /var/lib/rancher/k3s/server/node-token /vagrant/confs/node-token
