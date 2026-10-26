# Inception-of-Things — Complete Testing Documentation

**Student:** `tpandya`  
**Parts:** P1 (K3s multi-node Vagrant), P2 (K3s single-node + 3 apps + Ingress), P3 (K3d + ArgoCD GitOps)

---

## 0. Prerequisites

| Tool | Verify command |
|------|----------------|
| VirtualBox | `VBoxManage --version` |
| Vagrant | `vagrant --version` |
| Docker | `docker --version` |
| kubectl | `kubectl version --client` |
| k3d | `k3d version` |

Host OS: macOS (Apple Silicon ARM64). VirtualBox `virtio` NIC customization is required in Vagrantfiles for reliable private networking.

---

# PART 1: K3s Multi-Node Cluster (Vagrant)

**Goal:** 2 VMs (`tpandyaS` server @ `192.168.56.110`, `tpandyaSW` agent @ `192.168.56.111`), K3s server + agent, `kubectl` works.

## Directory layout

```
p1/
├── Vagrantfile
├── scripts/
│   ├── setup.sh        # server: install K3s, copy node-token to /vagrant/confs
│   └── setupWorker.sh  # agent: wait for token, join cluster
└── confs/
    └── node-token      # gitignored; copied from server at runtime
```

## Step 1: Boot the cluster

From repo root:

```bash
cd p1
vagrant destroy -f          # clean slate (optional, recommended for first run)
vagrant up tpandyaS         # boot server FIRST
vagrant up tpandyaSW        # boot agent SECOND
```

**Boot order matters:** `setupWorker.sh` waits for `/vagrant/confs/node-token`, which is only created after `tpandyaS` finishes provisioning.

## Step 2: Verify from host

```bash
vagrant status
vagrant ssh tpandyaS -c "hostname && ip a | grep 192.168.56.110"
vagrant ssh tpandyaSW -c "hostname && ip a | grep 192.168.56.111"
```

## Step 3: Verify Kubernetes inside server VM

```bash
vagrant ssh tpandyaS -c "kubectl get nodes -o wide"
vagrant ssh tpandyaS -c "kubectl get pods -A"
```

**Expected:** `tpandyaS` (Ready, control-plane) and `tpandyaSW` (Ready, agent).

## Step 4: Passwordless SSH

```bash
vagrant ssh tpandyaS
vagrant ssh tpandyaSW
```

No password prompt — Vagrant insecure key is used by default.

---

# PART 2: K3s Single-Node + 3 Apps + Host-Based Ingress

**Goal:** 1 VM (`tpandyaS` @ `192.168.56.110`), K3s server, 3 apps (`app1` = 1 replica, `app2` = 3 replicas, `app3` = 1 replica), single Traefik Ingress routing by `Host` header.

## Directory layout

```
p2/
├── Vagrantfile
├── scripts/
│   └── server.sh
└── confs/
    ├── app1.yaml
    ├── app2.yaml
    ├── app3.yaml
    └── ingress.yaml
```

## Step 1: Boot and deploy

```bash
cd p2
vagrant destroy -f
vagrant up
```

`scripts/server.sh` installs K3s, waits for `kubectl`, applies all 4 manifests, waits for rollouts, prints `kubectl get nodes,pods,svc,ingress -o wide`.

## Step 2: The evaluator test (run from your HOST)

```bash
# app1.com -> app1
curl -s -H "Host:app1.com" http://192.168.56.110 | grep Name

# app2.com -> app2 (3 replicas)
curl -s -H "Host:app2.com" http://192.168.56.110 | grep Name

# default (no host header) -> app3
curl -s http://192.168.56.110 | grep Name
```

**Expected output:** `app1`, `app2`, and `app3` respectively (from `WHOAMI_NAME` env var).

## Step 3: Verify Kubernetes objects

```bash
vagrant ssh tpandyaS -c "kubectl get deployments,pods,svc,ingress -o wide -A"
```

**Expected:**
- `deployments.apps`: app1 (1/1), app2 (3/3), app3 (1/1)
- `services`: app1, app2, app3 (all ClusterIP, port 80)
- `ingresses.apps`: apps-ingress with rules `app1.com`, `app2.com`, catch-all

---

# PART 3: K3d + ArgoCD GitOps

**Goal:** Install Docker + kubectl + k3d + argocd CLI from scratch, create K3d cluster, install ArgoCD, sync app from public GitHub repo, demonstrate v1 → v2 switch.

## Directory layout

```
p3/
├── scripts/
│   ├── install.sh   # docker, kubectl, k3d, argocd CLI
│   └── setup.sh     # k3d cluster, namespaces, ArgoCD install, Application
└── confs/
    ├── argocd-application.yaml
    ├── deployment.yaml   # wil42/playground:v1
    └── service.yaml
```

## Step 1: Install everything (run once, from scratch)

```bash
cd p3
chmod +x scripts/install.sh scripts/setup.sh
./scripts/install.sh
```

**Verifies:** `docker --version`, `kubectl version --client`, `k3d version`, `argocd version --client`.

> **Note:** After install, log out and back in (or run `newgrp docker`) so Docker group membership takes effect.

