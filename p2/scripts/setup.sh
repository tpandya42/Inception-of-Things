#!/usr/bin/env bash

set -euo pipefail

apt-get update -y && apt-get install -y curl iptables

IP="192.168.56.110"
IFACE=$(ip -4 -o addr show | awk "/${IP}/ {print \$2}")

if [ -z "$IFACE" ]; then
    echo "error: no interface found for IP ${IP}"
    exit 1
fi


curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
	--node-ip=${IP} \
	--advertise-address=${IP} \
	--flannel-iface=${IFACE} \
	--write-kubeconfig-mode=644" sh -

for i in $(seq 1 90); do
    if kubectl get nodes >/dev/null 2>&1; then
        break
    fi
    if [ "$i" -eq 90 ]; then
        echo "error: k3s not ready"
        systemctl status k3s --no-pager || true
        journalctl -u k3s --no-pager -n 50 || true
        exit 1
    fi
    sleep 2
done


kubectl apply -f /vagrant/confs/app1.yml
kubectl apply -f /vagrant/confs/app2.yml
kubectl apply -f /vagrant/confs/app3.yml
kubectl apply -f /vagrant/confs/ingress.yml

kubectl rollout status deployment/app1 --timeout=120s
kubectl rollout status deployment/app2 --timeout=120s
kubectl rollout status deployment/app3 --timeout=120s

kubectl get nodes,pods,svc,ingress -o wide
