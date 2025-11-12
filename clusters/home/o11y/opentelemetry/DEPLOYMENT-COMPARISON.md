# OpenTelemetry Deployment Collector Configuration Comparison

## Overview

This document compares your current **deployment** OpenTelemetry Collector
configuration (`otel-deployment.yaml`) against a Helm chart configuration using
the `clusterMetrics` and `kubernetesEvents` presets.

## Summary of Findings

### ✅ What's Working Well

1. Your deployment correctly uses `k8s_cluster` receiver for cluster metrics
2. Resource limits are appropriate (100m/128Mi requests, 500m/256Mi limits)
3. Single replica is correct for cluster-level collection
4. OTLP receiver is configured for accepting pushed telemetry

### ❌ Critical Issues Found

1. **Missing Kubernetes Events Collection**: No `k8sobjects` receiver configured
2. **Undefined Processor Reference**: Pipeline references `resourcedetection`
   processor that isn't defined (line 67)
3. **Less Detailed Cluster Metrics**: Your config collects fewer node conditions
   than the preset defaults

### ℹ️ Additional Observations

1. Preset includes Jaeger and Zipkin receivers by default (may not be needed)
2. Preset uses a more conservative collection interval (10s vs 30s)
3. Preset adds comprehensive RBAC for all K8s resource types

---

## Detailed Comparison

### 1. Receivers Configuration

#### **k8s_cluster Receiver**

**Your Current Config** (`otel-deployment.yaml`):

```yaml
k8s_cluster:
  auth_type: serviceAccount
  collection_interval: 30s
  node_conditions_to_report:
    - Ready
    - MemoryPressure
    - DiskPressure
    - PIDPressure
    - NetworkUnavailable
  allocatable_types_to_report:
    - cpu
    - memory
    - storage
    - ephemeral-storage
```

**Helm Preset Config**:

```yaml
k8s_cluster:
  collection_interval: 10s
```

**Differences:**

- ❌ Preset uses **10s collection interval** (more frequent) vs your **30s**
  (less load)
- ✅ You explicitly configure node conditions and allocatable types (good for
  clarity)
- ✅ Preset uses defaults which include the same conditions
- **Recommendation**: Keep your config - it's more explicit and 30s is
  reasonable for most clusters

---

#### **k8sobjects Receiver (Kubernetes Events)**

**Your Current Config**:

```yaml
# ❌ NOT CONFIGURED - MISSING!
```

**Helm Preset Config**:

```yaml
k8sobjects:
  objects:
    - exclude_watch_type:
        - DELETED
      group: events.k8s.io
      mode: watch
      name: events
```

**Impact**: You are **NOT collecting Kubernetes events** which include:

- Pod scheduling events
- Image pull errors
- Container crashes and restarts
- Volume mount failures
- Resource quota violations
- Node conditions changes

**Recommendation**: ⚠️ **CRITICAL** - Add this receiver to collect K8s events
for troubleshooting

---

#### **OTLP Receiver**

**Your Current Config**:

```yaml
otlp:
  protocols:
    grpc:
      endpoint: 0.0.0.0:4317
    http:
      endpoint: 0.0.0.0:4318
```

**Helm Preset Config**:

```yaml
otlp:
  protocols:
    grpc:
      endpoint: ${env:MY_POD_IP}:4317
    http:
      endpoint: ${env:MY_POD_IP}:4318
```

**Differences:**

- Your config binds to all interfaces (`0.0.0.0`)
- Preset binds to pod IP only (`${env:MY_POD_IP}`)
- **Recommendation**: Using `0.0.0.0` is fine for a deployment collector that
  should accept cluster-wide traffic

---

#### **Additional Receivers in Preset** (Not in your config)

Preset also includes:

- `jaeger` receiver (3 protocols: gRPC, thrift_compact, thrift_http)
- `zipkin` receiver
- `prometheus` receiver (for self-monitoring)

**Recommendation**:

- ❌ You probably don't need Jaeger/Zipkin unless you have apps using those
  formats
- ✅ Consider adding `prometheus` receiver for collector self-monitoring

---

### 2. Processors Configuration

#### **Your Current Config**:

