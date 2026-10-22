# Wind park fixes

Start states after repairs, so a group that skipped a lab can start the next one.
These scripts are catch-up tools, not the participant repair path.

In M6, keep `~/windpark.yaml` from onboarding, edit the affected ConfigMap or Deployment,
and run `kubectl apply -f ~/windpark.yaml`. After changing ConfigMap data, explicitly
restart only the affected Deployment; new CronJob Jobs read the updated data automatically.
Do not copy `windpark/windpark.yaml` again between repairs, it would overwrite them.
The two manifests `windpark/windpark.yaml` and `windpark/windpark-healthy.yaml` are supplied by
Day 1 (PR #2); the labs and catch-up scripts assume that material is available.

| | |
|---|---|
| `reset-to-training.sh` | the wind park with faults F1-F5, topic auto-creation on, and a poison pill from the maintenance tool in the topic (start of "Helping the dev teams") |
| `f3-alerts.yaml` | team Alarme's own topic and the ConfigMap that points to it (F3), applied on top of the healthy wind park |
| `after-helping-devs.sh` | applies the healthy wind park plus `f3-alerts.yaml` (F1, F2, F4 and F5 repaired, F3 stays) and moves the three consumer groups behind the poison pills |
| `skip-poison-pill.sh` | stops the consumer applications, moves their groups to the end of the telemetry topic, starts them again |

`./prepare.sh healthy` (in the folder above) is the wind park without any fault, the state after the governance lab.
