# Upgrade: operator, Kafka, metadata version

The install versions and the upgrade target are both in `../versions.env` (`STRIMZI_UPGRADE_VERSION`,
`KAFKA_UPGRADE_VERSION`, `KAFKA_UPGRADE_METADATA_VERSION`). Install is current minus one, so the lab has a real
step to take: a new Strimzi minor version, a new Kafka minor version, and a `metadataVersion` raise.

| File | Purpose |
|---|---|
| `operator.sh [version]` | Wrapper around `../cluster/operator.sh [version]`, which installs a Strimzi release the way the Strimzi documentation does (download, sha256 from `versions.env`, namespace, apply) and does not touch the `Kafka` resource. Default: the upgrade version |
| `prepare.sh` | Start state: cluster at the install versions with monitoring and wind park. A cluster that was upgraded is rebuilt (Strimzi does not roll a raised metadata version back). A cluster at the install versions that still has authorization switched on gets `../security/reset.sh` first |
| `reset.sh` | The same rebuild, unconditionally; destroys all data |