```yaml
processors:
  batch: {}

  memory_limiter:
    check_interval: 5s
    limit_percentage: 80
    spike_limit_percentage: 25
```

#### **Helm Preset Config**:

```yaml
processors:
  batch: {}

  memory_limiter:
    check_interval: 5s
    limit_percentage: 80
    spike_limit_percentage: 25
```

**Comparison**: ✅ Identical configuration - well done!

---

#### **⚠️ CRITICAL BUG: Undefined Processor**

**Your Current Pipeline** (line 60-70):

```yaml
service:
  pipelines:
    metrics:
      receivers:
        - k8s_cluster
        - otlp
      processors:
        - memory_limiter
        - resourcedetection # ❌ NOT DEFINED IN processors SECTION!
        - batch
      exporters:
        - otlphttp/mimir
```

**Issue**: Your pipeline references `resourcedetection` processor but it's not
defined in the `processors` section. This will cause the collector to fail to
start or error.

**Preset Pipeline**:

```yaml
service:
  pipelines:
    metrics:
      processors:
        - memory_limiter
        - batch
      receivers:
        - otlp
        - prometheus
        - k8s_cluster
```

**Recommendation**: Either:

1. ❌ Remove `resourcedetection` from the pipeline (if not needed)
2. ✅ Define it properly:
   ```yaml
   processors:
     resourcedetection:
       detectors: [env, system]
       timeout: 5s
   ```

---

### 3. Exporters Configuration

#### **Your Current Config**:

```yaml
exporters:
  otlphttp/mimir:
    endpoint: http://mimir-gateway.o11y-metrics.svc.cluster.local:80/otlp
    tls:
      insecure: true
```

#### **Helm Preset Config**:

```yaml
exporters:
  otlphttp/loki:
    endpoint: http://loki-gateway.o11y-logs.svc.cluster.local:80/otlp
    tls:
      insecure: true
  otlphttp/mimir:
    endpoint: http://mimir-gateway.o11y-metrics.svc.cluster.local:80/otlp
    tls:
      insecure: true
  debug: {}
```

**Differences:**

- ✅ Your metrics exporter is correct
- ❌ You're missing **Loki exporter for logs** (needed for K8s events)
- Preset includes `debug` exporter (useful for troubleshooting)

**Recommendation**: Add Loki exporter since K8s events should be sent as logs

---

### 4. Service Pipelines

#### **Your Current Config**:

```yaml
service:
  pipelines:
    metrics:
      receivers: [k8s_cluster, otlp]
      processors: [memory_limiter, resourcedetection, batch] # ❌ resourcedetection not defined
      exporters: [otlphttp/mimir]
```

#### **Helm Preset Config**:

```yaml
service:
  pipelines:
    logs:
      receivers: [otlp, k8sobjects] # ✅ Includes K8s events
      processors: [memory_limiter, batch]
      exporters: [otlphttp/loki]

    metrics:
      receivers: [otlp, prometheus, k8s_cluster]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/mimir]

    traces:
      receivers: [otlp, jaeger, zipkin]
      processors: [memory_limiter, batch]
      exporters: [debug]
```

**Key Differences:**

1. ❌ **You have no logs pipeline** - K8s events won't be collected
2. ❌ You reference undefined `resourcedetection` processor
3. Preset includes traces pipeline (though you might not need Jaeger/Zipkin)
4. ✅ Preset includes `prometheus` receiver for collector self-monitoring

---

### 5. RBAC Permissions

#### **Your Current Config**:

You're using the OpenTelemetry Operator's CRD (`kind: OpenTelemetryCollector`),
so RBAC is managed by the operator automatically.

#### **Helm Preset ClusterRole**:

```yaml
rules:
  - apiGroups: [""]
    resources:
      [
        "events",
        "namespaces",
        "namespaces/status",
        "nodes",
        "nodes/spec",
        "pods",
        "pods/status",
        "replicationcontrollers",
        "replicationcontrollers/status",
        "resourcequotas",
        "services",
      ]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["daemonsets", "deployments", "replicasets", "statefulsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["extensions"]
    resources: ["daemonsets", "deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["events.k8s.io"]
    resources: ["events"]
    verbs: ["watch", "list"]
```

**Required for:**

