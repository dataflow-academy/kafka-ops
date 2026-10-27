# Rebalance: adding a broker

Start state (`prepare.sh`): the cluster is Ready with three brokers, no Cruise Control and no topic
`nordwind.platform.private.rebalance-demo.event`. It also applies `../monitoring` (if Grafana runs), so that the
dashboard "Strimzi Cruise Control" and the ConfigMap `cruise-control-metrics` are there.

The lab needs no file from this folder. It switches on Cruise Control (with `metricsConfig`) and the rack in the
`Kafka` resource first, because Cruise Control needs a few minutes of measurements before it can propose anything.
Then it creates the load from the VM with the Kafka command line tools: a topic with replication factor 2 whose
replicas are all on the brokers 0 and 1 (`kafka-topics.sh --replica-assignment`; a `KafkaTopic` cannot pin replicas to
brokers), filled with about 600 MB by `kafka-producer-perf-test.sh`. A `KafkaRebalance` in mode `full` moves part of
it onto broker 2, then a fourth broker joins the node pool and a `KafkaRebalance` in mode `add-brokers` moves load
onto it. The participants write `full.yaml` and `add-broker.yaml` into this folder themselves.

`reset.sh` brings the cluster back to three brokers and no Cruise Control, and deletes the demo topic. A broker that
carries replicas cannot simply be scaled away: Strimzi reverts the scale-down. So `reset.sh` empties broker 3 with a
`remove-brokers` rebalance first (it switches Cruise Control on again if it is off, and has to wait for its first
measurements). It waits until the operator has processed each change (`status.observedGeneration`), not just for a
`Ready` that may belong to the previous generation, and it empties every broker with an id above 2.
