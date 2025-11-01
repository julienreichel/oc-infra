## 0. Prereqs on your laptop

1. Install:

   * `git`
   * `node` (20+)
   * `docker` (desktop or CLI)
   * `kubectl` brew install kubectl
   * `helm` brew install helm   

---

## 1. Prepare Infomaniak side

You said you have **Infomaniak Public Cloud** → we use their **managed Kubernetes service**. Steps (from their doc) ([infomaniak.com][1]):

1. In Infomaniak Manager → **Public Cloud** → create a **project**.

2. Inside the project → **Kubernetes** → **Create cluster**.

   * pick 1 small node group to start (1–2 nodes)
   * expose LoadBalancer (default)

3. Download the **kubeconfig** for that cluster (Manager gives you a button). ([paulsorensen.io][2])

4. On your laptop, put it at e.g. `~/.kube/infomaniak.yaml` and:

   ```bash
   export KUBECONFIG=~/.kube/infomaniak.yaml
   kubectl get nodes
   ```

   If you see nodes → you’re good.

5. (optional but recommended) Create 3 namespaces:

   ```bash
   kubectl create namespace oc-provider
   kubectl create namespace oc-client
   kubectl create namespace oc-gateway
   ```

6. Install **Nginx Ingress** into the cluster (either from Infomaniak’s template or Helm). Example via Helm:

   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm install ingress-nginx ingress-nginx/ingress-nginx -n oc-gateway
   ```

   That will create a **LoadBalancer** → Infomaniak will give you a public IP. (You can see it with `kubectl get svc -n oc-gateway`.) ([infomaniak.com][3])

7. In Infomaniak DNS (or wherever your domain is), create records:

   * `provider.yourdomain.tld` → that LoadBalancer IP
   * `client.yourdomain.tld` → same IP

This gives us entry points.

> Kong: you can install it after ingress (Helm chart in `oc-gateway`): we can add it later; not mandatory to get the 4 empty apps up.


## 2. Install cert-manager

**What is cert-manager?**
It’s a Kubernetes app that:

* receives a request like “I want a certificate for provider.on-track.ch”
* proves to Let’s Encrypt that the domain is really yours
* stores the certificate in a Kubernetes **Secret**
* renews it automatically

So we must **install** it in the cluster once.

### 2.1. Create a namespace for cert-manager

You do this **once**:

```bash
kubectl create namespace cert-manager
```

This just creates a “box” in your cluster where cert-manager will live.

### 2.2. Install cert-manager with Helm

On your laptop, run:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true
```

**What this does:**

* downloads the official cert-manager chart
* installs it into the namespace `cert-manager`
* `installCRDs=true` means “also install the extra types that cert-manager needs”

### 2.3. Check it’s running

```bash
kubectl get pods -n cert-manager
```

You should see something like:

```text
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-xxxxx                         1/1     Running   0          30s
cert-manager-cainjector-xxxxx              1/1     Running   0          30s
cert-manager-webhook-xxxxx                 1/1     Running   0          30s
```

If those 3 are **Running**, step 1 is done ✅

---

## 3. Tell cert-manager to use Let’s Encrypt

Right now cert-manager is like “I’m ready, but... where do I get certs from?”
We must create an object called a **ClusterIssuer**.

Think: **ClusterIssuer = recipe for getting certificates.**

### 3.2. Apply it to the cluster

From **`clusterissuer-letsencrypt-prod.yaml`**

```bash
kubectl apply -f clusterissuer-letsencrypt-prod.yaml
```

Check:

```bash
kubectl get clusterissuer
```

You should see:

```text
NAME              READY   AGE
letsencrypt-prod  True    5s
```

If it says `True` → perfect.
If it says `False` → do `kubectl describe clusterissuer letsencrypt-prod` to see why.

Now cert-manager knows “if anyone asks for a cert and says they use `letsencrypt-prod`, I know how to do it.”

---

### 3.3. Apply the ingress (optional)

Now apply this file:

```bash
kubectl apply -f oc-provider-frontend/k8s/ingress.yaml
```

(If you keep your k8s files in GitHub and deploy from CI, then just commit & push; but for now, we can do it by hand.)


### 3.4. Test in the browser

Now open:

* `https://provider.on-track.ch`
* `https://client.on-track.ch`

If all is good → green lock 🔒

