# Wind park fixes

Start states after repairs, so a group that skipped a lab can start the next one.
These scripts are catch-up tools, not the participant repair path.

In M6, keep `~/windpark.yaml` from onboarding, edit the affected ConfigMap or Deployment,
and run `kubectl apply -f ~/windpark.yaml`. After changing ConfigMap data, explicitly
restart only the affected Deployment; new CronJob Jobs read the updated data automatically.
Do not render the working file again between repairs. `windpark/render.sh` is supplied by
Day 1 (PR #2); the labs and catch-up scripts assume that material is available.

| | |
|---|---|
| `reset-to-training.sh` | the wind park with faults F1-F5, topic auto-creation on, and a poison pill from the maintenance tool in the topic (start of "Helping the dev teams") |
| `after-helping-devs/` | Kustomize overlay without F1, F2, F4 and F5 (F3 stays) |
| `after-helping-devs.sh` | applies that overlay and moves the three consumer groups behind the poison pills |
| `skip-poison-pill.sh` | stops the consumer applications, moves their groups to the end of the telemetry topic, starts them again |

`./prepare.sh healthy` (in the folder above) is the wind park without any fault, the state after the governance lab.
