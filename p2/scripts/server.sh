#!/bin/bash
set -euo pipefail

# SERVER PROVISIONING
# single-node K3s cluster + three apps

apt-get update -y >/dev/null    # curl comes in box: adding for consistency with p1
apt-get install -y curl >/dev/null

IP="192.168.56.110"
IFACE=$(ip -4 -o addr show | awk "/${IP}/ {print \$2; exit}")
if [ -z "$IFACE" ]; then
    echo "Error: no interface found for IP ${IP}"
    exit 1
fi
echo "Using interface: $IFACE"

curl -sfL https://get.k3s.io | sh -s - server \
    --node-ip "$IP" \
    --flannel-iface "$IFACE" \
    --write-kubeconfig-mode 644

until kubectl get nodes >/dev/null 2>&1; do
    sleep 2
done

kubectl apply -f /vagrant/confs
