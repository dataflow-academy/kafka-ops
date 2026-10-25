# Monitoring

Plain Prometheus (no Prometheus Operator), kube-state-metrics and Grafana as Deployments in the
namespace `kafka`. Prometheus finds its targets through the Kubernetes API with the same relabeling as the
example `PodMonitor`s of Strimzi, so the dashboards find the labels they expect. Grafana is provisioned with the
dashboards `strimzi-kafka`, `strimzi-kraft`, `strimzi-kafka-exporter` and `strimzi-operators` from the pinned Strimzi
release, 1.1.0 (`dashboards/`, with `${DS_PROMETHEUS}` already replaced by `prometheus`; do the same when you replace them from a newer release) and `wind-park.json`
(lag in seconds, restarts and failed jobs of the teams). Data lives in an `emptyDir`: a restart of Prometheus starts
from empty.

| Script | What it does |
|---|---|
| `metrics.sh` | switches on the JMX Prometheus Exporter and the Kafka Exporter in the Kafka cluster (rolling restart, once) |
| `install.sh` | Prometheus, kube-state-metrics, Grafana, Kafka UI (`../kafka-ui`, usually there since the first lab), without the scrape fault. The monitoring lab applies the same files with `kubectl apply -k .` and repairs the fault (lines marked `LAB-FAULT` in `prometheus.yaml`) |
| `prepare.sh` | all of the above (without the lab fault) plus the reference alerting rules |
| `reset.sh` | removes what `install.sh` created, except Kafka UI |

`rules.yml` holds the reference alerting rules, `rules-skeleton.yml` is the same file with the decisions left open
(`for`, `severity`, threshold). Prometheus loads every `*.yml` of the ConfigMap `prometheus-rules`.
