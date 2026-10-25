# Kafka tools

The command line tools (`kafka-topics.sh`, ...) are installed on the lab VMs and talk to the cluster through the external
NodePort listener (`$IP.1:31094`), like a laptop outside the cluster. `kafka-tools.yaml` is a pod with the same tools
INSIDE the cluster on node1, for the places where the access from inside is the point:

    kubectl apply -f tools/kafka-tools.yaml
    kubectl exec -i deploy/kafka-tools -- kafka-topics.sh --bootstrap-server nordwind-kafka-kafka-bootstrap:9092 --list

`prepare.sh` applies it and waits; `reset.sh` removes it. Idempotent.
