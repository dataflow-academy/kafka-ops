# Kafka tools

The command line tools (`kafka-topics.sh`, ...) are installed on the lab VMs and talk to the cluster through the external
NodePort listener (`$IP.1:31094`), like a laptop outside the cluster. `kafka-tools.yaml` is a pod with the same tools
INSIDE the cluster on node1, for the places where the access from inside is the point:

    kubectl apply -f tools/kafka-tools.yaml
    kubectl exec -i deploy/kafka-tools -- kafka-topics.sh --bootstrap-server nordwind-kafka-kafka-bootstrap:9092 --list

`prepare.sh` applies it and waits; `reset.sh` removes it. Idempotent.

`verifiable-producer.py` writes numbered records from the host (the lab "Ops goes wrong" runs three of them side by
side), one table row per acknowledged record and one line per failed one:

    python3 ~/kafka-ops/tools/verifiable-producer.py --bootstrap-server $IP.1:31094 --topic chaos-acks-all --acks all

`--acks` takes `all` (or `-1`, then the producer is idempotent), `1` or `0`; `--throughput` is records per second
(default 1). It needs `python3-confluent-kafka`, which the lab image has.
