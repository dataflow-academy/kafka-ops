# Rebalance: adding a broker

Start state (`prepare.sh`): the cluster is Ready with three brokers and no Cruise Control, and the topic
`rebalance-demo` (12 partitions, replication factor 3, about 600 MB) gives Cruise Control something to move.

The lab itself (switch on Cruise Control, add a fourth broker to the node pool, `KafkaRebalance` in mode
`add-brokers`, approve with an annotation) needs no file from this folder.

`reset.sh` brings the cluster back to three brokers and no Cruise Control. A broker that carries replicas cannot
simply be scaled away: Strimzi reverts the scale-down. So `reset.sh` empties broker 3 with a `remove-brokers`
rebalance first (it switches Cruise Control on again if it is off, and has to wait for its first measurements).
