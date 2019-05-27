#!jinja | kubernetes kubeconfig=/etc/kubernetes/admin.conf&context=kubernetes-admin@kubernetes

{%- from "metalk8s/repo/macro.sls" import build_image_name with context %}

# The content below has been generated from
# https://github.com/coreos/prometheus-operator, v0.29.0 tag,
# with the following command:
#   hack/concat-kubernetes-manifests.sh $(find contrib/kube-prometheus/manifests/ \
#     -name "prometheus-*.yaml") > deployed.sls
# In the following, only container image registries have been replaced.

---
apiVersion: v1
data:
  config.yaml: |
    resourceRules:
      cpu:
        containerQuery: sum(rate(container_cpu_usage_seconds_total{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)
        nodeQuery: sum(rate(container_cpu_usage_seconds_total{<<.LabelMatchers>>, id='/'}[1m])) by (<<.GroupBy>>)
        resources:
          overrides:
            node:
              resource: node
            namespace:
              resource: namespace
            pod_name:
              resource: pod
        containerLabel: container_name
      memory:
        containerQuery: sum(container_memory_working_set_bytes{<<.LabelMatchers>>}) by (<<.GroupBy>>)
        nodeQuery: sum(container_memory_working_set_bytes{<<.LabelMatchers>>,id='/'}) by (<<.GroupBy>>)
        resources:
          overrides:
            node:
              resource: node
            namespace:
              resource: namespace
            pod_name:
              resource: pod
        containerLabel: container_name
      window: 1m
kind: ConfigMap
metadata:
  name: adapter-config
  namespace: monitoring
---
apiVersion: apiregistration.k8s.io/v1beta1
kind: APIService
metadata:
  name: v1beta1.metrics.k8s.io
spec:
  group: metrics.k8s.io
  groupPriorityMinimum: 100
  insecureSkipTLSVerify: true
  service:
    name: prometheus-adapter
    namespace: monitoring
  version: v1beta1
  versionPriority: 100
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-adapter
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  - namespaces
  - pods
  - services
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: resource-metrics:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: prometheus-adapter
  namespace: monitoring
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: prometheus
  name: prometheus
  namespace: monitoring
spec:
  endpoints:
  - interval: 30s
    port: web
  selector:
    matchLabels:
      prometheus: k8s
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-k8s
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-k8s
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-k8s
rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  verbs:
  - get
- nonResourceURLs:
  - /metrics
  verbs:
  - get
---
{%- raw %}
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    prometheus: k8s
    role: alert-rules
  name: prometheus-k8s-rules
  namespace: monitoring
spec:
  groups:
  - name: k8s.rules
    rules:
    - expr: |
        sum(rate(container_cpu_usage_seconds_total{job="kubelet", image!="", container_name!=""}[5m])) by (namespace)
      record: namespace:container_cpu_usage_seconds_total:sum_rate
    - expr: |
        sum by (namespace, pod_name, container_name) (
          rate(container_cpu_usage_seconds_total{job="kubelet", image!="", container_name!=""}[5m])
        )
      record: namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate
    - expr: |
        sum(container_memory_usage_bytes{job="kubelet", image!="", container_name!=""}) by (namespace)
      record: namespace:container_memory_usage_bytes:sum
    - expr: |
        sum by (namespace, label_name) (
           sum(rate(container_cpu_usage_seconds_total{job="kubelet", image!="", container_name!=""}[5m])) by (namespace, pod_name)
         * on (namespace, pod_name) group_left(label_name)
           label_replace(kube_pod_labels{job="kube-state-metrics"}, "pod_name", "$1", "pod", "(.*)")
        )
      record: namespace_name:container_cpu_usage_seconds_total:sum_rate
    - expr: |
        sum by (namespace, label_name) (
          sum(container_memory_usage_bytes{job="kubelet",image!="", container_name!=""}) by (pod_name, namespace)
        * on (namespace, pod_name) group_left(label_name)
          label_replace(kube_pod_labels{job="kube-state-metrics"}, "pod_name", "$1", "pod", "(.*)")
        )
      record: namespace_name:container_memory_usage_bytes:sum
    - expr: |
        sum by (namespace, label_name) (
          sum(kube_pod_container_resource_requests_memory_bytes{job="kube-state-metrics"}) by (namespace, pod)
        * on (namespace, pod) group_left(label_name)
          label_replace(kube_pod_labels{job="kube-state-metrics"}, "pod_name", "$1", "pod", "(.*)")
        )
      record: namespace_name:kube_pod_container_resource_requests_memory_bytes:sum
    - expr: |
        sum by (namespace, label_name) (
          sum(kube_pod_container_resource_requests_cpu_cores{job="kube-state-metrics"} and on(pod) kube_pod_status_scheduled{condition="true"}) by (namespace, pod)
        * on (namespace, pod) group_left(label_name)
          label_replace(kube_pod_labels{job="kube-state-metrics"}, "pod_name", "$1", "pod", "(.*)")
        )
      record: namespace_name:kube_pod_container_resource_requests_cpu_cores:sum
  - name: kube-scheduler.rules
    rules:
    - expr: |
        histogram_quantile(0.99, sum(rate(scheduler_e2e_scheduling_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.99"
      record: cluster_quantile:scheduler_e2e_scheduling_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.99, sum(rate(scheduler_scheduling_algorithm_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.99"
      record: cluster_quantile:scheduler_scheduling_algorithm_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.99, sum(rate(scheduler_binding_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.99"
      record: cluster_quantile:scheduler_binding_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.9, sum(rate(scheduler_e2e_scheduling_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.9"
      record: cluster_quantile:scheduler_e2e_scheduling_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.9, sum(rate(scheduler_scheduling_algorithm_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.9"
      record: cluster_quantile:scheduler_scheduling_algorithm_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.9, sum(rate(scheduler_binding_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.9"
      record: cluster_quantile:scheduler_binding_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.5, sum(rate(scheduler_e2e_scheduling_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.5"
      record: cluster_quantile:scheduler_e2e_scheduling_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.5, sum(rate(scheduler_scheduling_algorithm_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.5"
      record: cluster_quantile:scheduler_scheduling_algorithm_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.5, sum(rate(scheduler_binding_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.5"
      record: cluster_quantile:scheduler_binding_latency:histogram_quantile
  - name: kube-apiserver.rules
    rules:
    - expr: |
        histogram_quantile(0.99, sum(rate(apiserver_request_latencies_bucket{job="apiserver"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.99"
      record: cluster_quantile:apiserver_request_latencies:histogram_quantile
    - expr: |
        histogram_quantile(0.9, sum(rate(apiserver_request_latencies_bucket{job="apiserver"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.9"
      record: cluster_quantile:apiserver_request_latencies:histogram_quantile
    - expr: |
        histogram_quantile(0.5, sum(rate(apiserver_request_latencies_bucket{job="apiserver"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.5"
      record: cluster_quantile:apiserver_request_latencies:histogram_quantile
  - name: node.rules
    rules:
    - expr: sum(min(kube_pod_info) by (node))
      record: ':kube_pod_info_node_count:'
    - expr: |
        max(label_replace(kube_pod_info{job="kube-state-metrics"}, "pod", "$1", "pod", "(.*)")) by (node, namespace, pod)
      record: 'node_namespace_pod:kube_pod_info:'
    - expr: |
        count by (node) (sum by (node, cpu) (
          node_cpu_seconds_total{job="node-exporter"}
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        ))
      record: node:node_num_cpu:sum
    - expr: |
        1 - avg(rate(node_cpu_seconds_total{job="node-exporter",mode="idle"}[1m]))
      record: :node_cpu_utilisation:avg1m
    - expr: |
        1 - avg by (node) (
          rate(node_cpu_seconds_total{job="node-exporter",mode="idle"}[1m])
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:)
      record: node:node_cpu_utilisation:avg1m
    - expr: |
        node:node_cpu_utilisation:avg1m
          *
        node:node_num_cpu:sum
          /
        scalar(sum(node:node_num_cpu:sum))
      record: node:cluster_cpu_utilisation:ratio
    - expr: |
        sum(node_load1{job="node-exporter"})
        /
        sum(node:node_num_cpu:sum)
      record: ':node_cpu_saturation_load1:'
    - expr: |
        sum by (node) (
          node_load1{job="node-exporter"}
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
        /
        node:node_num_cpu:sum
      record: 'node:node_cpu_saturation_load1:'
    - expr: |
        1 -
        sum(node_memory_MemFree_bytes{job="node-exporter"} + node_memory_Cached_bytes{job="node-exporter"} + node_memory_Buffers_bytes{job="node-exporter"})
        /
        sum(node_memory_MemTotal_bytes{job="node-exporter"})
      record: ':node_memory_utilisation:'
    - expr: |
        sum(node_memory_MemFree_bytes{job="node-exporter"} + node_memory_Cached_bytes{job="node-exporter"} + node_memory_Buffers_bytes{job="node-exporter"})
      record: :node_memory_MemFreeCachedBuffers_bytes:sum
    - expr: |
        sum(node_memory_MemTotal_bytes{job="node-exporter"})
      record: :node_memory_MemTotal_bytes:sum
    - expr: |
        sum by (node) (
          (node_memory_MemFree_bytes{job="node-exporter"} + node_memory_Cached_bytes{job="node-exporter"} + node_memory_Buffers_bytes{job="node-exporter"})
          * on (namespace, pod) group_left(node)
            node_namespace_pod:kube_pod_info:
        )
      record: node:node_memory_bytes_available:sum
    - expr: |
        sum by (node) (
          node_memory_MemTotal_bytes{job="node-exporter"}
          * on (namespace, pod) group_left(node)
            node_namespace_pod:kube_pod_info:
        )
      record: node:node_memory_bytes_total:sum
    - expr: |
        (node:node_memory_bytes_total:sum - node:node_memory_bytes_available:sum)
        /
        node:node_memory_bytes_total:sum
      record: node:node_memory_utilisation:ratio
    - expr: |
        (node:node_memory_bytes_total:sum - node:node_memory_bytes_available:sum)
        /
        scalar(sum(node:node_memory_bytes_total:sum))
      record: node:cluster_memory_utilisation:ratio
    - expr: |
        1e3 * sum(
          (rate(node_vmstat_pgpgin{job="node-exporter"}[1m])
         + rate(node_vmstat_pgpgout{job="node-exporter"}[1m]))
        )
      record: :node_memory_swap_io_bytes:sum_rate
    - expr: |
        1 -
        sum by (node) (
          (node_memory_MemFree_bytes{job="node-exporter"} + node_memory_Cached_bytes{job="node-exporter"} + node_memory_Buffers_bytes{job="node-exporter"})
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
        /
        sum by (node) (
          node_memory_MemTotal_bytes{job="node-exporter"}
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: 'node:node_memory_utilisation:'
    - expr: |
        1 - (node:node_memory_bytes_available:sum / node:node_memory_bytes_total:sum)
      record: 'node:node_memory_utilisation_2:'
    - expr: |
        1e3 * sum by (node) (
          (rate(node_vmstat_pgpgin{job="node-exporter"}[1m])
         + rate(node_vmstat_pgpgout{job="node-exporter"}[1m]))
         * on (namespace, pod) group_left(node)
           node_namespace_pod:kube_pod_info:
        )
      record: node:node_memory_swap_io_bytes:sum_rate
    - expr: |
        avg(irate(node_disk_io_time_seconds_total{job="node-exporter",device=~"nvme.+|rbd.+|sd.+|vd.+|xvd.+"}[1m]))
      record: :node_disk_utilisation:avg_irate
    - expr: |
        avg by (node) (
          irate(node_disk_io_time_seconds_total{job="node-exporter",device=~"nvme.+|rbd.+|sd.+|vd.+|xvd.+"}[1m])
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: node:node_disk_utilisation:avg_irate
    - expr: |
        avg(irate(node_disk_io_time_weighted_seconds_total{job="node-exporter",device=~"nvme.+|rbd.+|sd.+|vd.+|xvd.+"}[1m]) / 1e3)
      record: :node_disk_saturation:avg_irate
    - expr: |
        avg by (node) (
          irate(node_disk_io_time_weighted_seconds_total{job="node-exporter",device=~"nvme.+|rbd.+|sd.+|vd.+|xvd.+"}[1m]) / 1e3
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: node:node_disk_saturation:avg_irate
    - expr: |
        max by (namespace, pod, device) ((node_filesystem_size_bytes{fstype=~"ext[234]|btrfs|xfs|zfs"}
        - node_filesystem_avail_bytes{fstype=~"ext[234]|btrfs|xfs|zfs"})
        / node_filesystem_size_bytes{fstype=~"ext[234]|btrfs|xfs|zfs"})
      record: 'node:node_filesystem_usage:'
    - expr: |
        max by (namespace, pod, device) (node_filesystem_avail_bytes{fstype=~"ext[234]|btrfs|xfs|zfs"} / node_filesystem_size_bytes{fstype=~"ext[234]|btrfs|xfs|zfs"})
      record: 'node:node_filesystem_avail:'
    - expr: |
        sum(irate(node_network_receive_bytes_total{job="node-exporter",device!~"veth.+"}[1m])) +
        sum(irate(node_network_transmit_bytes_total{job="node-exporter",device!~"veth.+"}[1m]))
      record: :node_net_utilisation:sum_irate
    - expr: |
        sum by (node) (
          (irate(node_network_receive_bytes_total{job="node-exporter",device!~"veth.+"}[1m]) +
          irate(node_network_transmit_bytes_total{job="node-exporter",device!~"veth.+"}[1m]))
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: node:node_net_utilisation:sum_irate
    - expr: |
        sum(irate(node_network_receive_drop_total{job="node-exporter",device!~"veth.+"}[1m])) +
        sum(irate(node_network_transmit_drop_total{job="node-exporter",device!~"veth.+"}[1m]))
      record: :node_net_saturation:sum_irate
    - expr: |
        sum by (node) (
          (irate(node_network_receive_drop_total{job="node-exporter",device!~"veth.+"}[1m]) +
          irate(node_network_transmit_drop_total{job="node-exporter",device!~"veth.+"}[1m]))
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: node:node_net_saturation:sum_irate
    - expr: |
        max(
          max(
            kube_pod_info{job="kube-state-metrics", host_ip!=""}
          ) by (node, host_ip)
          * on (host_ip) group_right (node)
          label_replace(
            (max(node_filesystem_files{job="node-exporter", mountpoint="/"}) by (instance)), "host_ip", "$1", "instance", "(.*):.*"
          )
        ) by (node)
      record: 'node:node_inodes_total:'
    - expr: |
        max(
          max(
            kube_pod_info{job="kube-state-metrics", host_ip!=""}
          ) by (node, host_ip)
          * on (host_ip) group_right (node)
          label_replace(
            (max(node_filesystem_files_free{job="node-exporter", mountpoint="/"}) by (instance)), "host_ip", "$1", "instance", "(.*):.*"
          )
        ) by (node)
      record: 'node:node_inodes_free:'
  - name: kube-prometheus-node-recording.rules
    rules:
    - expr: sum(rate(node_cpu_seconds_total{mode!="idle",mode!="iowait"}[3m])) BY
        (instance)
      record: instance:node_cpu:rate:sum
    - expr: sum((node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}))
        BY (instance)
      record: instance:node_filesystem_usage:sum
    - expr: sum(rate(node_network_receive_bytes_total[3m])) BY (instance)
      record: instance:node_network_receive_bytes:rate:sum
    - expr: sum(rate(node_network_transmit_bytes_total[3m])) BY (instance)
      record: instance:node_network_transmit_bytes:rate:sum
    - expr: sum(rate(node_cpu_seconds_total{mode!="idle",mode!="iowait"}[5m])) WITHOUT
        (cpu, mode) / ON(instance) GROUP_LEFT() count(sum(node_cpu_seconds_total)
        BY (instance, cpu)) BY (instance)
      record: instance:node_cpu:ratio
    - expr: sum(rate(node_cpu_seconds_total{mode!="idle",mode!="iowait"}[5m]))
      record: cluster:node_cpu:sum_rate5m
    - expr: cluster:node_cpu_seconds_total:rate5m / count(sum(node_cpu_seconds_total)
        BY (instance, cpu))
      record: cluster:node_cpu:ratio
  - name: kubernetes-absent
    rules:
    - alert: AlertmanagerDown
      annotations:
        message: Alertmanager has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-alertmanagerdown
      expr: |
        absent(up{job="alertmanager-main",namespace="monitoring"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: CoreDNSDown
      annotations:
        message: CoreDNS has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-corednsdown
      expr: |
        absent(up{job="kube-dns"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeAPIDown
      annotations:
        message: KubeAPI has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapidown
      expr: |
        absent(up{job="apiserver"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeControllerManagerDown
      annotations:
        message: KubeControllerManager has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubecontrollermanagerdown
      expr: |
        absent(up{job="kube-controller-manager"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeSchedulerDown
      annotations:
        message: KubeScheduler has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeschedulerdown
      expr: |
        absent(up{job="kube-scheduler"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeStateMetricsDown
      annotations:
        message: KubeStateMetrics has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubestatemetricsdown
      expr: |
        absent(up{job="kube-state-metrics"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeletDown
      annotations:
        message: Kubelet has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeletdown
      expr: |
        absent(up{job="kubelet"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: NodeExporterDown
      annotations:
        message: NodeExporter has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-nodeexporterdown
      expr: |
        absent(up{job="node-exporter"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: PrometheusDown
      annotations:
        message: Prometheus has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-prometheusdown
      expr: |
        absent(up{job="prometheus-k8s",namespace="monitoring"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: PrometheusOperatorDown
      annotations:
        message: PrometheusOperator has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-prometheusoperatordown
      expr: |
        absent(up{job="prometheus-operator",namespace="monitoring"} == 1)
      for: 15m
      labels:
        severity: critical
  - name: kubernetes-apps
    rules:
    - alert: KubePodCrashLooping
      annotations:
        message: Pod {{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container
          }}) is restarting {{ printf "%.2f" $value }} times / 5 minutes.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepodcrashlooping
      expr: |
        rate(kube_pod_container_status_restarts_total{job="kube-state-metrics"}[15m]) * 60 * 5 > 0
      for: 1h
      labels:
        severity: critical
    - alert: KubePodNotReady
      annotations:
        message: Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-ready
          state for longer than an hour.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepodnotready
      expr: |
        sum by (namespace, pod) (kube_pod_status_phase{job="kube-state-metrics", phase=~"Pending|Unknown"}) > 0
      for: 1h
      labels:
        severity: critical
    - alert: KubeDeploymentGenerationMismatch
      annotations:
        message: Deployment generation for {{ $labels.namespace }}/{{ $labels.deployment
          }} does not match, this indicates that the Deployment has failed but has
          not been rolled back.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedeploymentgenerationmismatch
      expr: |
        kube_deployment_status_observed_generation{job="kube-state-metrics"}
          !=
        kube_deployment_metadata_generation{job="kube-state-metrics"}
      for: 15m
      labels:
        severity: critical
    - alert: KubeDeploymentReplicasMismatch
      annotations:
        message: Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has not
          matched the expected number of replicas for longer than an hour.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedeploymentreplicasmismatch
      expr: |
        kube_deployment_spec_replicas{job="kube-state-metrics"}
          !=
        kube_deployment_status_replicas_available{job="kube-state-metrics"}
      for: 1h
      labels:
        severity: critical
    - alert: KubeStatefulSetReplicasMismatch
      annotations:
        message: StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has
          not matched the expected number of replicas for longer than 15 minutes.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubestatefulsetreplicasmismatch
      expr: |
        kube_statefulset_status_replicas_ready{job="kube-state-metrics"}
          !=
        kube_statefulset_status_replicas{job="kube-state-metrics"}
      for: 15m
      labels:
        severity: critical
    - alert: KubeStatefulSetGenerationMismatch
      annotations:
        message: StatefulSet generation for {{ $labels.namespace }}/{{ $labels.statefulset
          }} does not match, this indicates that the StatefulSet has failed but has
          not been rolled back.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubestatefulsetgenerationmismatch
      expr: |
        kube_statefulset_status_observed_generation{job="kube-state-metrics"}
          !=
        kube_statefulset_metadata_generation{job="kube-state-metrics"}
      for: 15m
      labels:
        severity: critical
    - alert: KubeStatefulSetUpdateNotRolledOut
      annotations:
        message: StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} update
          has not been rolled out.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubestatefulsetupdatenotrolledout
      expr: |
        max without (revision) (
          kube_statefulset_status_current_revision{job="kube-state-metrics"}
            unless
          kube_statefulset_status_update_revision{job="kube-state-metrics"}
        )
          *
        (
          kube_statefulset_replicas{job="kube-state-metrics"}
            !=
          kube_statefulset_status_replicas_updated{job="kube-state-metrics"}
        )
      for: 15m
      labels:
        severity: critical
    - alert: KubeDaemonSetRolloutStuck
      annotations:
        message: Only {{ $value }}% of the desired Pods of DaemonSet {{ $labels.namespace
          }}/{{ $labels.daemonset }} are scheduled and ready.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedaemonsetrolloutstuck
      expr: |
        kube_daemonset_status_number_ready{job="kube-state-metrics"}
          /
        kube_daemonset_status_desired_number_scheduled{job="kube-state-metrics"} * 100 < 100
      for: 15m
      labels:
        severity: critical
    - alert: KubeDaemonSetNotScheduled
      annotations:
        message: '{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset
          }} are not scheduled.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedaemonsetnotscheduled
      expr: |
        kube_daemonset_status_desired_number_scheduled{job="kube-state-metrics"}
          -
        kube_daemonset_status_current_number_scheduled{job="kube-state-metrics"} > 0
      for: 10m
      labels:
        severity: warning
    - alert: KubeDaemonSetMisScheduled
      annotations:
        message: '{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset
          }} are running where they are not supposed to run.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedaemonsetmisscheduled
      expr: |
        kube_daemonset_status_number_misscheduled{job="kube-state-metrics"} > 0
      for: 10m
      labels:
        severity: warning
    - alert: KubeCronJobRunning
      annotations:
        message: CronJob {{ $labels.namespace }}/{{ $labels.cronjob }} is taking more
          than 1h to complete.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubecronjobrunning
      expr: |
        time() - kube_cronjob_next_schedule_time{job="kube-state-metrics"} > 3600
      for: 1h
      labels:
        severity: warning
    - alert: KubeJobCompletion
      annotations:
        message: Job {{ $labels.namespace }}/{{ $labels.job_name }} is taking more
          than one hour to complete.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubejobcompletion
      expr: |
        kube_job_spec_completions{job="kube-state-metrics"} - kube_job_status_succeeded{job="kube-state-metrics"}  > 0
      for: 1h
      labels:
        severity: warning
    - alert: KubeJobFailed
      annotations:
        message: Job {{ $labels.namespace }}/{{ $labels.job_name }} failed to complete.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubejobfailed
      expr: |
        kube_job_status_failed{job="kube-state-metrics"}  > 0
      for: 1h
      labels:
        severity: warning
  - name: kubernetes-resources
    rules:
    - alert: KubeCPUOvercommit
      annotations:
        message: Cluster has overcommitted CPU resource requests for Pods and cannot
          tolerate node failure.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubecpuovercommit
      expr: |
        sum(namespace_name:kube_pod_container_resource_requests_cpu_cores:sum)
          /
        sum(node:node_num_cpu:sum)
          >
        (count(node:node_num_cpu:sum)-1) / count(node:node_num_cpu:sum)
      for: 5m
      labels:
        severity: warning
    - alert: KubeMemOvercommit
      annotations:
        message: Cluster has overcommitted memory resource requests for Pods and cannot
          tolerate node failure.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubememovercommit
      expr: |
        sum(namespace_name:kube_pod_container_resource_requests_memory_bytes:sum)
          /
        sum(node_memory_MemTotal_bytes)
          >
        (count(node:node_num_cpu:sum)-1)
          /
        count(node:node_num_cpu:sum)
      for: 5m
      labels:
        severity: warning
    - alert: KubeCPUOvercommit
      annotations:
        message: Cluster has overcommitted CPU resource requests for Namespaces.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubecpuovercommit
      expr: |
        sum(kube_resourcequota{job="kube-state-metrics", type="hard", resource="requests.cpu"})
          /
        sum(node:node_num_cpu:sum)
          > 1.5
      for: 5m
      labels:
        severity: warning
    - alert: KubeMemOvercommit
      annotations:
        message: Cluster has overcommitted memory resource requests for Namespaces.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubememovercommit
      expr: |
        sum(kube_resourcequota{job="kube-state-metrics", type="hard", resource="requests.memory"})
          /
        sum(node_memory_MemTotal_bytes{job="node-exporter"})
          > 1.5
      for: 5m
      labels:
        severity: warning
    - alert: KubeQuotaExceeded
      annotations:
        message: Namespace {{ $labels.namespace }} is using {{ printf "%0.0f" $value
          }}% of its {{ $labels.resource }} quota.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubequotaexceeded
      expr: |
        100 * kube_resourcequota{job="kube-state-metrics", type="used"}
          / ignoring(instance, job, type)
        (kube_resourcequota{job="kube-state-metrics", type="hard"} > 0)
          > 90
      for: 15m
      labels:
        severity: warning
    - alert: CPUThrottlingHigh
      annotations:
        message: '{{ printf "%0.0f" $value }}% throttling of CPU in namespace {{ $labels.namespace
          }} for container {{ $labels.container_name }} in pod {{ $labels.pod_name
          }}.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-cputhrottlinghigh
      expr: "100 * sum(increase(container_cpu_cfs_throttled_periods_total{container_name!=\"\",
        }[5m])) by (container_name, pod_name, namespace)\n  /\nsum(increase(container_cpu_cfs_periods_total{}[5m]))
        by (container_name, pod_name, namespace)\n  > 25 \n"
      for: 15m
      labels:
        severity: warning
  - name: kubernetes-storage
    rules:
    - alert: KubePersistentVolumeUsageCritical
      annotations:
        message: The PersistentVolume claimed by {{ $labels.persistentvolumeclaim
          }} in Namespace {{ $labels.namespace }} is only {{ printf "%0.2f" $value
          }}% free.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepersistentvolumeusagecritical
      expr: |
        100 * kubelet_volume_stats_available_bytes{job="kubelet"}
          /
        kubelet_volume_stats_capacity_bytes{job="kubelet"}
          < 3
      for: 1m
      labels:
        severity: critical
    - alert: KubePersistentVolumeFullInFourDays
      annotations:
        message: Based on recent sampling, the PersistentVolume claimed by {{ $labels.persistentvolumeclaim
          }} in Namespace {{ $labels.namespace }} is expected to fill up within four
          days. Currently {{ printf "%0.2f" $value }}% is available.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepersistentvolumefullinfourdays
      expr: |
        100 * (
          kubelet_volume_stats_available_bytes{job="kubelet"}
            /
          kubelet_volume_stats_capacity_bytes{job="kubelet"}
        ) < 15
        and
        predict_linear(kubelet_volume_stats_available_bytes{job="kubelet"}[6h], 4 * 24 * 3600) < 0
      for: 5m
      labels:
        severity: critical
    - alert: KubePersistentVolumeErrors
      annotations:
        message: The persistent volume {{ $labels.persistentvolume }} has status {{
          $labels.phase }}.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepersistentvolumeerrors
      expr: |
        kube_persistentvolume_status_phase{phase=~"Failed|Pending",job="kube-state-metrics"} > 0
      for: 5m
      labels:
        severity: critical
  - name: kubernetes-system
    rules:
    - alert: KubeNodeNotReady
      annotations:
        message: '{{ $labels.node }} has been unready for more than an hour.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubenodenotready
      expr: |
        kube_node_status_condition{job="kube-state-metrics",condition="Ready",status="true"} == 0
      for: 1h
      labels:
        severity: warning
    - alert: KubeVersionMismatch
      annotations:
        message: There are {{ $value }} different semantic versions of Kubernetes
          components running.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeversionmismatch
      expr: |
        count(count by (gitVersion) (label_replace(kubernetes_build_info{job!="kube-dns"},"gitVersion","$1","gitVersion","(v[0-9]*.[0-9]*.[0-9]*).*"))) > 1
      for: 1h
      labels:
        severity: warning
    - alert: KubeClientErrors
      annotations:
        message: Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance
          }}' is experiencing {{ printf "%0.0f" $value }}% errors.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeclienterrors
      expr: |
        (sum(rate(rest_client_requests_total{code=~"5.."}[5m])) by (instance, job)
          /
        sum(rate(rest_client_requests_total[5m])) by (instance, job))
        * 100 > 1
      for: 15m
      labels:
        severity: warning
    - alert: KubeClientErrors
      annotations:
        message: Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance
          }}' is experiencing {{ printf "%0.0f" $value }} errors / second.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeclienterrors
      expr: |
        sum(rate(ksm_scrape_error_total{job="kube-state-metrics"}[5m])) by (instance, job) > 0.1
      for: 15m
      labels:
        severity: warning
    - alert: KubeletTooManyPods
      annotations:
        message: Kubelet {{ $labels.instance }} is running {{ $value }} Pods, close
          to the limit of 110.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubelettoomanypods
      expr: |
        kubelet_running_pod_count{job="kubelet"} > 110 * 0.9
      for: 15m
      labels:
        severity: warning
    - alert: KubeAPILatencyHigh
      annotations:
        message: The API server has a 99th percentile latency of {{ $value }} seconds
          for {{ $labels.verb }} {{ $labels.resource }}.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapilatencyhigh
      expr: |
        cluster_quantile:apiserver_request_latencies:histogram_quantile{job="apiserver",quantile="0.99",subresource!="log",verb!~"^(?:LIST|WATCH|WATCHLIST|PROXY|CONNECT)$"} > 1
      for: 10m
      labels:
        severity: warning
    - alert: KubeAPILatencyHigh
      annotations:
        message: The API server has a 99th percentile latency of {{ $value }} seconds
          for {{ $labels.verb }} {{ $labels.resource }}.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapilatencyhigh
      expr: |
        cluster_quantile:apiserver_request_latencies:histogram_quantile{job="apiserver",quantile="0.99",subresource!="log",verb!~"^(?:LIST|WATCH|WATCHLIST|PROXY|CONNECT)$"} > 4
      for: 10m
      labels:
        severity: critical
    - alert: KubeAPIErrorsHigh
      annotations:
        message: API server is returning errors for {{ $value }}% of requests.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapierrorshigh
      expr: |
        sum(rate(apiserver_request_count{job="apiserver",code=~"^(?:5..)$"}[5m])) without(instance, pod)
          /
        sum(rate(apiserver_request_count{job="apiserver"}[5m])) without(instance, pod) * 100 > 10
      for: 10m
      labels:
        severity: critical
    - alert: KubeAPIErrorsHigh
      annotations:
        message: API server is returning errors for {{ $value }}% of requests.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapierrorshigh
      expr: |
        sum(rate(apiserver_request_count{job="apiserver",code=~"^(?:5..)$"}[5m])) without(instance, pod)
          /
        sum(rate(apiserver_request_count{job="apiserver"}[5m])) without(instance, pod) * 100 > 5
      for: 10m
      labels:
        severity: warning
    - alert: KubeClientCertificateExpiration
      annotations:
        message: A client certificate used to authenticate to the apiserver is expiring
          in less than 7 days.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeclientcertificateexpiration
      expr: |
        histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{job="apiserver"}[5m]))) < 604800
      labels:
        severity: warning
    - alert: KubeClientCertificateExpiration
      annotations:
        message: A client certificate used to authenticate to the apiserver is expiring
          in less than 24 hours.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeclientcertificateexpiration
      expr: |
        histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{job="apiserver"}[5m]))) < 86400
      labels:
        severity: critical
  - name: alertmanager.rules
    rules:
    - alert: AlertmanagerConfigInconsistent
      annotations:
        message: The configuration of the instances of the Alertmanager cluster `{{$labels.service}}`
          are out of sync.
      expr: |
        count_values("config_hash", alertmanager_config_hash{job="alertmanager-main",namespace="monitoring"}) BY (service) / ON(service) GROUP_LEFT() label_replace(prometheus_operator_spec_replicas{job="prometheus-operator",namespace="monitoring",controller="alertmanager"}, "service", "alertmanager-$1", "name", "(.*)") != 1
      for: 5m
      labels:
        severity: critical
    - alert: AlertmanagerFailedReload
      annotations:
        message: Reloading Alertmanager's configuration has failed for {{ $labels.namespace
          }}/{{ $labels.pod}}.
      expr: |
        alertmanager_config_last_reload_successful{job="alertmanager-main",namespace="monitoring"} == 0
      for: 10m
      labels:
        severity: warning
    - alert: AlertmanagerMembersInconsistent
      annotations:
        message: Alertmanager has not found all other members of the cluster.
      expr: |
        alertmanager_cluster_members{job="alertmanager-main",namespace="monitoring"}
          != on (service) GROUP_LEFT()
        count by (service) (alertmanager_cluster_members{job="alertmanager-main",namespace="monitoring"})
      for: 5m
      labels:
        severity: critical
  - name: general.rules
    rules:
    - alert: TargetDown
      annotations:
        message: '{{ $value }}% of the {{ $labels.job }} targets are down.'
      expr: 100 * (count(up == 0) BY (job) / count(up) BY (job)) > 10
      for: 10m
      labels:
        severity: warning
    - alert: Watchdog
      annotations:
        message: |
          This is an alert meant to ensure that the entire alerting pipeline is functional.
          This alert is always firing, therefore it should always be firing in Alertmanager
          and always fire against a receiver. There are integrations with various notification
          mechanisms that send a notification when this alert is not firing. For example the
          "DeadMansSnitch" integration in PagerDuty.
      expr: vector(1)
      labels:
        severity: none
  - name: kube-prometheus-node-alerting.rules
    rules:
    - alert: NodeDiskRunningFull
      annotations:
        message: Device {{ $labels.device }} of node-exporter {{ $labels.namespace
          }}/{{ $labels.pod }} will be full within the next 24 hours.
      expr: |
        (node:node_filesystem_usage: > 0.85) and (predict_linear(node:node_filesystem_avail:[6h], 3600 * 24) < 0)
      for: 30m
      labels:
        severity: warning
    - alert: NodeDiskRunningFull
      annotations:
        message: Device {{ $labels.device }} of node-exporter {{ $labels.namespace
          }}/{{ $labels.pod }} will be full within the next 2 hours.
      expr: |
        (node:node_filesystem_usage: > 0.85) and (predict_linear(node:node_filesystem_avail:[30m], 3600 * 2) < 0)
      for: 10m
      labels:
        severity: critical
  - name: prometheus.rules
    rules:
    - alert: PrometheusConfigReloadFailed
      annotations:
        description: Reloading Prometheus' configuration has failed for {{$labels.namespace}}/{{$labels.pod}}
        summary: Reloading Prometheus' configuration failed
      expr: |
        prometheus_config_last_reload_successful{job="prometheus-k8s",namespace="monitoring"} == 0
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusNotificationQueueRunningFull
      annotations:
        description: Prometheus' alert notification queue is running full for {{$labels.namespace}}/{{
          $labels.pod}}
        summary: Prometheus' alert notification queue is running full
      expr: |
        predict_linear(prometheus_notifications_queue_length{job="prometheus-k8s",namespace="monitoring"}[5m], 60 * 30) > prometheus_notifications_queue_capacity{job="prometheus-k8s",namespace="monitoring"}
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusErrorSendingAlerts
      annotations:
        description: Errors while sending alerts from Prometheus {{$labels.namespace}}/{{
          $labels.pod}} to Alertmanager {{$labels.Alertmanager}}
        summary: Errors while sending alert from Prometheus
      expr: |
        rate(prometheus_notifications_errors_total{job="prometheus-k8s",namespace="monitoring"}[5m]) / rate(prometheus_notifications_sent_total{job="prometheus-k8s",namespace="monitoring"}[5m]) > 0.01
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusErrorSendingAlerts
      annotations:
        description: Errors while sending alerts from Prometheus {{$labels.namespace}}/{{
          $labels.pod}} to Alertmanager {{$labels.Alertmanager}}
        summary: Errors while sending alerts from Prometheus
      expr: |
        rate(prometheus_notifications_errors_total{job="prometheus-k8s",namespace="monitoring"}[5m]) / rate(prometheus_notifications_sent_total{job="prometheus-k8s",namespace="monitoring"}[5m]) > 0.03
      for: 10m
      labels:
        severity: critical
    - alert: PrometheusNotConnectedToAlertmanagers
      annotations:
        description: Prometheus {{ $labels.namespace }}/{{ $labels.pod}} is not connected
          to any Alertmanagers
        summary: Prometheus is not connected to any Alertmanagers
      expr: |
        prometheus_notifications_alertmanagers_discovered{job="prometheus-k8s",namespace="monitoring"} < 1
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusTSDBReloadsFailing
      annotations:
        description: '{{$labels.job}} at {{$labels.instance}} had {{$value | humanize}}
          reload failures over the last four hours.'
        summary: Prometheus has issues reloading data blocks from disk
      expr: |
        increase(prometheus_tsdb_reloads_failures_total{job="prometheus-k8s",namespace="monitoring"}[2h]) > 0
      for: 12h
      labels:
        severity: warning
    - alert: PrometheusTSDBCompactionsFailing
      annotations:
        description: '{{$labels.job}} at {{$labels.instance}} had {{$value | humanize}}
          compaction failures over the last four hours.'
        summary: Prometheus has issues compacting sample blocks
      expr: |
        increase(prometheus_tsdb_compactions_failed_total{job="prometheus-k8s",namespace="monitoring"}[2h]) > 0
      for: 12h
      labels:
        severity: warning
    - alert: PrometheusTSDBWALCorruptions
      annotations:
        description: '{{$labels.job}} at {{$labels.instance}} has a corrupted write-ahead
          log (WAL).'
        summary: Prometheus write-ahead log is corrupted
      expr: |
        tsdb_wal_corruptions_total{job="prometheus-k8s",namespace="monitoring"} > 0
      for: 4h
      labels:
        severity: warning
    - alert: PrometheusNotIngestingSamples
      annotations:
        description: Prometheus {{ $labels.namespace }}/{{ $labels.pod}} isn't ingesting
          samples.
        summary: Prometheus isn't ingesting samples
      expr: |
        rate(prometheus_tsdb_head_samples_appended_total{job="prometheus-k8s",namespace="monitoring"}[5m]) <= 0
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusTargetScrapesDuplicate
      annotations:
        description: '{{$labels.namespace}}/{{$labels.pod}} has many samples rejected
          due to duplicate timestamps but different values'
        summary: Prometheus has many samples rejected
      expr: |
        increase(prometheus_target_scrapes_sample_duplicate_timestamp_total{job="prometheus-k8s",namespace="monitoring"}[5m]) > 0
      for: 10m
      labels:
        severity: warning
  - name: prometheus-operator
    rules:
    - alert: PrometheusOperatorReconcileErrors
      annotations:
        message: Errors while reconciling {{ $labels.controller }} in {{ $labels.namespace
          }} Namespace.
      expr: |
        rate(prometheus_operator_reconcile_errors_total{job="prometheus-operator",namespace="monitoring"}[5m]) > 0.1
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusOperatorNodeLookupErrors
      annotations:
        message: Errors while reconciling Prometheus in {{ $labels.namespace }} Namespace.
      expr: |
        rate(prometheus_operator_node_address_lookup_errors_total{job="prometheus-operator",namespace="monitoring"}[5m]) > 0.1
      for: 10m
      labels:
        severity: warning
{%- endraw %}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-adapter
  namespace: monitoring
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-adapter
subjects:
- kind: ServiceAccount
  name: prometheus-adapter
  namespace: monitoring
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-adapter
  namespace: monitoring
---
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  labels:
    prometheus: k8s
  name: k8s
  namespace: monitoring
spec:
  alerting:
    alertmanagers:
    - name: alertmanager-main
      namespace: monitoring
      port: web
  baseImage: {{ build_image_name('prometheus') }}
  nodeSelector:
    beta.kubernetes.io/os: linux
  replicas: 2
  resources:
    requests:
      memory: 400Mi
  ruleSelector:
    matchLabels:
      prometheus: k8s
      role: alert-rules
  securityContext:
    fsGroup: 2000
    runAsNonRoot: true
    runAsUser: 1000
  serviceAccountName: prometheus-k8s
  serviceMonitorNamespaceSelector: {}
  serviceMonitorSelector: {}
  version: v2.5.0
---
apiVersion: rbac.authorization.k8s.io/v1
items:
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: prometheus-k8s
    namespace: default
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: prometheus-k8s
  subjects:
  - kind: ServiceAccount
    name: prometheus-k8s
    namespace: monitoring
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: prometheus-k8s
    namespace: kube-system
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: prometheus-k8s
  subjects:
  - kind: ServiceAccount
    name: prometheus-k8s
    namespace: monitoring
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: prometheus-k8s
    namespace: monitoring
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: prometheus-k8s
  subjects:
  - kind: ServiceAccount
    name: prometheus-k8s
    namespace: monitoring
kind: RoleBindingList
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: kube-controller-manager
  name: kube-controller-manager
  namespace: monitoring
spec:
  endpoints:
  - interval: 30s
    metricRelabelings:
    - action: drop
      regex: etcd_(debugging|disk|request|server).*
      sourceLabels:
      - __name__
    port: http-metrics
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      k8s-app: kube-controller-manager
---
apiVersion: rbac.authorization.k8s.io/v1
items:
- apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: prometheus-k8s
    namespace: default
  rules:
  - apiGroups:
    - ""
    resources:
    - services
    - endpoints
    - pods
    verbs:
    - get
    - list
    - watch
- apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: prometheus-k8s
    namespace: kube-system
  rules:
  - apiGroups:
    - ""
    resources:
    - services
    - endpoints
    - pods
    verbs:
    - get
    - list
    - watch
- apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: prometheus-k8s
    namespace: monitoring
  rules:
  - apiGroups:
    - ""
    resources:
    - services
    - endpoints
    - pods
    verbs:
    - get
    - list
    - watch
kind: RoleList
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: prometheus-k8s-config
  namespace: monitoring
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-metrics-server-resources
rules:
- apiGroups:
  - metrics.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: coredns
  name: coredns
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    interval: 15s
    port: metrics
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      k8s-app: kube-dns
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-k8s
  namespace: monitoring
---
apiVersion: v1
kind: Service
metadata:
  labels:
    name: prometheus-adapter
  name: prometheus-adapter
  namespace: monitoring
spec:
  ports:
  - name: https
    port: 443
    targetPort: 6443
  selector:
    name: prometheus-adapter
---
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: prometheus-adapter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      name: prometheus-adapter
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        name: prometheus-adapter
    spec:
      containers:
      - args:
        - --cert-dir=/var/run/serving-cert
        - --config=/etc/adapter/config.yaml
        - --logtostderr=true
        - --metrics-relist-interval=1m
        - --prometheus-url=http://prometheus-k8s.monitoring.svc:9090/
        - --secure-port=6443
        image: {{ build_image_name('k8s-prometheus-adapter-amd64', 'v0.4.1') }}
        name: prometheus-adapter
        ports:
        - containerPort: 6443
        volumeMounts:
        - mountPath: /tmp
          name: tmpfs
          readOnly: false
        - mountPath: /var/run/serving-cert
          name: volume-serving-cert
          readOnly: false
        - mountPath: /etc/adapter
          name: config
          readOnly: false
      nodeSelector:
        beta.kubernetes.io/os: linux
      serviceAccountName: prometheus-adapter
      volumes:
      - emptyDir: {}
        name: tmpfs
      - emptyDir: {}
        name: volume-serving-cert
      - configMap:
          name: adapter-config
        name: config
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: prometheus-k8s-config
  namespace: monitoring
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: prometheus-k8s-config
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: monitoring
---
apiVersion: v1
kind: Service
metadata:
  labels:
    prometheus: k8s
  name: prometheus-k8s
  namespace: monitoring
spec:
  ports:
  - name: web
    port: 9090
    targetPort: web
  selector:
    app: prometheus
    prometheus: k8s
  sessionAffinity: ClientIP
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: resource-metrics-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: prometheus-adapter
  namespace: monitoring
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: kubelet
  name: kubelet
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    honorLabels: true
    interval: 30s
    port: https-metrics
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    honorLabels: true
    interval: 30s
    metricRelabelings:
    - action: drop
      regex: container_([a-z_]+);
      sourceLabels:
      - __name__
      - image
    - action: drop
      regex: container_(network_tcp_usage_total|network_udp_usage_total|tasks_state|cpu_load_average_10s)
      sourceLabels:
      - __name__
    path: /metrics/cadvisor
    port: https-metrics
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      k8s-app: kubelet
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: apiserver
  name: kube-apiserver
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    interval: 30s
    metricRelabelings:
    - action: drop
      regex: etcd_(debugging|disk|request|server).*
      sourceLabels:
      - __name__
    - action: drop
      regex: apiserver_admission_controller_admission_latencies_seconds_.*
      sourceLabels:
      - __name__
    - action: drop
      regex: apiserver_admission_step_admission_latencies_seconds_.*
      sourceLabels:
      - __name__
    port: https
    scheme: https
    tlsConfig:
      caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      serverName: kubernetes
  jobLabel: component
  namespaceSelector:
    matchNames:
    - default
  selector:
    matchLabels:
      component: apiserver
      provider: kubernetes
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: kube-scheduler
  name: kube-scheduler
  namespace: monitoring
spec:
  endpoints:
  - interval: 30s
    port: http-metrics
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      k8s-app: kube-scheduler
