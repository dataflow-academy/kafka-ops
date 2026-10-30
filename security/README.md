# Security: mTLS, simple authorization, one KafkaUser per team

Start state (`prepare.sh`): the cluster is open (plain listeners, no authorization), the wind park runs without faults.
If security is on, `reset.sh` runs first.

| File | Purpose |
|---|---|
| `examples/scada.yaml`, `examples/forecast.yaml` | Finished `KafkaUser`s (SCADA writes the telemetry topic, Forecast reads it), the pattern for the others |
| `solutions/` | The users of Control room, Billing and Alerts |
| `copy-secrets.sh <user>` | Copies the user's Secret (as `kafka-user-<user>`) and the cluster CA (as `kafka-cluster-ca`) into the namespace `windpark` |
| `connect-app.sh <deployment> <user>` | Creates the `KafkaUser` without ACLs if it is missing, `copy-secrets.sh`, then sets the bootstrap address and six client settings in the Deployment's env (the change the lab makes by hand for the control room) |
| `examples/kafka-ui.yaml`, `connect-kafka-ui.sh` | The user of Kafka UI (no ACLs, a super user in the `Kafka` resource); moves Kafka UI to the `tls` listener |
| `connect-remaining.sh` | Alerts, Assets and Maintenance: `KafkaUser` without ACLs, certificates, tls listener. Assets has librdkafka settings, Alerts and the Maintenance CronJob write a properties file for the console producer |
| `examples/platform.yaml`, `cli-config.sh` | The user of the platform team (SCRAM, a super user) and the settings file for the Kafka tools on the host |
| `probe.sh <user> produce\|consume <topic>`, `probe.sh <user> group <group>` | Tries one operation with the user's certificate from the kafka-tools pod (the `tls` listener is only reachable inside the cluster) (`group` describes a Consumer Group, which needs a right on the group), prints ALLOWED or DENIED |
| `reset.sh` | Deletes the users, switches authorization, `allow.everyone.if.no.acl.found` and the `tls` listener authentication off, restarts the applications and Kafka UI without certificates (one rolling update) |
| `reset.sh --keep-authorization` | For the other labs, when security is on: deletes the users (and so every ACL) and the Secret copies, puts the applications and Kafka UI back on the plain listener; authorization stays, with `allow.everyone.if.no.acl.found=true` (set again if it is missing, one rolling update) |

The lab switches authorization on with `allow.everyone.if.no.acl.found: true`. That setting is decided per resource, not
per user: as long as no ACL names a resource everyone may use it, with a certificate or as the user `ANONYMOUS` that every
client on the `plain` listener is. Once one ACL names it, only the users named there may use it. So the lab goes in two steps:
first every application gets a `KafkaUser` without ACLs and connects with its certificate, then the ACLs follow. While the
User Operator writes them user by user, an application may be denied for a moment and restart once. What is left without an
ACL on the telemetry topic is denied: Maintenance and the Kafka tools on the host. Alerts and Assets keep working, no ACL
names their topics. Kafka UI is a super user (`CN=kafka-ui`); an ACL on the topic `*` would name every topic and shut out
everyone else.

When every client is on TLS, the lab removes the listener `plain` and puts `external` on TLS with SCRAM. The Kafka tools on the
host then need `cli-config.sh`: the user `platform` (a super user) and `platform.properties`. `reset.sh` brings the plaintext
listeners back, in the cluster and in `cluster/nordwind-kafka.yaml`.
