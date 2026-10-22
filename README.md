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
| [`windpark/`](windpark) | the applications of six teams in the namespace `windpark`, with built-in faults (`./prepare.sh [as-requested\|healthy]`) | `cluster/` |
| [`monitoring/`](monitoring) | Metrics switched on in the Kafka cluster (rolling restart), Prometheus, Grafana with the Strimzi dashboards, Kafka UI | `cluster/` |
| [`tools/`](tools) | The Pod `kafka-tools` with the Kafka command line tools, used from the second lab on | `cluster/` |
| [`chaos/`](chaos) | Six failures of the platform, a script that causes one at random and one that heals all of them | `cluster/`, `monitoring/`, `windpark/` |
| [`governance/`](governance) | The state after the wind park repairs, topic auto-creation on, no policies; material for the naming and limit policies | `cluster/`, `windpark/` |
| [`storage/`](storage) | Cluster, monitoring and wind park running, no experiment topics; retention and compaction experiments | `cluster/`, `windpark/` |
| [`rebalance/`](rebalance) | Three brokers, no Cruise Control, topic `nordwind.platform.private.rebalance-demo.event` with about 600 MB | `cluster/` |
| [`security/`](security) | Open cluster, wind park without faults; `KafkaUser` examples, mTLS and authorization | `cluster/`, `windpark/` |
| [`dr/`](dr) | Only the first cluster; the second cluster `dr-cluster` in `kafka-dr` and MirrorMaker 2 are built in the lab | `cluster/`, `windpark/` |
| [`upgrade/`](upgrade) | Cluster at the install versions with monitoring and wind park; a changed cluster is rebuilt | `k3s/` |
| [`zk-migration/`](zk-migration) | Strimzi 0.45 and a ZooKeeper-based cluster with load; `reset.sh` restores the modern stack | `k3s/` |
| [`perf/`](perf) | `./run.sh` runs one `kafka-producer-perf-test` as a Job on a topic named by the convention | `cluster/` |

All versions are pinned in exactly one file: [`versions.env`](versions.env). Nothing else in the repository
contains a version number of Strimzi, Kafka, k3s, Prometheus, Grafana or Kafka UI. (The wind park manifests are plain files
that name their images and the Kafka image literally.)
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

Producer and consumer are the JSON applications of the Nordwind wind park, run unchanged as
Kubernetes Deployments. Every knob is an environment variable that comes from a ConfigMap, so a scenario is a
patch, never a rebuild:

| Variable | Effect |
|---|---|
| `BOOTSTRAP_SERVERS`, `TOPIC`, `GROUP_ID` | where to connect, what to produce or consume |
| `TICK_INTERVAL_MS` | the 50 simulated turbines report once per tick: 1000 = 50 records/s, 100 = 500 records/s |
| `KAFKA_<NAME>` | any client config; `KAFKA_LINGER_MS=20` becomes `linger.ms=20`. Environment wins over the defaults in the code |
| `JAVA_OPTS` | JVM options such as `-XX:MaxRAMPercentage=70` |

The wind park is two plain manifests in [`windpark/`](windpark): `windpark.yaml` is the state the participants meet
(with built-in faults), `windpark-healthy.yaml` is the same without the faults. They are applied with
`kubectl apply -f`.

### Images

The images are public (`ghcr.io/dataflow-academy/...`) and pinned by commit SHA in the manifests. The nodes need
no pull credentials.
