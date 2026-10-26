# ZooKeeper to KRaft migration

Old versions on purpose: Strimzi 0.45.1 (the last release with ZooKeeper and the migration) and Kafka 3.9.1; the
checksum of the release file is in `../cluster/operator.sh`. Participants walk the procedure of the
Strimzi documentation: adopt node pools, add a controller pool, `strimzi.io/kraft=migration`, wait for
`KRaftPostMigration`, `strimzi.io/kraft=enabled` (the point of no return), remove `spec.zookeeper`.

| File | Purpose |
|---|---|
| `prepare.sh` | Removes the current cluster (and the CRDs of the newer Strimzi, the Kafka UI and the monitoring go with the namespace), installs the old operator, creates the ZooKeeper cluster `zk-cluster.yaml` (three ZooKeeper nodes, three brokers, no node pools) and the producer of `load.yaml` (50 records per second). The wind park cannot run on the old operator. |
| `reset.sh` | Back to the stack of the other labs: removes everything above, then runs `cluster/prepare.sh`, `monitoring/prepare.sh`, `windpark/prepare.sh healthy`; `~/nordwind-kafka.yaml` becomes the file of that cluster again (the old one is kept as `.bak`). |
| `solutions/` | The two node pools and the cleaned-up `Kafka` resource (`kraft-cluster.yaml`) |

The operator gets a larger memory limit than its install file sets: with node pools and the migration at 256 Mi it is
killed (OOMKilled).
