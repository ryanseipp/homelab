# OpenTelemetry Collector Configuration Comparison

## Key Differences Between Current Config and Helm Chart Presets

### 1. **k8sattributes Processor - Label/Annotation Extraction**

**Your Current Config:**

```yaml
k8sattributes:
  extract:
    labels:
      - tag_name: k8s.pod.labels
        key_regex: (.*)
        from: pod
    annotations:
      - tag_name: k8s.pod.annotations
        key_regex: (.*)
        from: pod
```

**Helm Preset Config:**

```yaml
k8sattributes:
  extract:
    annotations:
      - from: pod
        key_regex: (.*)
        tag_name: $$1
    labels:
      - from: pod
        key_regex: (.*)
        tag_name: $$1
```

**Difference:** The preset uses `tag_name: $$1` which creates individual
attributes for each label/annotation (e.g., `app.kubernetes.io/name: myapp`),
while your config groups them under `k8s.pod.labels` and `k8s.pod.annotations`
prefixes.

### 2. **k8sattributes Processor - Node Filtering**

**Your Current Config:**

- Missing node filtering

**Helm Preset Config:**

```yaml
k8sattributes:
  filter:
    node_from_env_var: K8S_NODE_NAME
```

**Impact:** This tells the k8sattributes processor to only process pods running
on the same node as the collector, which is critical for daemonset deployments.

### 3. **kubeletstats Receiver Endpoint**

**Your Current Config:**

```yaml
kubeletstats:
  endpoint: https://${env:K8S_NODE_NAME}:10250
```

**Helm Preset Config:**

```yaml
kubeletstats:
  endpoint: ${env:K8S_NODE_IP}:10250
```

**Difference:** Uses `K8S_NODE_IP` instead of `K8S_NODE_NAME`. This might be
more reliable as it uses the IP directly rather than relying on DNS resolution
of the node name.

### 4. **Processor Pipeline Order**

**Your Current Config (logs pipeline):**

```yaml
processors:
  - filter/logs
  - k8sattributes
  - transform/logs
  - memory_limiter
  - resourcedetection
  - batch
```

**Helm Preset Config (logs pipeline):**

```yaml
processors:
  - k8sattributes
  - memory_limiter
  - batch
```

**Difference:** The preset puts k8sattributes first, then memory_limiter, then
batch. Your config has additional processors (filter, transform,
resourcedetection) but the order is different.

### 5. **Memory Limiter Settings**

**Your Current Config:**

```yaml
memory_limiter:
  check_interval: 5s
  limit_percentage: 90
  spike_limit_percentage: 30
```

**Helm Preset Config:**

```yaml
memory_limiter:
  check_interval: 5s
  limit_percentage: 80
  spike_limit_percentage: 25
```

**Difference:** Preset is more conservative (80% vs 90%).

### 6. **Environment Variables**

**Your Current Config:**

- K8S_NODE_NAME
- K8S_POD_NAME
- K8S_POD_NAMESPACE
- K8S_POD_IP

**Helm Preset Config:**

- MY_POD_IP
- K8S_NODE_NAME
- K8S_NODE_IP

**Missing:** You don't have `K8S_NODE_IP` which is used by the kubeletstats
receiver in the preset.

### 7. **Volume Mounts**

**Your Current Config:**

```yaml
volumeMounts:
  - name: varlogpods
    mountPath: /var/log/pods
  - name: varlibkubelet
    mountPath: /var/lib/kubelet
  - name: hostfs
    mountPath: /hostfs
```

**Helm Preset Config:**

```yaml
volumeMounts:
  - name: varlogpods
    mountPath: /var/log/pods
  - name: varlibdockercontainers
    mountPath: /var/lib/docker/containers
  - name: hostfs
    mountPath: /hostfs
```

**Difference:** Preset uses `/var/lib/docker/containers` instead of
`/var/lib/kubelet`. However, for Talos Linux, this path might not exist.

## Potential Issues in Your Current Config

### **CRITICAL: Missing Node Filter in k8sattributes**

The most likely issue is the missing `filter.node_from_env_var` in your
k8sattributes processor. Without this, the processor might try to enrich
telemetry for ALL pods in the cluster, not just the ones on the local node. This
could cause:

- API server overload
- Incorrect metadata enrichment
- Performance issues

### **Kubeletstats Endpoint**

Using `K8S_NODE_NAME` might not resolve correctly. The preset uses `K8S_NODE_IP`
which is more direct.

### **Processor Order**

Having `memory_limiter` after several other processors means those processors
can consume unbounded memory before the limiter kicks in.

## Recommended Fixes

1. **Add node filtering to k8sattributes:**

   ```yaml
   k8sattributes:
     filter:
       node_from_env_var: K8S_NODE_NAME
   ```

2. **Add K8S_NODE_IP environment variable:**

   ```yaml
   env:
     - name: K8S_NODE_IP
       valueFrom:
         fieldRef:
           fieldPath: status.hostIP
   ```

3. **Consider using K8S_NODE_IP in kubeletstats endpoint:**

   ```yaml
   kubeletstats:
     endpoint: ${env:K8S_NODE_IP}:10250
   ```

4. **Reorder processors (optional but recommended):** Put memory_limiter earlier
   in the pipeline, right after k8sattributes.
