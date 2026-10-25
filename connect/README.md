# Kafka Connect with an image built by Strimzi

Start state: the Kafka cluster `nordwind-kafka` is open and Ready, a registry runs in the cluster (namespace `registry`),
every node can pull from it, a PostgreSQL database (`wartung-db`, table `work_orders`, eight rows) and the topic
`nordwind.maintenance.private.work-orders.state` exist. No Kafka Connect, no connectors. The lab gets there by applying
`registry.yaml`, `postgres.yaml` and `topic.yaml` itself; `prepare.sh` does the same in one step (rescue path, also removes
leftovers) and works on the reference cluster as well as on the participants' own, smaller one (plain listener on 9092,
three brokers).

| File | Purpose |
|---|---|
| `registry.yaml` | `registry:2` with an `emptyDir`, service `registry.registry.svc:5000`, NodePort 30500 |
| `registry-mirror.sh` | Tries a real pull on every node and adds the containerd mirror for `registry.registry.svc:5000` to `/etc/rancher/k3s/registries.yaml` where it fails. The lab VMs have the entry already |
| `postgres.yaml` | The database of the maintenance team, `wal_level=logical`, credentials `wartung`/`wartung` |
| `topic.yaml` | The topic for the work orders (one partition, three replicas) |
| `connect-frame.yaml`, `jdbc-source-frame.yaml` | The starting points: the lab copies them to `~/connect.yaml` and `~/jdbc-source.yaml` and fills in the TODOs |
| `connect.yaml` | The solution: `KafkaConnect` with `spec.build`, the JDBC plugin pinned by sha512, AppArmor profile of the build container, plain-HTTP push |
| `jdbc-source.yaml` | The solution: polling with an incrementing id |
| `debezium-source.yaml` | Change data capture; needs the Debezium plugin in the image (see the lab's "Going deeper") |

## How the build works, and what it needs

Strimzi starts a pod `connect-connect-build` that runs buildah: it pulls the Kafka base image, downloads and unpacks
the plugins, and pushes the result to `spec.build.output.image`. Two things are not default on k3s:

* **AppArmor.** containerd starts containers under `cri-containerd.apparmor.d`, which forbids `mount`. buildah fails
  while unpacking the base image with `remount /: permission denied`. Setting
  `template.buildContainer.securityContext.appArmorProfile.type: Unconfined` is enough; no `privileged`, no extra
  capabilities.
* **The registry name.** The build pod pushes to `registry.registry.svc:5000` (cluster DNS, plain HTTP, hence
  `additionalPushOptions: ["--tls-verify=false"]`). The kubelet pulls on the node, where that name does not resolve.
  The mirror in `registries.yaml` maps it to `http://localhost:30500`, the NodePort of the registry:

  ```yaml
  mirrors:
    "registry.registry.svc:5000":
      endpoint:
        - "http://localhost:30500"
  ```

Measured on the lab VMs: the build takes about 30 seconds, `KafkaConnect` is Ready after about 100 seconds; adding a
second plugin and rebuilding takes about the same.

`reset.sh` removes Connect, the connectors, the registry (and with it the images), the database and the topics, including
Connect's internal topics: left behind, the stored offsets would make a new connector skip rows.
