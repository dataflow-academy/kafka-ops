# Wind park fixes

Start states after repairs, so a group that skipped a lab can start the next one.

| | |
|---|---|
| `reset-to-training.sh` | the wind park with faults F1-F5, topic auto-creation on, and a poison pill from the maintenance tool in the topic (start of "Helping the dev teams") |
| `after-helping-devs/` | Kustomize overlay without F1, F2, F4 and F5 (F3 stays) |
| `after-helping-devs.sh` | applies that overlay and moves the three consumer groups behind the poison pills |
| `skip-poison-pill.sh` | stops the consumer applications, moves their groups to the end of the telemetry topic, starts them again |

`./prepare.sh healthy` (in the folder above) is the wind park without any fault, the state after the governance lab.
