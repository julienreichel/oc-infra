# OC Infrastructure — Knowledge Base

## 🎯 Purpose

The **OC Infrastructure** project defines, documents, and maintains the complete deployment and operational foundation for the platform.
It provides a unified structure for hosting, deploying, and scaling all components of the system, ensuring that each environment — production, staging, or local — can be **created automatically** from configuration files and CI workflows.

The guiding principle is full reproducibility:

> The entire system, from network to applications, should be deployable anywhere with no manual intervention.

---

## 🧩 Global Architecture Overview

The platform is composed of multiple isolated applications and shared infrastructure layers deployed on Kubernetes.

### Application Layers

| Namespace     | Component             | Description                                                                              |
| ------------- | --------------------- | ---------------------------------------------------------------------------------------- |
| `oc-provider` | **Provider Frontend** | Web interface used by providers to create and send documents.                            |
| `oc-provider` | **Provider Backend**  | API responsible for managing provider data, documents, and client link generation.       |
| `oc-client`   | **Client Frontend**   | Web interface allowing clients to view documents shared by providers.                    |
| `oc-client`   | **Client Backend**    | API responsible for delivering client-facing content and managing document access codes. |

### Shared Infrastructure Layers

| Namespace                  | Component                    | Role                                                                      |
| -------------------------- | ---------------------------- | ------------------------------------------------------------------------- |
| `oc-gateway`               | **Ingress Controller**       | Manages routing between external requests and internal services.          |
| `oc-gateway`               | **Certificate Management**   | Handles TLS certificates and renewals for all domains.                    |
| `oc-gateway`               | **API Gateway (planned)**    | Will unify routing, authentication, and rate-limiting across services.    |
| `oc-provider`, `oc-client` | **PostgreSQL Databases**     | One per backend, ensuring isolation and resilience.                       |
| All                        | **Secrets & Configurations** | Centralized management of credentials, tokens, and environment variables. |

This layered structure guarantees scalability, fault isolation, and independent evolution of each subsystem.

---

## 🌐 Networking and Routing

All network traffic enters the system through a single ingress layer in the `oc-gateway` namespace.
Host-based routing rules direct requests to the correct service depending on the domain and path.

* `provider.on-track.ch` → Provider Frontend
* `provider.on-track.ch/api` → Provider Backend
* `client.on-track.ch` → Client Frontend
* `client.on-track.ch/api` → Client Backend

TLS encryption is automatically managed through certificate automation.
Future integration of an API gateway (Kong) will allow for centralized authentication, rate control, and observability of all HTTP traffic.

---

## 🔐 Security and Certificates

Security is a core aspect of the infrastructure.
All traffic is secured via HTTPS using automatically issued and renewed certificates.
The certificate management system is configured once at the cluster level and automatically serves all ingress resources referencing it.

This ensures:

* Each subdomain receives its own valid certificate.
* Renewals occur transparently.
* No manual certificate management is required.

---

## 🗃️ Databases

Each backend runs its own managed PostgreSQL instance within its namespace.
This guarantees **logical separation** between the provider and client data layers and avoids performance interference or cross-access.

Key design choices:

* One database per backend for fault tolerance and clear data ownership.
* Persistent storage to ensure data durability.
* Credentials stored securely as Kubernetes secrets and injected as environment variables into the backend deployments.

Database creation, configuration, and connection secrets are all defined declaratively and deployed automatically through CI pipelines.

---

## ⚙️ Namespaces

Namespaces are used to isolate environments and resources logically.

| Namespace       | Purpose                                                                 |
| --------------- | ----------------------------------------------------------------------- |
| **oc-provider** | Hosts the provider’s frontend, backend, and database.                   |
| **oc-client**   | Hosts the client’s frontend, backend, and database.                     |
| **oc-gateway**  | Hosts networking components such as ingress and certificate management. |

Each namespace is created from versioned configuration files to ensure reproducibility and consistency across deployments.

