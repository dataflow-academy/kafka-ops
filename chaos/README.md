# Failures

Material for the lab "Ops goes wrong": six failures of the platform, a script that causes one of them at random,
and a script that undoes all of them.

    ./prepare.sh    # cluster, monitoring and wind park running, no failure active, topic windpark_alerts on the broker of node3
    ./reset.sh      # heal.sh, delete the experiment topics and ~/.chaos-started

| File | What it does |
|---|---|
| `topics.yaml` | three experiment topics with TODOs the group fills in |
| `start-producers.sh` | the three experiment producers in one terminal (`ACKS_TELEMETRY`, `ACKS_BILLING`, `ACKS_ALERTS`), logs in `~/telemetry.log` and friends |
| `produce.sh`, `count.sh` | one producer, and counting what was acknowledged and what is stored |
| `place-alerts.sh` | put the topic `windpark_alerts` (fault F3, one replica) on the broker of node3 |
| `break.sh [P1..P6]` | cause one failure and say nothing about which (without argument one of P4..P6 at random; P1..P3 only by name); creates `~/.chaos-started` |
| `heal.sh` | undo every failure, wait until the cluster is healthy: Kafka Ready, pods ready, nodes Ready, no under-replicated partitions |

| | Failure | Symptom |
|---|---|---|
| P1 | operator scaled to 0, then a broker pod deleted | broker stays away, under-replicated partitions |
| P2 | `k3s-agent` of a node stopped, its containers killed | node `NotReady`, pods `Terminating`, offline partitions |
| P3 | two of three controllers gone | produce keeps working, creating a topic hangs |
| P4 | volume of a broker full (a "heap dump" fills it) | broker in `CrashLoopBackOff`, `No space left on device` |
| P5 | the replication port of a node is dropped by iptables | ISR shrinks, under-replicated partitions |
| P6 | operator and topic operator watch the wrong namespace | a new `KafkaTopic` never gets a status |

`break.sh` needs neither ssh nor sudo: it works through short-lived privileged pods. `heal.sh` needs `ssh nodeN`
and `sudo` once (a stopped k3s agent can only be started on the node); it asks for the sudo password if needed.
