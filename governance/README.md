# Governance

Material for the governance lab: rules the cluster enforces itself, and the package the participants take home.

    ./prepare.sh    # the state after "Helping the dev teams": faults F1, F2, F4, F5 repaired, F3 still there, topic auto-creation on, no policies
    ./reset.sh      # remove the policies and experiment resources, switch topic auto-creation back on (rolling restart if it was off)

| File | What it is |
|---|---|
| `policies/topic-naming.yaml` | `ValidatingAdmissionPolicy` for the naming convention, with two TODOs (the name Kafka will see, and the pattern) |
| `policies/topic-limits.yaml` | at least three replicas, at most 24 partitions, `min.insync.replicas` below the replication factor |
| `examples/` | KafkaTopic resources that the policies must accept or reject (`kubectl apply --dry-run=server -f`) |
| `quota-test.yaml` | a topic of its own for the quota measurement (never write test load into live topics) |
| `alerts-topic.yaml` | the topic team Alarme should have had (follows the convention, three replicas) |
| `migrate-alerts.sh` | copies the alerts of `windpark_alerts` into the new topic; a second run copies only what arrived since |
| `orphans.sh` | topics that exist in Kafka but have no `KafkaTopic` resource |
| `paket.md` | the governance package to fill in |

The policies skip a `KafkaTopic` that is being deleted: the topic operator removes its finalizer with an update, and a
policy that refuses it would leave the resource in `Terminating` for good. A policy needs a few seconds after it has
been created before it takes effect.

While the policies are active every `KafkaTopic` in the namespace `kafka` has to follow them. A script that creates
topics of its own (for example the faulty wind park with its topic `windpark_alerts`) is rejected; run `./reset.sh` first.
