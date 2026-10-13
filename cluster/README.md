# Strimzi and the Kafka cluster

`prepare.sh` installs the pinned Strimzi release into the namespace `kafka` (the release's install file,
downloaded from the project's release page and checked against the sha256 in `versions.env`) and creates
the Kafka cluster `my-cluster` from `kafka.yaml`:

* KRaft, API `kafka.strimzi.io/v1`, `KafkaNodePool`s `controller` (ids 100-102) and `broker` (ids 0-2)
* one controller per node (`topologySpreadConstraints`), brokers spread by a *preferred* pod anti-affinity (a fourth broker still schedules), the node name is the broker's rack
* listeners `plain` 9092, `tls` 9093, `external` (NodePort 31094 for the bootstrap, 31095-31097 per broker)
* `min.insync.replicas=2`, replication factor 3; topic auto-creation stays at the Kafka default on purpose
* metrics via the JMX Prometheus Exporter (`metrics-config.yaml`), Kafka Exporter for consumer groups

`reset.sh` deletes the namespace, the Strimzi CRDs and the cluster-wide roles, including all data.
