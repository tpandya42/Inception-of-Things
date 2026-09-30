#!usr/bin/env/ bash

set -e
apt-get update -y && apt-get install -y curl iptables

IP="192.168.56.110"
IFACE=$(ip -4 -o addr show | awk "/${IP}/ {print \$2}")

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
	--node-ip=${IP} \
	--advertise-address=${IP} \
	--flannel-iface=${IFACE} \
	--write-kubeconfig-mode=644" sh -

until kubectl get nodes > /dev/null 2>&1; do
	sleep 2
done

kubectl apply -f /vagrant/confs
