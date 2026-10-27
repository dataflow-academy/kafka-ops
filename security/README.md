# Security: mTLS, simple authorization, one KafkaUser per team

Start state (`prepare.sh`): the cluster is open (plain listeners, no authorization), the wind park runs without faults.
If security is on, `reset.sh` runs first.

| File | Purpose |
|---|---|
| `examples/scada.yaml`, `examples/forecast.yaml` | Finished `KafkaUser`s (SCADA writes the telemetry topic, Forecast reads it), the pattern for the others |
| `solutions/` | The users of Control room, Billing and Alerts |
| `copy-secrets.sh <user>` | Copies the user's Secret (as `kafka-user-<user>`) and the cluster CA (as `kafka-cluster-ca`) into the namespace `windpark` |
| `connect-app.sh <deployment> <user>` | `copy-secrets.sh`, then sets the bootstrap address and six client settings in the Deployment's env (the change the lab makes by hand for the control room) |
| `probe.sh <user> produce\|consume <topic>`, `probe.sh <user> group <group>` | Tries one operation with the user's certificate from the kafka-tools pod (the `tls` listener is only reachable inside the cluster) (`group` describes a Consumer Group, which needs a right on the group), prints ALLOWED or DENIED |
| `reset.sh` | Deletes the users, switches authorization, `allow.everyone.if.no.acl.found` and the `tls` listener authentication off, restarts the applications without certificates (one rolling update) |
| `reset.sh --keep-authorization` | For the labs after this one: deletes the users (and so every ACL) and the Secret copies, puts the applications back on the plain listener; authorization stays, with `allow.everyone.if.no.acl.found=true` (set again if it is missing, one rolling update) |

The lab switches authorization on with `allow.everyone.if.no.acl.found: true`. As long as no ACL names a resource,
everyone may use it, also the user `ANONYMOUS` that every client on the `plain` listener is. The first `KafkaUser`s
put ACLs on the telemetry topic and the groups: from then on only the users named there may use them, and the
applications that still come in without a certificate are denied. That is the staged failure of the lab. Topics
without ACLs (Alerts, Assets) keep working, so a group that does not finish leaves the following labs a usable cluster.
