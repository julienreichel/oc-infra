# Install Steps – OC Infra (Helm + GitHub Actions + Infomaniak)

This guide explains how to bring up and automate your **Kubernetes infrastructure** (Traefik ingress, cert-manager, PostgreSQL, and namespaces) using **GitHub Actions**.
Application deployments are handled by their own repositories.

---

## 0. Prerequisites (on your laptop)

Install:

```bash
brew install git node docker kubectl helm
```

Verify:

```bash
kubectl version --client
helm version
```

---

## 1. Prepare your Infomaniak cluster

1. In **Infomaniak Manager → Public Cloud → Kubernetes**, create a cluster
   → start with 1–2 nodes + LoadBalancer enabled.
2. Download the **kubeconfig** from the Manager and save it, e.g.:

   ```bash
   mkdir -p ~/.kube
   mv ~/Downloads/infomaniak.yaml ~/.kube/infomaniak.yaml
   export KUBECONFIG=~/.kube/infomaniak.yaml
   kubectl get nodes
   ```

   You should see your cluster nodes.
3. In DNS (Infomaniak or your domain host):

   ```
   provider.yourdomain.tld → <LoadBalancer IP>
   client.yourdomain.tld   → <LoadBalancer IP>
   ```

---

## 2. GitHub setup (secrets & repositories)

### Required secrets (in this repo `oc-infra`)

| Name                 | Purpose                                                |
| -------------------- | ------------------------------------------------------ |
| `KUBECONFIG_CONTENT` | Paste the full kubeconfig content from Infomaniak      |
| `CR_PAT`             | Personal Access Token with `write:packages` (for GHCR) |
| `DB_PASSWORD`        | Postgres user password (shared by all namespaces)      |

Application repos (provider/client FE + BE) need only `CR_PAT` and their own `KUBECONFIG_CONTENT`.

---

## 3. How the CI/CD works

The pipeline runs automatically on every push to `main`.
It provisions and reconciles the cluster infra in four stages:

### 1️⃣ `set-matrix`

Defines the list of namespaces once as JSON:

```json
["oc-provider","oc-client","oc-dev-provider","oc-dev-client"]
```

and shares it with downstream jobs.

### 2️⃣ `ensure-ghcr-secrets`

Runs **in parallel** per namespace:

* Ensures namespace exists
* Creates or updates:

  * `ghcr-creds` (secret for GHCR pulls)
  * `db-secret` (Postgres credentials)
  * `db` (secret with `DATABASE_URL`)

Example URL:

```
postgresql://app:<DB_PASSWORD>@pg:5432/db
```

### 3️⃣ `deploy-infra`

Runs once (cluster-wide):

* Installs/upgrades **Traefik** in `oc-gateway`
* Installs/upgrades **cert-manager** in `cert-manager`
* Applies `k8s/namespace.yaml`
* Applies `k8s/clusterissuer-letsencrypt-prod.yaml`

All Helm calls use `--atomic --wait` for safe rollbacks.

### 4️⃣ `deploy-db`

Runs **in parallel** per namespace (using the same matrix):

* Ensures namespace exists
* Installs/upgrades **Postgres** via Bitnami chart:

  ```bash
  helm upgrade --install pg bitnami/postgresql \
    --namespace <ns> \
    --set auth.username=app \
    --set auth.password=$DB_PASSWORD \
    --set auth.database=db \
    --set primary.persistence.enabled=false \
    --wait --atomic
  ```

Result: each namespace has its own Postgres (`Service: pg`) and matching `DATABASE_URL` secret.
Backends use that secret to connect automatically.

---

## 4. Verify infra after first run

```bash
kubectl get ns
kubectl get pods -A
kubectl get svc -A | grep traefik
kubectl get issuer,clusterissuer -A
kubectl -n oc-provider get pods
```

Everything should be Running and Ready.

---

## 5. DNS and Certificates

After the pipeline finishes:

* `kubectl get svc -n oc-gateway` shows a LoadBalancer with an external IP.
* Point your domain records to this IP.
* `cert-manager` and the `ClusterIssuer` will obtain Let’s Encrypt certificates automatically.

---

## 6. Optional: Kong or other API gateway

When Traefik + cert-manager are working, you can add Kong via Helm in `oc-gateway` if needed.
This is not required for basic operation.

---

## 7. Local development (reminder)

`oc-infra/scripts/setup-local.sh` lets you replicate this setup locally with k3d.
It installs Traefik, cert-manager (self-signed issuer), and Postgres via Helm.
Then you can develop frontends/backends locally while the cluster provides infra.

---

## 8. Recap

| Step                        | Who does it   | Tool       |
| --------------------------- | ------------- | ---------- |
| Create cluster & kubeconfig | You           | Infomaniak |
| Configure GitHub Secrets    | You           | GitHub UI  |
| Ingress + TLS + DB deploy   | CI/CD         | Helm       |
| Namespaces + Secrets        | CI/CD         | kubectl    |
| App deploys                 | Each app repo | App CI/CD  |

After the first run, your cluster will have:

* `oc-gateway` → Traefik Ingress Controller
* `cert-manager` → certificate automation
* `oc-provider`, `oc-client`, `oc-dev-*` → Postgres and secrets ready
* DNS + certs → Let’s Encrypt managed

Your backends connect using `DATABASE_URL` from secret `db`.

Push to `main` → GitHub Actions keeps everything in sync ✅
