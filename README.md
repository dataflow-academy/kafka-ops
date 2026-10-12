# Apache Kafka for Operators: lab material

Manifests, scripts and pinned versions for the Kubernetes edition of the operators training:
a three-node [k3s](https://k3s.io) cluster running [Strimzi](https://strimzi.io), a KRaft Kafka cluster,
monitoring, and a wind park workload that is deliberately not perfect.

Every folder is one topic, self-contained, with a `prepare.sh` that creates a defined start state and a
`reset.sh` that cleans up. Both are idempotent. Run them on `node1` of the lab VMs.

| Folder | Start state after `prepare.sh` | Needs |
|---|---|---|
| [`k3s/`](k3s) | k3s v1.36 on three nodes (server on node1, agents on node2 and node3), kubeconfig for `user` | three VMs reaching each other with `ssh node1..3` |
| [`hello/`](hello) | k3s, the Strimzi operator and the small cluster `hello` with one message (first lab) | three VMs reaching each other with `ssh node1..3` |
| [`cluster/`](cluster) | Strimzi operator, Kafka cluster `my-cluster` Ready: 3 controllers and 3 brokers, one of each per node | `k3s/` |
| [`monitoring/`](monitoring) | Metrics switched on in the Kafka cluster (rolling restart), Prometheus, Grafana with the Strimzi dashboards, Kafka UI | `cluster/` |
| [`windpark/`](windpark) | the applications of six teams in the namespace `windpark`, with built-in faults (`./prepare.sh [as-requested\|healthy]`) | `cluster/` |
| [`workload/`](workload) | Topic, wind park producer and consumers (`./prepare.sh [overlay]`) | `cluster/` |
| [`perf/`](perf) | `./run.sh` runs one `kafka-producer-perf-test` as a Job | `cluster/` |

All versions are pinned in exactly one file: [`versions.env`](versions.env). Nothing else in the repository
contains a version number of Strimzi, Kafka, k3s, Prometheus, Grafana, Kafka UI or the workload images.
The rule is "current release minus one", so that the upgrade lab has a real step to take.

## Reaching things

| What | Where |
|---|---|
| Grafana | `http://<any node>:30300` (admin / admin) |
| Prometheus | `http://<any node>:30900` |
| Kafka UI | `http://<any node>:30800` |
| Kafka inside the cluster | `my-cluster-kafka-bootstrap.kafka.svc:9092` (plain), `:9093` (TLS) |
| Kafka from the VMs | `<node ip>:31094` (NodePort, plain); `cluster/prepare.sh` writes the address list to `~/.kafka-bootstrap-servers` |

## The wind park workload

Producer and consumer are the JSON applications of the training's template collection, run unchanged as
Kubernetes Deployments. Every knob is an environment variable that comes from a ConfigMap, so a scenario is a
patch, never a rebuild:

| Variable | Effect |
|---|---|
| `BOOTSTRAP_SERVERS`, `TOPIC`, `GROUP_ID` | where to connect, what to produce or consume |
| `TICK_INTERVAL_MS` | the 50 simulated turbines report once per tick: 1000 = 50 records/s, 100 = 500 records/s |
| `KAFKA_<NAME>` | any client config; `KAFKA_LINGER_MS=20` becomes `linger.ms=20`. Environment wins over the defaults in the code |
| `JAVA_OPTS` | JVM options such as `-XX:MaxRAMPercentage=70` |

Layout for "broken from the first deployment, fixed in later labs", using Kustomize:

* `workload/base` is the healthy wind park.
* `workload/components/<fault>` is one fault: a patch to a ConfigMap value, a resource limit, a topic setting. See `_template`.
* `workload/overlays/training` is the base plus the faults that participants meet first.
  Each later lab removes the fixed fault from its `components:` list (`overlays/after-<lab>`).
* `workload/overlays/healthy` is the reference without faults.

`./workload/prepare.sh training` converges the cluster to whatever the overlay lists, `./workload/reset.sh` removes it.

### Images

The images are pulled from a private registry, pinned by commit SHA in `versions.env`. Where the registry is
(`WIND_IMAGE_REGISTRY`) and the pull credentials come from the lab VM: `/etc/kafka-ops.env` names the registry,
`/etc/rancher/k3s/registries.yaml` holds the credentials and must exist before k3s is installed. Without access,
`STAGE_IMAGES_FROM=<sources> ./workload/prepare.sh` builds the same images on the node and imports them into k3s on
all nodes. That is a stopgap for testing.