- `k8s_cluster` receiver: Needs access to nodes, pods, namespaces, deployments,
  etc.
- `k8sobjects` receiver: Needs access to events in `events.k8s.io` API group

**Recommendation**: Check that your OpenTelemetry Operator deployment RBAC
includes:

- Access to `events.k8s.io` API group for events collection
- All the resources listed above

---

### 6. Environment Variables

#### **Your Current Config**:

```yaml
# Using operator CRD - env vars managed by operator
```

#### **Helm Preset Config**:

```yaml
env:
  - name: MY_POD_IP
    valueFrom:
      fieldRef:
        apiVersion: v1
        fieldPath: status.podIP
  - name: GOMEMLIMIT
    value: "204MiB"
```

**Recommendation**: Ensure your operator provides `MY_POD_IP` if you want to use
pod IP in config

---

## Recommended Changes to Your Deployment Config

### Priority 1: Critical Fixes

#### 1. Remove or Define `resourcedetection` Processor

**Option A - Remove it** (if not needed):

```yaml
service:
  pipelines:
    metrics:
      receivers:
        - k8s_cluster
        - otlp
      processors:
        - memory_limiter
        - batch # Removed resourcedetection
      exporters:
        - otlphttp/mimir
```

**Option B - Define it properly** (if you want resource detection):

```yaml
processors:
  batch: {}

  memory_limiter:
    check_interval: 5s
    limit_percentage: 80
    spike_limit_percentage: 25

  resourcedetection: # Add this
    detectors: [env, system]
    timeout: 5s
    override: false
```

---

#### 2. Add Kubernetes Events Collection

Add the receiver:

```yaml
receivers:
  k8s_cluster:
    # ... existing config ...

  otlp:
    # ... existing config ...

  # Add this:
  k8sobjects:
    auth_type: serviceAccount
    objects:
      - name: events
        mode: watch
        group: events.k8s.io
        exclude_watch_type:
          - DELETED
```

Add the Loki exporter:

```yaml
exporters:
  otlphttp/mimir:
    # ... existing config ...

  # Add this:
  otlphttp/loki:
    endpoint: http://loki-gateway.o11y-logs.svc.cluster.local:80/otlp
    tls:
      insecure: true
```

Add the logs pipeline:

```yaml
service:
  pipelines:
    # Add this new pipeline:
    logs:
      receivers:
        - k8sobjects
      processors:
        - memory_limiter
        - batch
      exporters:
        - otlphttp/loki

    metrics:
      # ... existing config ...
```

---

### Priority 2: Enhancements (Optional)

#### 3. Add Self-Monitoring

```yaml
receivers:
  # ... existing receivers ...

  prometheus:
    config:
      scrape_configs:
        - job_name: otel-collector
          scrape_interval: 30s
          static_configs:
            - targets:
                - 0.0.0.0:8888
```

Add to metrics pipeline:

```yaml
metrics:
  receivers:
    - k8s_cluster
    - otlp
    - prometheus # Add this
```

#### 4. Increase Collection Frequency (Optional)

If you want more real-time metrics:

```yaml
k8s_cluster:
  collection_interval: 10s # Changed from 30s
```

---

## Final Recommended Configuration

Here's what your deployment collector should look like with all fixes:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-k8scluster
  namespace: o11y-collector