---

## 🚀 CI/CD Workflow

Continuous integration and deployment are central to the platform philosophy.
Each application repository includes a dedicated workflow file that performs the following sequence:

1. **Build and Validation** – The code is built and tested to ensure integrity.
2. **Containerization** – A Docker image is generated and tagged for deployment.
3. **Image Publication** – The image is pushed to a shared container registry.
4. **Kubernetes Deployment** – The image tag is automatically injected into the application’s deployment manifest.
5. **Environment Update** – The workflow applies all Kubernetes manifests (deployment, service, ingress, and configuration).

These workflows ensure that every deployment is traceable, reproducible, and isolated per application.
No manual steps are needed to push a change from source code to the live environment.

---

## 🧱 Infrastructure-as-Code

All components of the infrastructure are defined declaratively through YAML manifests and versioned in Git.
This includes namespaces, network routing, storage, databases, secrets, ingress rules, and certificates.

The goal is **total automation**:

* Any new environment can be created simply by applying the manifests via CI.
* No configuration should exist outside of version control.
* The infrastructure definition acts as the single source of truth.

Future enhancements will include:

* Parameterization through Helm charts for modular deployments.
* Terraform integration to automate the provisioning of Kubernetes clusters, DNS entries, and external resources.

---

## 💻 Development Environments

Two environment types are planned to ensure continuous and safe development.

### 1. Server Development Environment

A staging-level setup designed to mirror production in a controlled environment.
It uses the same deployment pipeline but deploys into dedicated namespaces (e.g., `oc-staging-provider`, `oc-staging-client`).

Key principles:

* Same configuration as production, with reduced resource allocation.
* Automated setup via CI, triggered by pushes to the staging branch.
* Staging subdomains (`staging.provider.on-track.ch`, `staging.client.on-track.ch`).
* Enables full integration testing before release.

### 2. Local Development Environment

A lightweight replica of the system for developers to work locally.

Key principles:

* Runs all services using Docker or a local Kubernetes cluster (e.g., Minikube or KinD).
* Environment variables mirror those of the Kubernetes secrets.
* Local scripts prepare the environment, start databases, and expose the same port mappings as in production.
* Full automation is planned via CI scripts to ensure developers can recreate the environment with a single command.

Both environments are designed for **full reproducibility** and **zero manual setup**.

---

## 🔗 System Interactions

| Layer         | Component           | Interacts With             | Description                                         |
| ------------- | ------------------- | -------------------------- | --------------------------------------------------- |
| Network       | Ingress Controller  | All frontends and backends | Routes requests based on hostnames and paths.       |
| Security      | Certificate Manager | Ingress Controller         | Provides and renews TLS certificates automatically. |
| Storage       | PostgreSQL          | Backends                   | Persistent data storage per application.            |
| Automation    | GitHub Actions      | Kubernetes Cluster         | Handles continuous integration and deployment.      |
| Orchestration | Kubernetes          | All components             | Schedules and isolates workloads per namespace.     |

This architecture ensures clear separation of concerns, minimal cross-dependency, and high reliability.

---

## 🛠️ Future Evolutions

| Area                  | Improvement                                         | Objective                                                          |
| --------------------- | --------------------------------------------------- | ------------------------------------------------------------------ |
| **API Gateway**       | Introduce Kong or equivalent                        | Centralized authentication, observability, and request throttling. |
| **Monitoring**        | Add logging and metrics (Grafana, Prometheus, Loki) | Unified observability and alerting.                                |


---

## 🧭 Working Principles

The infrastructure follows five guiding principles:

1. **Declarative** — Everything is defined as code and versioned.
2. **Automated** — CI/CD manages all build and deployment steps.
3. **Isolated** — Each application runs in its namespace with independent data and routing.
4. **Reproducible** — Any environment can be recreated identically from Git.
5. **Portable** — The system can be deployed to any Kubernetes-compatible cloud with minimal adaptation.