If it’s not yet green → try `http://...` first to see if the challenge is still running.

---

## 4. Create a container registry (where to push images)

You need any Docker registry reachable from Infomaniak. Options:

* GitHub Container Registry (GHCR) → easiest
* Docker Hub
* Infomaniak’s own (if enabled)

Let’s pick **GHCR**.

1. In GitHub → Settings → Developer settings → **Personal access tokens (classic or fine-grained)** → create one with `write:packages`.
2. In **each repo**, add Secrets:

   * `CR_PAT` → your token
   * `REGISTRY` → `ghcr.io`
   * `IMAGE_NAME` → `ghcr.io/<your-gh-username>/<repo-name>`
   * `KUBECONFIG_CONTENT` (paste the kubeconfig you downloaded from Infomaniak — base64 is nicer but inline works)


### 4.1. Create a secret in `oc-provider`

Use **the same token** you used in GitHub (`CR_PAT` with `read:packages`).

On your laptop:

```bash
kubectl create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password='<your-personal-access-token>' \
  --docker-email=none@none \
  -n oc-provider
```

⚠️ Replace:

* `<your-github-username>`
* `<your-personal-access-token>`

Now the cluster has a secret called `ghcr-creds` in the **right namespace** (`oc-provider`).

---

## 9. Database on Infomaniak

Right now, you only need **empty backends** so we can just:

1. In Infomaniak → create **Managed PostgreSQL** (one called `oc-provider-pg`, another `oc-client-pg`).
2. Copy connection strings.
3. In k8s, create secrets:

```bash
kubectl create secret generic oc-provider-db \
  --from-literal=DATABASE_URL=postgres://user:pass@host:5432/dbname \
  -n oc-provider
```

4. In your **backend Deployment**, mount the env:

```yaml
envFrom:
  - secretRef:
      name: oc-provider-db
```

For now NestJS won’t use it (empty app), but it’s wired.

---

## 10. (Optional now / later) Install Kong

Once you have ingress working, install Kong via Helm in `oc-gateway` and start declaring services/routes for the 2 backends. This is straight from their doc, the cluster is ready for it. (We don’t need it to have “empty apps deployed”.)

---

## Recap – your step-by-step

1. ✅ Create 4 GitHub repos (provider/client FE+BE)
2. ✅ Bootstrap Vue+Quasar in FE repos
3. ✅ Bootstrap NestJS in BE repos
4. ✅ Add Dockerfiles to all 4
5. ✅ In Infomaniak: create k8s cluster, download kubeconfig, create 3 namespaces, install Nginx ingress ([infomaniak.com][1])
6. ✅ Create DNS entries pointing to the ingress LB
7. ✅ In each repo: add `.github/workflows/cicd.yml` (build → docker → deploy)
8. ✅ In each repo: add `k8s/` with deployment + service (+ ingress for the FEs)
9. ✅ Add GitHub secrets: `CR_PAT`, `IMAGE_NAME`, `KUBECONFIG_CONTENT`
10. ✅ Push to `main` → GitHub builds images → pushes to GHCR → applies manifests → 4 empty apps are running on Infomaniak

At this point you can open:

* `https://provider.yourdomain.tld` → empty Quasar app
* `https://provider.yourdomain.tld/api` → NestJS “Hello World”
* `https://client.yourdomain.tld` → empty Quasar app
* `https://client.yourdomain.tld/api` → NestJS “Hello World”

Then you start coding.

If you tell me your actual domain (or if you want to use `*.ik-server.ch` style hostnames that Infomaniak gives you), I can rewrite the 2 ingress files exactly.

[1]: https://www.infomaniak.com/en/support/faq/2819/install-kubernetes-on-public-cloud?utm_source=chatgpt.com "Install Kubernetes on Public Cloud"
[2]: https://paulsorensen.io/kubernetes-infomaniak-cloud-guide/?utm_source=chatgpt.com "How to Set Up Kubernetes on Infomaniak Cloud"
[3]: https://www.infomaniak.com/en/hosting/public-cloud/kubernetes?utm_source=chatgpt.com "Kubernetes service"
[4]: https://nth-root.nl/en/guides/automate-kubernetes-deployments-with-github-actions?utm_source=chatgpt.com "Automate Kubernetes deployments with GitHub Actions"

