#!/bin/bash
set -euo pipefail

CLUSTER="tpandya-p3"

echo "Create k3d cluster: ${CLUSTER}"
k3d cluster create "${CLUSTER}" \
    --servers 1 \
    --agents 0 \
    -p "8888:8888@server:0" \
    -p "8080:80@server:0" \
    -p "8443:443@server:0" \
    --wait

echo "-> Create namespaces"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

echo "-> Install ArgoCD"
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "-> Wait for ArgoCD to be ready"
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=Available deployment/argocd-repo-server -n argocd --timeout=300s
kubectl wait --for=condition=Available deployment/argocd-dex-server -n argocd --timeout=300s

echo "-> Apply ArgoCD Application"
# Path to be replaced with VM's actual local path
kubectl apply -f /home/tpandya/Inception-of-Things/p3/confs/argocd-application.yaml

echo "-> Wait for app sync"
TIMEOUT=300
ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
	STATUS=$(kubectl get application playground -n argocd \
		-o jsonpath='{.status.sync.status}
	{.status.health.status}')

		echo "Sync/Health: $STATUS"

		[ "$STATUS" = "Synced Healthy" ] && break

		sleep 5
		ELAPSED=$((ELAPSED + 5))
	done

	[ "$STATUS" = "Synced Healthy" ] || {
		echo "Error: Can't sync"
		exit
	}

echo "-> ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d;
echo

echo "  ArgoCD UI: kubectl port-forward svc/argocd-server 8080:443 -n argocd  -> https://localhost:8080"
