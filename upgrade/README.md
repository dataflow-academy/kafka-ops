# Upgrade: operator, Kafka, metadata version

The labs start with Strimzi 1.1.0 and Kafka 4.2.1 (`metadataVersion` 4.2-IV1). The upgrade lab goes to Strimzi 1.2.0,
Kafka 4.3.1 and `metadataVersion` 4.3-IV0, so there is a real step to take: a new Strimzi minor version, a new Kafka
minor version, and a `metadataVersion` raise. The participants type these versions themselves; they are written in
the lab text and nowhere else.

| File | Purpose |
|---|---|
| `operator.sh [version]` | Wrapper around `../cluster/operator.sh [version]`, which installs a Strimzi release the way the Strimzi documentation does (download, sha256, namespace, apply) and does not touch the `Kafka` resource. Default: 1.2.0 |
| `prepare.sh` | Start state: cluster at the install versions with monitoring and wind park. A cluster that was upgraded is rebuilt from `../cluster/kafka.yaml` (Strimzi does not roll a raised metadata version back) and `~/nordwind-kafka.yaml` becomes that cluster's file again (the old one is kept as `~/nordwind-kafka.yaml.bak`). A cluster at the install versions with authorization from the security lab gets `../security/reset.sh --keep-authorization` first (users and ACLs go, the wind park returns to the plain listener) |
| `reset.sh` | The same rebuild, unconditionally; destroys all data |
