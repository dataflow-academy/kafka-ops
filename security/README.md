# Security: mTLS, simple authorization, one KafkaUser per team

Start state (`prepare.sh`): the cluster is open (plain listeners, no authorization), the wind park runs without faults.
If security is on, `reset.sh` runs first.

| File | Purpose |
|---|---|
| `examples/scada.yaml` | A finished `KafkaUser` (writes the telemetry topic), the pattern for the others |
| `solutions/` | The users of Control room, Billing, Forecast and Alerts |
| `connect-app.sh <deployment> <user>` | Copies the user's Secret and the cluster CA into the namespace `windpark` and sets the bootstrap address and six client settings on the Deployment |
| `probe.sh <user> produce\|consume <topic>`, `probe.sh <user> group <group>` | Tries one operation with the user's certificate from the kafka-tools pod (the `tls` listener is only reachable inside the cluster) (`group` describes a Consumer Group, which needs a right on the group), prints ALLOWED or DENIED |
| `reset.sh` | Deletes the users, switches authorization and the `tls` listener authentication off, restarts the applications without certificates (one rolling update) |

The `plain` listener has no authentication. Once authorization is on, everything that arrives there is the user
`ANONYMOUS` and has no ACL, so the whole wind park stops until the teams use the `tls` listener with a certificate.
That is the staged failure of the lab.
