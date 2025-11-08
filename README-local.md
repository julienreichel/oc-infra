# Local Development Environment (k3d)

This document explains how to bring up a **local Kubernetes environment** that mirrors the OC production architecture (provider + client apps, ingress, TLS, and databases).

The goal is:
- 1 command to create the local cluster,
- minimal manual steps,
- then develop frontends/backends with `npm run dev` while the cluster provides infra (DB + ingress + TLS).

---

## 1. Prerequisites

Install the following tools on your machine:

- Docker (Desktop or equivalent)
- `k3d`
- `kubectl`
- `helm`

You also need the 5 repositories in the same workspace:

```text
workspace/
  oc-infra/
  oc-provider-frontend/
  oc-provider-backend/
  oc-client-frontend/
  oc-client-backend/
````

All commands below are run **from `oc-infra/`**.

---

## 2. What the setup does

The script `./scripts/setup-local.sh` will:

1. create a local k3d cluster (`oc-local`) and expose ports **80** and **443**
2. create 3 namespaces: `oc-gateway`, `oc-provider`, `oc-client`
3. install **Nginx Ingress** into `oc-gateway`
4. install **cert-manager**
5. install a **self-signed** ClusterIssuer called `selfsigned-local` (used only for local)
6. deploy **Postgres** in `oc-provider` and in `oc-client`
7. build the 4 application images (provider/client, frontend/backend)
8. import them into the k3d cluster
9. apply the k8s manifests from each app repo
10. print the `/etc/hosts` lines to add

Result: you can open

* `https://provider.localhost`
* `https://client.localhost`

and you should see the apps served through the local ingress.

---

## 3. Run the setup

From `oc-infra/`:

```bash
chmod +x ./scripts/setup-local.sh
./scripts/setup-local.sh
```

At the end, add the following lines to your `/etc/hosts`:

```text
127.0.0.1  provider.localhost
127.0.0.1  client.localhost
```

Then open:

* [https://provider.localhost](https://provider.localhost)
* [https://client.localhost](https://client.localhost)

---

## 4. What runs after setup?

**Important:**

After `./scripts/setup-local.sh` finishes, **all 4 apps are already running inside Kubernetes**:

* Provider frontend (in `oc-provider`)
* Provider backend (in `oc-provider`)
* Client frontend (in `oc-client`)
* Client backend (in `oc-client`)

You do **not** have to start each app manually to see something in the browser.

This is the **“cluster mode”**: everything is deployed as if it were on the real cluster.

---

## 5. Developing locally (override mode)

During development, you often want **live reload** and **faster feedback** than rebuilding/pushing images.

So the workflow is:

1. Let K8s run the infra (ingress, TLS, Postgres, other apps)
2. Stop **just** the K8s app you want to work on
3. Run that app locally with `npm run dev` (frontend) or `npm run start:dev` (backend)

### 5.1. Example: develop provider backend

1. Scale down the K8s backend:

   ```bash
   kubectl scale deployment oc-provider-backend -n oc-provider --replicas=0
   ```

2. Run it locally:

   ```bash
   cd ../oc-provider-backend
   npm install
   npm run start:dev
   ```

3. Keep using: [https://provider.localhost/api](https://provider.localhost/api)
   (your local backend must point to the K8s Postgres; you can port-forward if needed)

4. When done, restore K8s app:

   ```bash
   kubectl scale deployment oc-provider-backend -n oc-provider --replicas=1
   ```

### 5.2. Example: develop provider frontend

1. Scale down the K8s frontend:

   ```bash
   kubectl scale deployment oc-provider-frontend -n oc-provider --replicas=0
   ```

2. Run locally:

   ```bash
   cd ../oc-provider-frontend
   npm install
   npm run dev
   ```

3. Configure the app to call the K8s backend at: `https://provider.localhost/api`

4. Restore K8s version when you’re done:

   ```bash
   kubectl scale deployment oc-provider-frontend -n oc-provider --replicas=1
   ```

You can do the same for the **client** side.

---

## 6. Trusting the local certificate (macOS)

Because we use a **self-signed** local CA (`selfsigned-local` → `local-ca-issuer`), browsers will warn you the first time.

To fix this:

1. **Export the local CA certificate**

   ```bash
   kubectl get secret local-ca-secret -n cert-manager -o jsonpath="{.data['tls\.crt']}" | base64 --decode > local-ca.crt
   ```

2. **Add it to macOS system keychain with proper trust settings**

   ```bash
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain local-ca.crt
   sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain local-ca.crt
   ```

   **Alternative method (sometimes more reliable):**
   ```bash
   # Import the certificate
   sudo security import local-ca.crt -k /Library/Keychains/System.keychain
   
   # Set trust settings explicitly for SSL
   sudo security add-trusted-cert -d -r trustRoot -p ssl -p smime -k /Library/Keychains/System.keychain local-ca.crt
   ```

3. Refresh `https://provider.localhost` → no more warning ✅

Notes:

* Firefox has its own certificate store → import `local-ca.crt` via Preferences.
* On Linux → use your distro’s CA mechanism.
* On Windows → right-click → install → Trusted Root.

---

## 7. Helper scripts

To reduce manual `kubectl scale ...`, we provide small helper scripts in `oc-infra/scripts/`:

* `dev-start-provider-frontend.sh`
* `dev-stop-provider-frontend.sh`
* `dev-start-provider-backend.sh`
* `dev-stop-provider-backend.sh`
* `dev-start-client-frontend.sh`
* `dev-stop-client-frontend.sh`
* `dev-start-client-backend.sh`
* `dev-stop-client-backend.sh`

See below for their content.

---

## 8. Troubleshooting

* **503 from ingress** → usually the pod is not ready. Check:

  ```bash
  kubectl get pods -n oc-provider
  kubectl get pods -n oc-client
  ```
* **404 on /api** → ingress is working but the app is not serving under `/api`. Fix either ingress (rewrite) or Nest (global prefix).
* **cert-manager not ready** → wait 10–15 seconds and re-apply the ingress.
* **I changed code but UI didn’t update** → you’re still using the K8s version → scale it to 0 and run locally.
