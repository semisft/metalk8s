include:
  - metalk8s.kubernetes.kube-proxy.deployed
  - metalk8s.kubernetes.cni.calico.deployed
  - metalk8s.kubernetes.coredns.deployed
  - metalk8s.repo.deployed
  - metalk8s.salt.master.deployed
  - metalk8s.addons.ui.deployed
  - metalk8s.addons.monitoring.prometheus-operator.deployed
  - metalk8s.addons.monitoring.kube-controller-manager.exposed
  - metalk8s.addons.monitoring.kube-scheduler.exposed
  - metalk8s.addons.monitoring.alertmanager.deployed
  - metalk8s.addons.monitoring.prometheus.deployed
  - metalk8s.addons.monitoring.kube-state-metrics.deployed
  - metalk8s.addons.monitoring.node-exporter.deployed
  - metalk8s.addons.monitoring.grafana.deployed
