# Failures

Material for the lab "Ops goes wrong". The participant path uses deterministic numbered
entry points, each with a "Finger weg!" warning. Participants diagnose the live cluster,
not the scripts or `chaos-state`. The BOFH chats ask for observations and hypotheses,
give at most one small hint at a time, and never repair anything.

* `bad-things1.sh`: missing broker (P1); the BOFH helps with the tools from M1–M4.
* `bad-things1b.sh`: a second broker goes (P1b), run by the BOFH of incident 1 once the group found the first one; it
  refuses while the operator runs, because the operator would bring the broker back at once.
* `bad-things2.sh`: full broker volume (P4), the unknown incident; the cause is not announced in the lab.
* The node failure, the controller quorum and the other extras of the lab are done by hand.

Every entry point touches its marker `~/.bad-things<N>-started` (the self-checks and the BOFH look for it);
`bad-things1.sh` and `bad-things2.sh` before the failure starts, `bad-things1b.sh` after it succeeded.
`heal.sh` undoes them all. Do not stack incidents: recover and verify the cluster before starting the next one.

    ./prepare.sh    # cluster, monitoring and wind park running, no failure active, topic windpark_alerts on the broker of node3
    ./reset.sh      # heal.sh, delete the experiment topics, the markers and ~/.chaos-started

| File | What it does |
|---|---|
| `topics.yaml` | three experiment topics `chaos-acks-all`, `chaos-acks-1`, `chaos-acks-0`: three replicas, one partition, broker defaults |
| `../tools/verifiable-producer.py` | the producers of the lab, on the host: numbered records, one table row per acknowledgment, one line per failure (`--acks all\|1\|0`) |
| `place-alerts.sh` | put the topic `windpark_alerts` (fault F3, one replica) on the broker of node3 |
| `break.sh P1\|P1b\|P4` | cause one failure and say nothing about which broker it hit; creates `~/.chaos-started` |
| `heal.sh` | undo every failure, wait until the cluster is healthy: Kafka Ready, pods ready, nodes Ready, no under-replicated partitions |
| `check.sh` | is the cluster healthy (nodes, operator, pods, no under-replicated or unavailable partitions, a new `KafkaTopic` becomes Ready) |
| `rescue-pod.yaml` | a pod that mounts the data volume of a broker that cannot start |

| | Failure | Symptom |
|---|---|---|
| P1 | operator scaled to 0, then a broker pod deleted | broker stays away, under-replicated partitions |
| P1b | while P1 is active, one more running broker pod deleted | one broker left: producers with `acks=all` are rejected (`min.insync.replicas` 2), `acks=1` and `acks=0` keep writing |
| P4 | volume of a broker full (a "heap dump" fills it) | broker in `CrashLoopBackOff`, `No space left on device` |

`break.sh` needs neither ssh nor sudo: it works through short-lived privileged pods. It prints progress
(`step 1/4` ...) while it prepares P4, which copies the data of the broker into a loop file system, and ends as soon
as the volume is full and the operator is back. `heal.sh` needs `ssh $IP.N` and `sudo` once (a stopped k3s agent can
only be started on the node).

The scripts do not depend on the design the group chose, except for the numbers it asks for: three or more brokers
(the experiment topics have three replicas), an odd number of at least three controllers, and the
`strimzi.io/pool-name` labels `broker` and `controller` of the design skeleton. `check.sh` counts the pods the node pools ask for.
The node failure and the topic of team Alerts need one broker and one controller per node; with the reference design
(`cluster/prepare.sh`) that is the case, a design without spreading may break it.
