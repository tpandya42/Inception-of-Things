#!/bin/bash
set -euo pipefail

# Build the p3-world: k3d cluster, namespaces, ArgoCD and the application that watches the repo

CLUSTER="iot"
CONFS="$(dirname "$0")/../confs"

# 1. Cluster
if k3d cluster list | grep -qw "$CLUSTER"; then
    echo "cluster $CLUSTER: already exists"
    k3d kubeconfig merge "$CLUSTER" --kubeconfig-switch-context
else
    k3d cluster create "$CLUSTER" --api-port 127.0.0.1:6550
fi

# 2. Namespaces
for ns in argocd dev; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# 3. Argo CD
kubectl apply -n argocd --server-side \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
    >/dev/null

# 4. Wait until Argo CD is actually ready 
# 4a) first we get the CRD (Custom Resource Definition)
for i in {1..60}; do
    kubectl get crd applications.argoproj.io >/dev/null 2>&1 && break
    sleep 1
done
kubectl get crd applications.argoproj.io >/dev/null 2>&1 || { echo "Timed out waiting for the Argo CD CRD" >&2; exit 1; }
# 4b) then we make sure it is usable 
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=120s
# 4c) same thing for the server
for i in {1..60}; do
    kubectl get deploy/argocd-server -n argocd >/dev/null 2>&1 && break
    sleep 1
done
kubectl get deploy/argocd-server -n argocd >/dev/null 2>&1 || { echo "Timed out waiting for the argocd-server deployment" >&2; exit 1; }
kubectl wait --for=condition=Available deploy/argocd-server -n argocd --timeout=300s

# 5. The pointer: watch the repo, deploy to dev
kubectl apply -f "$CONFS/application.yaml"

# 6. Print how to open the app (playground) and the Argo CD UI
echo
echo
echo "OK: p3 IS NOW READY TO ROLL!"
echo " Argo CD is watching saimar-iot and syncing into 'dev'."
echo
echo "To reach the app:"
echo "  kubectl port-forward svc/playground -n dev 8888:8888"

echo
echo "Argo CD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  open https://localhost:8080  (user: admin)"
echo "  the browser warns about the self-signed certificate, that is expected"
echo -n "  password: "
for i in {1..120}; do
    kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1 && break
    sleep 1
done
kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1 || { echo "Timed out waiting for argocd-initial-admin-secret" >&2; exit 1; }
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
echo