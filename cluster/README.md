# Strimzi and the Kafka cluster

`prepare.sh` installs Strimzi 1.1.0 into the namespace `kafka` (the release's install file,
downloaded from the project's release page by `operator.sh`, version and sha256 written there) and creates
the Kafka cluster `nordwind-kafka` from `kafka.yaml`:

* Kafka 4.2.1 (`version` and `metadataVersion` written in `kafka.yaml`), KRaft, API `kafka.strimzi.io/v1`, `KafkaNodePool`s `controller` (ids 100-102) and `broker` (ids 0-2)
* one controller per node (a *required* pod anti-affinity), brokers spread by a *preferred* pod anti-affinity (a fourth broker still schedules), the node name is the broker's rack. `skeleton.yaml`, the start of the design lab, leaves out all of this on purpose (and TLS, resources, JVM options, `metadataVersion`): the lab adds the spreading as an extra task, later labs add the rest
* listeners `plain` 9092, `tls` 9093, `external` (NodePort 31094 for the bootstrap, 31095-31097 per broker)
* `min.insync.replicas=2`, replication factor 3; topic auto-creation stays at the Kafka default on purpose
* no metrics yet: `monitoring/prepare.sh` switches on the JMX Prometheus Exporter and the Kafka Exporter (a rolling restart)

`reset.sh` deletes the namespace, the Strimzi CRDs and the cluster-wide roles, including all data.
