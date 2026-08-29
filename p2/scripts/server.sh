#!/bin/bash
set -eu

# SERVER PROVISIONING
# single-node K3s cluster + three apps

IFACE=$(ip -4 -o addr show | awk '/192\.168\.56\.110/ {print $2}')
if [ -z "$IFACE" ]; then
    echo "Error: no interface found for IP 192.168.56.110"
    exit 1
fi
echo "Using interface: $IFACE"

curl -sfL https://get.k3s.io | sh -s - server \
    --node-ip 192.168.56.110 \
    --flannel-iface "$IFACE" \
    --write-kubeconfig-mode 644

until kubectl get nodes >/dev/null 2>&1; do
    sleep 2
done

kubectl apply -f /vagrant/confs