## Step 2: Create cluster + install ArgoCD + deploy app

```bash
./scripts/setup.sh
```

**What this does:**
1. `k3d cluster create tpandya-p3` with port mappings `8888:8888`, `8080:80`, `8443:443`
2. Creates namespaces `argocd` and `dev`
3. Installs ArgoCD from official stable manifests
4. Waits for `argocd-server`, `argocd-repo-server`, `argocd-dex` deployments to be Available
5. Applies `argocd-application.yaml` (points ArgoCD at your public GitHub repo)
6. Polls until ArgoCD Application is `Synced Healthy`
7. Prints the initial admin password

## Step 3: Verify namespaces and pods

```bash
kubectl get ns
kubectl get pods -n argocd
kubectl get pods -n dev
```

**Expected:** `argocd` and `dev` namespaces Active; ArgoCD pods Running; `playground` pod Running in `dev`.

## Step 4: Access the application (v1)

```bash
kubectl port-forward svc/playground 8888:80 -n dev
```

In another terminal:

```bash
curl -s http://localhost:8888
```

**Expected:** JSON response containing `v1` (from `wil42/playground:v1`).

## Step 5: ArgoCD UI (optional, good for defense)

```bash
kubectl port-forward svc/argocd-server 8080:443 -n argocd
```

Open `https://localhost:8080` in a browser.
- **Username:** `admin`
- **Password:** printed by `setup.sh`, or retrieve with:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Step 6: GitOps demo — switch v1 → v2

On your host (where the GitHub repo is cloned):

1. Edit `p3/confs/deployment.yaml`:
   ```yaml
   image: wil42/playground:v2
   ```

2. Commit and push:
   ```bash
   git add p3/confs/deployment.yaml
   git commit -m "feat(p3): switch app to v2"
   git push origin main
   ```

3. ArgoCD detects the change automatically (`syncPolicy.automated`) and redeploys.

4. Verify sync:
   ```bash
   kubectl get application playground -n argocd
   # STATUS: Synced / Healthy
   ```

5. Verify app is now v2:
   ```bash
   curl -s http://localhost:8888
   ```

**Expected:** JSON response containing `v2`.

## Step 7: Cleanup

```bash
k3d cluster delete tpandya-p3
---

# FULL DEFENSE RUNBOOK (all parts, sequential)

```bash
# ============ PART 1 ============
cd p1
vagrant up tpandyaS
vagrant up tpandyaSW
vagrant ssh tpandyaS -c "kubectl get nodes -o wide"

# ============ PART 2 ============
cd p2
vagrant up
# From host:
curl -s -H "Host:app1.com" http://192.168.56.110 | grep Name
curl -s -H "Host:app2.com" http://192.168.56.110 | grep Name
curl -s http://192.168.56.110 | grep Name

# ============ PART 3 ============
cd p3
./scripts/install.sh
./scripts/setup.sh
kubectl port-forward svc/playground 8888:80 -n dev &
# From another terminal:
curl -s http://localhost:8888   # v1
# Edit deployment.yaml to v2, git push
curl -s http://localhost:8888   # v2
```

---

# TROUBLESHOOTING

| Problem | Likely cause | Fix |
|---------|-------------|-----|
| P2: `curl` returns nothing | Traefik Ingress not ready | `kubectl get ingress -w` wait for IP |
| P2: `app2` not 3 replicas | `replicas: 3` missing/wrong | Check `p2/confs/app2.yaml` |
| P3: `setup.sh` hangs 300s | `argocd-dex-server` doesn't exist | Should be `argocd-dex` |
| P3: ArgoCD can't clone repo | Repo is private | Make GitHub repo public |
| P3: `kubectl port-forward` connection refused | Service not ready | `kubectl get pods -n dev` wait for Running |
| P3: `amd64` kubectl on ARM64 | Wrong architecture | Use `dpkg --print-architecture` |

---

# KEY FILES SUMMARY

| Part | File | Purpose |
|------|------|---------|
| P1 | `p1/Vagrantfile` | 2 VMs: `tpandyaS` + `tpandyaSW` |
| P1 | `p1/scripts/setup.sh` | K3s server install + node-token copy |
| P1 | `p1/scripts/setupWorker.sh` | K3s agent join |
| P2 | `p2/Vagrantfile` | 1 VM: `tpandyaS` @ `192.168.56.110` |
| P2 | `p2/scripts/server.sh` | K3s install + apply manifests |
| P2 | `p2/confs/app{1,2,3}.yaml` | Deployments + Services |
| P2 | `p2/confs/ingress.yaml` | Host-based Traefik Ingress |
| P3 | `p3/scripts/install.sh` | Docker + kubectl + k3d + argocd CLI |
| P3 | `p3/scripts/setup.sh` | Cluster + ArgoCD + Application |
| P3 | `p3/confs/deployment.yaml` | App deployment (`wil42/playground:v1`) |
| P3 | `p3/confs/service.yaml` | ClusterIP Service port 80 → 8888 |
| P3 | `p3/confs/argocd-application.yaml` | ArgoCD Application pointing at GitHub repo |
