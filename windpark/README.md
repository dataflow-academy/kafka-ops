# Wind park

The applications of six teams of the fictional company Nordwind, running in the namespace `windpark`.
The platform team (the training participants) operates the Kafka cluster; these are its customers.
Nothing here needs code changes: every application is configured through a ConfigMap.

    ./prepare.sh               # the wind park as participants meet it: faults F1-F5 built in
    ./prepare.sh as-requested  # same, plus the topics approved exactly as requested (fault F6)
    ./prepare.sh healthy       # no faults
    ./render.sh > ~/windpark.yaml  # prepare the editable participant manifests
    kubectl apply -f ~/windpark.yaml  # deploy them; participants create the onboarding topics themselves
    ./apply.sh                 # apply directly (used by prepare.sh for catch-up states)
    ./reset.sh                 # remove everything (the cluster stays)

`requests/topics-skeleton.yaml` is the file participants fill in for the three topics of the onboarding requests.
`prepare.sh` creates the three topics of the onboarding requests if they do not exist yet (with the grandfathering label of the governance lab when its naming policy is active). Participants
create them themselves in the onboarding lab. They render `~/windpark.yaml` once with `windpark/render.sh`,
inspect it and run `kubectl apply -f ~/windpark.yaml`. Rendering only substitutes the pinned image versions
and registry address; it does not contact the cluster. All resources carry their own namespace.

Keep this file for the repairs in M6. Edit the affected ConfigMap or Deployment in the file, then apply
it again. Editing ConfigMap data does not change its generated name and does not restart a Deployment:
restart only the affected Deployment explicitly with `kubectl rollout restart`. A CronJob uses the changed
ConfigMap on its next Job; existing Jobs keep their original environment. Do not render the file again
after repairing it, as that would replace your edits with the initial faulty state.

| Team | Application | Reads / writes |
|---|---|---|
| SCADA | `scada-telemetry`, Deployment | writes `telemetry` |
| Assets | `assets-stammdaten`, Deployment (a snapshot every 20 seconds, the pod ends on the first failed delivery) | writes `turbine-registry` and `park-registry` (compacted) |
| Leitwarte | `leitwarte`, 2 replicas | reads telemetry, group `leitwarte` |
| Abrechnung | `abrechnung` | reads telemetry, group `abrechnung` (classic group protocol) |
| Prognose | `prognose` | reads telemetry, group `prognose` |
| Wartung | `wartung-meldung`, CronJob every 20 minutes | writes one record into `telemetry` (they asked for a topic of that name too, SCADA got it first, and nobody told them the counter-proposal; fault F2) |
| Alarme | `alarme` | writes an alert every 10 seconds |

## The faults

Each fault is a Kustomize component in `faults/`. The `kustomization.yaml` in this folder lists F1 to F5;
these components prepare the exercise, not its participant repair path. Participants edit the rendered
YAML and apply it themselves. Overlays under `fixes/` are catch-up states for skipped labs.

| | Fault | Mechanics |
|---|---|---|
| F1 | Abrechnung reads a topic with a typo | `TOPIC=telemetery`; topic auto-creation makes it an empty topic |
| F2 | Wartung writes `"n/a"` into `power_kw` | every consumer that reads the record stops (poison pill); a new one arrives every 20 minutes |
| F3 | Alarme built its own topic | `windpark_alerts`, one partition, one replica, `min.insync.replicas=1` |
| F4 | Prognose falls behind | CPU limit 25m, it needs about 30m at 200 records/s |
| F5 | SCADA writes with `acks=1` | `KAFKA_ACKS=1` and `KAFKA_ENABLE_IDEMPOTENCE=false` |
| F6 | Traps from the onboarding requests | `topics/as-requested`: 500 partitions, `min.insync.replicas=3` on the registries; the rolling restart of the metrics lab then makes the Assets pod fail and restart |

Behaviour worth knowing when repairing:

* A poison pill stays in the topic until its retention ends. Every consumer group that has to read past it
  (also a group that is started later and begins at the earliest offset, for example Abrechnung after F1 is
  repaired) stops on it until its offset is behind the record.
* Wartung keeps writing a new pill every 20 minutes as long as F2 is in place.
* `topics/` holds the careful (`sensible`) and the unchecked (`as-requested`) version of the onboarding topics.
