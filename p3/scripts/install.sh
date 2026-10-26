#!/bin/bash
set -euo pipefail

echo "-> Install Dependencies"
apt-get update -y
apt-get install -y curl ca-certificates gnupg lsb-release

echo "-> Install Docker"
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker tpandya || true
systemctl enable docker || true
systemctl start docker || true

echo "-> Install kubectl"
KUBECTL_V=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -L "https://dl.k8s.io/release/${KUBECTL_V}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

echo "-> Install k3d"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "-> Install argocd CLI"
ARGOCD_V="v2.11.7"
ARGOCD_URL="https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_V}/argocd-linux-amd64"

curl -fL --retry 3 \
	-H "Accept: application/octet-stream" \
	"$ARGOCD_URL" \
	-o /tmp/argocd

if ! file /tmp/argocd | grep -qE 'ELF.*executable'; then
	echo "ERROR: ARGO CD DOWNLOAD"
	file /tmp/argocd
	exit 1
fi

install -m 0755 /tmp/argocd /usr/local/bin/argocd

echo "-> Check if All installed"
docker --version
kubectl version --client || true
k3d version
argocd version --client || true

echo "EVERYTHING INSTALLED : )"

