# Change data capture with Debezium

Start state: the Kafka cluster `nordwind-kafka` is open and Ready, the registry from [`connect/`](../connect) runs in the
cluster and every node can pull from it, the SCADA database runs in the namespace `scada`, the feed writes to it, and the
two topics for its tables exist. No Debezium Connect, no connector. The lab gets there by applying
`connect/registry.yaml`, `postgres.yaml` and `topics.yaml` itself; `prepare.sh` does the same in one step (rescue path,
also removes leftovers). `prepare.sh running` adds Kafka Connect with the Debezium plugin and the running connector.

| File | Purpose |
|---|---|
| `postgres.yaml` | Namespace `scada`; PostgreSQL 17 with `wal_level=logical`, tables `turbines` (30 rows) and `readings`, a role `debezium` with `REPLICATION` and `SELECT` only, the publication `nordwind_cdc` for exactly these two tables; `scada-feed` updates all readings ten times per second |
| `topics.yaml` | `nordwind.scada.private.turbines.state` and `nordwind.scada.private.readings.state`, compacted, three replicas |
| `connect.yaml`, `connector.yaml` | The files the lab edits and applies, where they live; `reset.sh` restores them from the frames |
| `connect-frame.yaml`, `connector-frame.yaml` | The pristine frames of those two files |
| `connect-solution.yaml` | The solution: `KafkaConnect` `debezium` with the Debezium PostgreSQL connector 3.6.3.Final pinned by sha512 |
| `slot.sql` | The replication slot and how much WAL it holds back; `kubectl exec -i -n scada deploy/scada-db -- psql -U scada < slot.sql` |

## Decisions

* **A Connect cluster of its own** (`debezium`) instead of a second plugin in the Connect lab's cluster: the lab works
  whether or not the Connect lab ran or was cleaned up, a rebuild for Debezium does not restart other connectors, and
  the connector does not share a JVM with others. The build is the one of the Connect lab: buildah with the AppArmor
  profile `Unconfined` for the build container, push without TLS to `registry.registry.svc:5000`, pull through the
  containerd mirror on every node.
* **The DBA side in the database**: the publication is created in `init.sql`, the connector runs with
  `publication.autocreate.mode: disabled`, so the role `debezium` needs neither superuser nor ownership.
* **Topic names follow the Nordwind convention**: Debezium writes `<topic.prefix>.<schema>.<table>`; a `RegexRouter`
  in the connector renames `nordwind.scada.cdc.public.<table>` to `nordwind.scada.private.<table>.state`, the names
  of the `KafkaTopic` resources in `topics.yaml`.
* **`offset.flush.interval.ms: 10000`** in Connect: Debezium confirms its position to the slot only when Connect stores
  the offsets. With the default of one minute the slot would hold back up to a minute of WAL while everything runs.
* **`errors.max.retries: -1`** is written into the connector explicitly: it is Debezium's default, the lab shows that
  the task then stays `RUNNING` while it cannot connect, and changes it to `3`.

Measured on the lab VMs (cpx42, PostgreSQL 17, Debezium 3.6.3.Final on Kafka Connect 4.2.1): the build takes about
30 seconds, `KafkaConnect` is Ready after about 90 seconds; the feed writes about 30 kB of WAL per second, so a stopped
connector makes the slot hold back about 1.8 MB per minute (100 MB per hour). After the restart the slot is released
within about 30 seconds. A failed task restarted with `strimzi.io/restart-task` runs again after the next
reconciliation (seconds up to two minutes).

`reset.sh` removes the connector, the Connect cluster, the namespace `scada` (and with it the slot), the topics including
Connect's internal ones, and the registry unless the Connect lab's cluster still uses it.
