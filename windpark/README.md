# Wind park

The applications of six teams of the fictional company Nordwind, running in the namespace `windpark`.
The platform team (the training participants) operates the Kafka cluster; these are its customers.
Nothing here needs code changes: every application is configured through a ConfigMap.

    ./prepare.sh               # the wind park as participants meet it: faults F1-F5 built in (windpark-faulty.yaml)
    ./prepare.sh as-requested  # same, plus the topics approved exactly as requested (fault F6)
    ./prepare.sh healthy       # no faults (windpark-healthy.yaml)
    ./reset.sh                 # remove everything (the cluster stays)

Two plain manifests hold the whole wind park, ordered by team (ConfigMap and workload next to each other):

* `windpark-faulty.yaml` is the training state with the faults F1-F5 built in, `windpark.yaml` is the working file: at the
  start it is the same. Participants read it, run `kubectl apply -f ~/kafka-ops/windpark/windpark.yaml` and keep editing it
  for the repairs. `prepare.sh` copies the state it creates over `windpark.yaml`.
* `windpark-healthy.yaml` is the same without the faults. The catch-up scripts apply it.
  `diff windpark-faulty.yaml windpark-healthy.yaml` shows exactly the fault fields.

The images are public, `ghcr.io/dataflow-academy/...:<commit sha>`, pinned in the files. All resources carry their own
namespace (`windpark`, or `kafka` for the KafkaTopic of team Alerts).

`requests/topics.yaml` is the file participants fill in for the topics of the four onboarding requests (they edit it where it lives).
`prepare.sh` creates those topics if they do not exist yet (with the grandfathering label of the governance lab
when its naming policy is active). Participants create them themselves in the onboarding lab.

Editing ConfigMap data in `windpark.yaml` and applying it does not restart a Deployment: restart only the affected
Deployment explicitly with `kubectl rollout restart`. A CronJob uses the changed ConfigMap on its next Job; existing
Jobs keep their original environment. Copying `windpark-faulty.yaml` over `windpark.yaml` again would replace the repairs with the initial faulty
state. `prepare.sh` restarts the Deployments whose ConfigMap it changed.

| Team | Application | Reads / writes |
|---|---|---|
| SCADA | `scada-telemetry`, Deployment | writes `telemetry` |
| Assets | `assets-masterdata`, Deployment (a snapshot every 20 seconds, the pod ends on the first failed delivery) | writes `turbine-registry` and `park-registry` (compacted) |
| Control room | `control-room`, 2 replicas | reads telemetry, group `control-room` |
| Billing | `billing` | reads telemetry, group `billing` (classic group protocol) |
| Forecast | `forecast` | reads telemetry, group `forecast` |
| Maintenance | `maintenance-report`, CronJob every 20 minutes | writes one record into `telemetry` (they asked for a topic of that name too, SCADA got it first, and nobody told them the counter-proposal; fault F2) |
| Alerts | `alerts` | writes an alert every 10 seconds |

## The faults

The faults are values in `windpark-faulty.yaml`; `windpark-healthy.yaml` has the healthy values. They prepare the exercise;
participants repair them in their own copy of the file. `fixes/` (day 2 labs) holds catch-up states for skipped labs.

| | Fault | Mechanics |
|---|---|---|
| F1 | Billing reads a topic with a typo | `TOPIC=telemetery`; topic auto-creation makes it an empty topic |
| F2 | Maintenance writes `"n/a"` into `power_kw` | every consumer that reads the record stops (poison pill); a new one arrives every 20 minutes |
| F3 | Alerts built its own topic | `windpark_alerts`, one partition, one replica, `min.insync.replicas=1` |
| F4 | Forecast falls behind | CPU limit 25m, it needs about 30m at 200 records/s |
| F5 | SCADA writes with `acks=1` | `KAFKA_ACKS=1` and `KAFKA_ENABLE_IDEMPOTENCE=false` |
| F6 | Traps from the onboarding requests | `topics/as-requested`: 500 partitions, `min.insync.replicas=3` on the registries; the rolling restart of the metrics lab then makes the Assets pod fail and restart |

Behaviour worth knowing when repairing:

* A poison pill stays in the topic until its retention ends. Every consumer group that has to read past it
  (also a group that is started later and begins at the earliest offset, for example Billing after F1 is
  repaired) stops on it until its offset is behind the record.
* Maintenance keeps writing a new pill every 20 minutes as long as F2 is in place.
* `topics/` holds the careful (`sensible`) and the unchecked (`as-requested`) version of the onboarding topics, plain
  files: `kubectl apply -f topics/sensible`.
