# Copilot Instructions for oc-infra

## Project Overview
The **OC Infrastructure** repository manages the shared Kubernetes environment, networking, and routing for the "oc" project. This infrastructure ensures reliable, secure, and scalable operation of Provider and Client applications deployed on Infomaniak Public Cloud.

## Architecture & Components
- **Target Platform**: Kubernetes Service (managed K8s cluster)
- **Service Architecture**: 3-namespace isolation (`oc-provider`, `oc-client`, `oc-gateway`)
- **Ingress**: Traefik Controller in `oc-gateway` namespace for traffic routing and TLS termination
- **Certificate Management**: Cert-manager with Let's Encrypt for automated SSL provisioning
- **Container Registry**: GitHub Container Registry (GHCR) for image storage
- **Databases**: PostgreSQL 
- **Future Components**: Kong Gateway for API authentication, rate limiting, and observability

## Key Infrastructure Patterns

### Namespace Organization & Resource Isolation
The project uses a strict 3-namespace approach for resource and secret isolation:
- `oc-provider`: Provider backend and frontend services
- `oc-client`: Client backend and frontend services  
- `oc-gateway`: Shared infrastructure (Nginx Ingress Controller, future Kong Gateway)

### Traffic Routing & SSL Management
- **Traefik Ingress Controller**: Deployed in `oc-gateway` namespace, handles public traffic routing based on hostnames
- **DNS Configuration**: `provider.on-track.ch` and `client.on-track.ch` both point to cluster LoadBalancer IP
- **Cert-Manager**: Automates Let's Encrypt certificate issuance and renewal
- **ClusterIssuer**: `clusterissuer-letsencrypt-prod.yaml` defines production ACME endpoint with HTTP-01 challenge

### Container Registry Authentication
Docker registry secrets are created per namespace using GitHub Personal Access Tokens:
```bash
kubectl create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io \
  --docker-username=julienreichel \
  --docker-password='[PAT]' \
  -n [namespace]
```

## Developer Workflow

### Prerequisites (from INSTALL_STEP.md)
Required tools: `git`, `node` (20+), `docker`, `kubectl`, `helm`

### File Conventions
- `clusterissuer-*.yaml`: Cluster-wide certificate issuers for Let's Encrypt integration
- `INSTALL_STEP.md`: Complete infrastructure setup guide with external dependencies
- `KNOWLEDGE_BASE.md`: Architecture overview and component interactions

## External Integrations
- **Infomaniak Public Cloud**: Primary hosting platform for managed Kubernetes
- **Let's Encrypt**: Automated certificate provisioning via ACME protocol
- **GitHub Container Registry**: Container image storage and distribution
- **Domain Management**: DNS configuration required for ingress routing

## Security Considerations
- Each namespace requires separate docker registry secrets
- TLS termination handled at ingress level with automatic certificate renewal
- Database connections use Kubernetes secrets for credential management

## Future Infrastructure Evolution
- **Kong Gateway**: Will be deployed for API authentication, rate limiting, and observability
- **Monitoring Stack**: Planned integration of Prometheus + Grafana for metrics
- **Logging**: Centralized logging with Loki or ELK stack
- **Autoscaling**: Horizontal Pod Autoscaling (HPA) implementation
- **Infrastructure as Code**: Terraform automation for cluster provisioning

## Commit & Release Conventions

### Commit Messages

```
type(scope): Description

Examples:
feat(document): Add access code validation
fix(layout): Prevent header overlap on mobile
refactor(providers): Extract HTTP error handling
```

### Release Process

```bash
git checkout main && git pull
git merge dev
npm version <patch|minor|major>
git push && git push --tags
# Create RELEASE-NOTES.md with high-level changes
```


## Related Repositories
This infra repo supports deployment of 4 application repositories:
- Provider frontend (Vue.js + Quasar)
- Provider backend (NestJS)
- Client frontend (Vue.js + Quasar)  
- Client backend (NestJS)

When modifying infrastructure, coordinate changes with application deployments that reference these namespace and service configurations.