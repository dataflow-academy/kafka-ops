# Multi-cluster: a second cluster and MirrorMaker 2

Start state (`prepare.sh`): only the first cluster, open, the wind park without faults. No second cluster.

| File | Purpose |
|---|---|
| `watch-namespace.sh` | Lets the Strimzi operator watch the namespace `kafka-dr` as well (`STRIMZI_NAMESPACE` plus the operator's role bindings there) |
| `target-cluster.yaml` | The second cluster `dr-cluster` in `kafka-dr`: three nodes with both roles, NodePort listener 31194 for the self-checks |
| `mirrormaker2-frame.yaml` | `KafkaMirrorMaker2` with the connections only; topics, groups, naming policy and offset translation are the participants' decisions |
| `mirrormaker2.yaml` | The solution: active/passive, `IdentityReplicationPolicy`, `sync.group.offsets.enabled` |

The "disaster" is the operator scaled to 0 and the pods of the first cluster deleted; their volumes stay. `reset.sh`
brings the operator back, deletes the mirror and the second cluster, restores `STRIMZI_NAMESPACE` and puts the wind
park back on the first cluster.
