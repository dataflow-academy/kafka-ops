# Multi-cluster: MirrorMaker 2 from the cluster of another group

Every group runs one region with its own cluster. MirrorMaker 2 runs in your cluster and pulls the telemetry and the
offsets of a consumer group from the cluster of a neighbor group, over the internet: the external listener (NodePort
31094) reports the public node addresses (k3s takes them as `InternalIP`), so the other group reaches every broker.

Start state (`prepare.sh`): your cluster and the wind park; the users and ACLs of the security lab are removed
(`security/reset.sh --keep-authorization`), authorization stays; no mirror.

| File | Purpose |
|---|---|
| `mirrormaker2.yaml` | The file the lab edits where it lives, starting as a copy of the frame (`reset.sh` restores it) |
| `mirrormaker2-frame.yaml` | `KafkaMirrorMaker2` with the connection to your own cluster; region names, the neighbor's address, patterns and offset sync are the participants' decisions. MirrorMaker 2 only reads at the neighbor's (`offset-syncs.topic.location: target`) |
| `mirrormaker2-solution.yaml` | An example for the region `nord` with the neighbor `sued`, plain and (commented) over TLS |
| `tls-listener.sh` | Rescue path of the extra task: adds the listener `externaltls` (NodePort 31194, TLS) to the Kafka cluster |
| `neighbor-ca.crt` | (created by `reset.sh`, not in git) where the neighbor's cluster CA certificate is pasted; `my-ca.crt` is your own one to send |

Over TLS the broker certificates do not contain the node addresses, so the mirror switches the host name check off
(`ssl.endpoint.identification.algorithm: ""`); the certificate chain is still checked against the neighbor's CA.

With ACLs on `telemetry` (a neighbor that has not run `prepare.sh`), anonymous reads through the external listener
are refused, and ACLs for `User:ANONYMOUS` added by hand are removed by the User Operator within two minutes.

`reset.sh` deletes the mirror, the topics it wrote (internal ones and `<alias>.*`) and the Secret with the neighbor's CA;
the listener `externaltls` stays.
