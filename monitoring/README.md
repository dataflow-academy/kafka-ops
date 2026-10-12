# Monitoring

Plain Prometheus (no Prometheus Operator), kube-state-metrics, Grafana and Kafka UI as Deployments in the
namespace `kafka`. Prometheus finds its targets through the Kubernetes API with the same relabeling as the
example `PodMonitor`s of Strimzi, so the dashboards find the labels they expect. Grafana is provisioned with the
dashboards `strimzi-kafka`, `strimzi-kraft`, `strimzi-kafka-exporter` and `strimzi-operators` from the pinned Strimzi
release (`dashboards/`; replace them from the same release when `STRIMZI_VERSION` changes) and `wind-park.json`
(lag in seconds, restarts and failed jobs of the teams). Data lives in an `emptyDir`: a restart of Prometheus starts
from empty.

| Script | What it does |
|---|---|
| `metrics.sh` | switches on the JMX Prometheus Exporter and the Kafka Exporter in the Kafka cluster (rolling restart, once) |
| `install.sh [--lab]` | Prometheus, kube-state-metrics, Grafana, Kafka UI. `--lab` leaves one scrape target out, as the monitoring lab starts |
| `prepare.sh` | all of the above (without the lab fault) plus the reference alerting rules |
| `reset.sh` | removes what `install.sh` created |

`rules.yml` holds the reference alerting rules, `rules-skeleton.yml` is the same file with the decisions left open
(`for`, `severity`, threshold). Prometheus loads every `*.yml` of the ConfigMap `prometheus-rules`.
