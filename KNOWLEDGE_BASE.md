# OC Infrastructure — Knowledge Base

## 🎯 Purpose
The **OC Infrastructure** repository manages the shared Kubernetes environment, networking, and routing between all services.  
It ensures reliable, secure, and scalable operation of the Provider and Client applications.

---

## 🧩 Key Components

| Component | Description |
|------------|-------------|
| **Kubernetes Cluster (Infomaniak)** | Primary runtime environment. |
| **Namespaces** | `oc-provider`, `oc-client`, `oc-gateway` — isolate resources and secrets. |
| **Nginx Ingress Controller (oc-gateway)** | Handles public traffic, routing, and TLS termination. |
| **Cert-Manager** | Automates Let’s Encrypt certificate management. |
| **Kong Gateway (future)** | Will handle authentication, rate limits, and observability. |
| **Secrets & Configs** | Stores credentials for GHCR, databases, and APIs. |

---

## 🔗 Interactions

| Component | Interacts With | Purpose |
|------------|----------------|----------|
| Ingress | Provider / Client apps | Routes based on hostnames. |
| Cert-Manager | Let’s Encrypt | Issues and renews TLS certificates. |
| Kong (future) | Provider + Client Backends | Unified API gateway and security layer. |

---

## ⚙️ Deployment & CI/CD

- **Namespace:** `oc-gateway`
- **Ingress Controller:**
  ```bash
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm install ingress-nginx ingress-nginx/ingress-nginx -n oc-gateway
  ```
- **TLS Issuer:**
  ```bash
  kubectl apply -f cert-manager.yaml
  kubectl apply -f clusterissuer-letsencrypt-prod.yaml
  ```
- **DNS Configuration:**
  - `provider.on-track.ch` → cluster LoadBalancer IP
  - `client.on-track.ch` → same IP
- **CI/CD:**  
  - Managed manually or through `oc-infra` repository scripts.
  - Future: integrate Terraform or Helmfile.

---

## 🛠 Future Evolutions

- Deploy Kong Gateway for API authentication and rate limiting.
- Add centralized logging (Loki or ELK stack).
- Add monitoring (Prometheus + Grafana).
- Implement Horizontal Pod Autoscaling (HPA).
- Automate infrastructure provisioning with Terraform.
