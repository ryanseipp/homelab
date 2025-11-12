# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Overview

This is a declarative homelab configuration combining NixOS host management with
Kubernetes cluster management. The repository uses Talos Linux for Kubernetes
cluster provisioning and ArgoCD for GitOps-based application deployment.

## Architecture

### Two-Layer Infrastructure

1. **NixOS Host Layer** (deprecated/transitioning):
   - `flake.nix`: Defines NixOS system configurations using flake-parts
   - Previously configured bare-metal Kubernetes with Cilium CNI
   - Deploy mechanism: `deploy-rs` for remote NixOS deployments
   - Host configuration references in flake.nix point to now-deleted
     `nix/hosts/kube-host-1`

2. **Kubernetes Cluster Layer** (current):
   - **Talos Linux**: Kubernetes cluster OS (configs in `clusters/home/talos/`)
   - **GitOps**: ArgoCD ApplicationSets manage all cluster applications
   - **Manifest Management**: Helm charts templated to static YAML, managed via
     Kustomize

### Cluster Configuration Pattern

Each service in `clusters/home/` follows this structure:

- `helmfile.yaml`: Helm chart definitions with values
- `helm/`: Generated static manifests from Helm charts (DO NOT edit directly)
- `kustomization.yaml`: References generated Helm manifests and custom resources
- Additional YAML files: Custom resources (namespaces, projects, routes, etc.)

Key services deployed:

- **argocd**: GitOps controller with ApplicationSets for infra and apps
- **cilium**: CNI with L2 LoadBalancer and Gateway API
- **cert-manager**: TLS certificate management
- **rook-ceph**: Persistent storage
- **strimzi**: Kafka operator
- **tailscale**: VPN/mesh networking
- **mimir**, **tempo**: Observability (metrics, traces)
- **opentelemetry**: Telemetry collection

### ArgoCD GitOps Structure

ArgoCD uses ApplicationSets to automatically discover and deploy applications:

- `infra-appset.yaml`: Points to infrastructure applications in external repo
- `apps-appset.yaml`: Points to user applications in external repo
- External repo: `https://github.com/ryanseipp/gitops-app-platform.git`

## Development Workflow

### Environment Setup

Enter the development shell (provides all necessary tools):

```bash
nix develop
```

This provides: argocd, cilium-cli, helmfile, k9s, kubectl, kustomize, talosctl,
and more.

### Helm Chart Updates

When modifying Helm charts or values in any `helmfile.yaml`:

```bash
# Re-template all Helm charts to static manifests
./scripts/template-helm.sh
```

This script:

1. Finds all `helmfile.yaml` files
2. Removes old `helm/` directories
3. Runs `helmfile template` to generate new manifests
4. Updates `kustomization.yaml` to reference new manifests
5. Formats output with `nix fmt`

**IMPORTANT**: Never manually edit files in `helm/` directories - they are
generated artifacts.

### Code Formatting

```bash
nix fmt
```

Uses treefmt with:

- `nixfmt` for Nix files
- `prettier` for YAML/JSON/Markdown (with `proseWrap: always`)

Excludes: `.envrc`, `LICENSE`, `*.pub` files

### Kubernetes Cluster Access

With Talos cluster:

```bash
# Using talosctl (config in clusters/home/talos/talosconfig)
talosctl --talosconfig clusters/home/talos/talosconfig <command>

# Using kubectl (kubeconfig obtained via talosctl)
kubectl <command>

# Interactive cluster management
k9s
```

### NixOS Deployments (Legacy)

The flake defines a deploy-rs configuration for the `kube-host-1` node:

```bash
# Deploy NixOS configuration changes
nix run github:serokell/deploy-rs -- .#kube-host-1
```

Note: The NixOS modules referenced in flake.nix have been deleted from this
repo.

## Key Configuration Relationships

### Helmfile → Kustomize Flow

1. `helmfile.yaml` defines Helm chart source and values
2. `./scripts/template-helm.sh` generates static manifests in `helm/`
3. `kustomization.yaml` lists all generated manifests as resources
4. `kustomization.yaml` may add image digest pins for immutability
5. ArgoCD syncs from this repository or external GitOps repo

### Talos Configuration Files

- `kube-host-1.yaml`: Specific node overrides

### Cilium Networking

- `gatewayclass.yaml`: Defines Gateway API class
- `l2announcement-policy.yaml`: L2 advertisement configuration
- `lb-ip-pool.yaml`: LoadBalancer IP allocation pool

## Common Tasks

### Adding a New Kubernetes Service

1. Create directory: `clusters/home/<service-name>/`
2. Add `namespace.yaml`
3. Add `helmfile.yaml` with chart definition
4. Run `./scripts/template-helm.sh`
5. Create `kustomization.yaml` referencing namespace and helm manifests
6. Commit all files (including generated `helm/` directory)

### Updating a Service Version

1. Edit version in `clusters/home/<service>/helmfile.yaml`
2. Run `./scripts/template-helm.sh`
3. Review changes in `helm/` directory
4. Update image digests in `kustomization.yaml` if needed
5. Commit changes

### Modifying Helm Chart Values

1. Edit values in `clusters/home/<service>/helmfile.yaml`
2. Run `./scripts/template-helm.sh`
3. Commit changes to both `helmfile.yaml` and regenerated `helm/` manifests

## Security Considerations

- SSH keys in deployment config: `~/.ssh/rseipp_id_ed25519_sk`
- Secure boot enabled via lanzaboote module
- Image digests pinned in kustomization files for supply chain security
- Talos configuration files containing sensitive PKI data are gitignored
- When you need to run ceph commands, use the rook-ceph kubectl plugin like so:
  `kubectl rook ceph -n infra-storage ceph status`
