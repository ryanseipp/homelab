# Homelab

This is the declarative configuration for my entire homelab. It's currently a
single machine running NixOS to host a bare-metal Kubernetes cluster.

For more about the methodology and details of the configuration,
[read my posts about this homelab](https://ryanseipp.com/tag/homelab/).

## Features

- [x] Declarative Configuration
- [x] Continuous Focus on Security
- [x] NixOS Host Operating System
  - [x] (Mostly) Unattended Installation
  - [x] Automated Deployments
  - [x] Secure Boot
  - [x] At-Rest Encryption
  - [x] Secure SSH Access
- [ ] Kubernetes Bare-Metal
  - [ ] Cilium CNI
  - [ ] GitOps via ArgoCD
  - [ ] Rook Storage
  - [ ] Vault Secrets Storage
  - [ ] CSI Secrets Store Driver
  - [ ] External DNS
  - [ ] Prometheus/Tempo/Loki telemetry storage
  - [ ] OpenTelemetry
  - [ ] Cilium Hubble for networking o11y
  - [ ] Grafana Dashboards