spec:
  mode: deployment
  replicas: 1

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

  config:
    receivers:
      # Kubernetes cluster-level metrics from API
      k8s_cluster:
        auth_type: serviceAccount
        collection_interval: 30s
        node_conditions_to_report:
          - Ready
          - MemoryPressure
          - DiskPressure
          - PIDPressure
          - NetworkUnavailable
        allocatable_types_to_report:
          - cpu
          - memory
          - storage
          - ephemeral-storage

      # Kubernetes events
      k8sobjects:
        auth_type: serviceAccount
        objects:
          - name: events
            mode: watch
            group: events.k8s.io
            exclude_watch_type:
              - DELETED

      # OTLP receiver for pushed telemetry
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      # Self-monitoring (optional)
      prometheus:
        config:
          scrape_configs:
            - job_name: otel-collector
              scrape_interval: 30s
              static_configs:
                - targets:
                    - 0.0.0.0:8888

    processors:
      batch: {}

      memory_limiter:
        check_interval: 5s
        limit_percentage: 80
        spike_limit_percentage: 25

    exporters:
      # Export logs to Loki
      otlphttp/loki:
        endpoint: http://loki-gateway.o11y-logs.svc.cluster.local:80/otlp
        tls:
          insecure: true

      # Export metrics to Mimir
      otlphttp/mimir:
        endpoint: http://mimir-gateway.o11y-metrics.svc.cluster.local:80/otlp
        tls:
          insecure: true

    service:
      pipelines:
        # New logs pipeline for K8s events
        logs:
          receivers:
            - k8sobjects
          processors:
            - memory_limiter
            - batch
          exporters:
            - otlphttp/loki

        metrics:
          receivers:
            - k8s_cluster
            - otlp
            - prometheus
          processors:
            - memory_limiter
            - batch
          exporters:
            - otlphttp/mimir
```

---

## Testing Plan

After applying the recommended changes:

1. **Verify collector starts successfully**:

   ```bash
   kubectl get pods -n o11y-collector -l app.kubernetes.io/name=otel-k8scluster
   kubectl logs -n o11y-collector -l app.kubernetes.io/name=otel-k8scluster
   ```

2. **Check for errors in logs**:

   ```bash
   kubectl logs -n o11y-collector -l app.kubernetes.io/name=otel-k8scluster | grep -i error
   ```

3. **Verify K8s events are being collected**:
   - In Grafana, check Loki logs with label `k8s_object_name="events"`
   - Create a test pod that fails to verify events appear

4. **Verify cluster metrics are being collected**:
   - In Grafana, query Mimir for metrics like `k8s_node_condition` or
     `k8s_node_allocatable_cpu`

5. **Check RBAC permissions**:
   ```bash
   kubectl auth can-i list events.v1.events.k8s.io --as=system:serviceaccount:o11y-collector:otel-k8scluster -n o11y-collector
   ```

---

## Summary Table

| Feature                         | Current Config              | Preset Config       | Recommendation        |
| ------------------------------- | --------------------------- | ------------------- | --------------------- |
| **k8s_cluster receiver**        | ✅ Configured (30s)         | ✅ Configured (10s) | ✅ Keep your config   |
| **k8sobjects receiver**         | ❌ Missing                  | ✅ Configured       | ⚠️ **ADD THIS**       |
| **OTLP receiver**               | ✅ Configured               | ✅ Configured       | ✅ Keep your config   |
| **Loki exporter**               | ❌ Missing                  | ✅ Configured       | ⚠️ **ADD THIS**       |
| **Logs pipeline**               | ❌ Missing                  | ✅ Configured       | ⚠️ **ADD THIS**       |
| **resourcedetection processor** | ❌ Referenced but undefined | ❌ Not used         | ⚠️ **FIX THIS**       |
| **Prometheus receiver**         | ❌ Missing                  | ✅ Configured       | ✅ Consider adding    |
| **Jaeger/Zipkin receivers**     | ❌ Not needed               | ✅ Included         | ❌ Skip unless needed |
| **Resource limits**             | ✅ Appropriate              | ✅ Same             | ✅ Keep as is         |
| **Collection interval**         | ✅ 30s (reasonable)         | 10s (more frequent) | ✅ Keep 30s           |

---

## Conclusion

Your deployment collector configuration is mostly good, but has two critical
issues:

1. **Missing Kubernetes events collection** - You're not capturing important
   cluster events
2. **Broken processor reference** - `resourcedetection` processor is referenced
   but not defined

The helm chart presets provide a good baseline, but your manual configuration is
actually more explicit and customized. The presets mainly show you what's
missing (K8s events) rather than suggesting you should switch to using them.

**Action Items:**

1. ⚠️ **CRITICAL**: Remove `resourcedetection` from pipeline or define it
   properly
2. ⚠️ **CRITICAL**: Add `k8sobjects` receiver to collect Kubernetes events
3. ⚠️ **CRITICAL**: Add logs pipeline and Loki exporter for events
4. ✅ **OPTIONAL**: Add `prometheus` receiver for collector self-monitoring
