# Security: mTLS, simple authorization, one KafkaUser per team

Start state (`prepare.sh`): the cluster is open (plain listeners, no authorization), the wind park runs without faults.
If security is on, `reset.sh` runs first.

| File | Purpose |
|---|---|
| `examples/scada.yaml` | A finished `KafkaUser` (writes the telemetry topic), the pattern for the others |
| `solutions/` | The users of Leitwarte, Abrechnung, Prognose and Alarme |
| `connect-app.sh <deployment> <user>` | Copies the user's Secret and the cluster CA into the namespace `windpark` and sets the six client settings on the Deployment |
| `probe.sh <user> produce\|consume <topic>` | Tries one operation with the user's certificate from a broker pod, prints ALLOWED or DENIED |
| `reset.sh` | Deletes the users, switches authorization and the `tls` listener authentication off, restarts the applications without certificates (one rolling update) |

The `plain` listener has no authentication. Once authorization is on, everything that arrives there is the user
`ANONYMOUS` and has no ACL, so the whole wind park stops until the teams use the `tls` listener with a certificate.
That is the staged failure of the lab.
