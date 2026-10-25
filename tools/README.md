# Kafka tools

The lab VMs have no Kafka installation. `prepare.sh` starts a pod with the command line tools on node1:

    kubectl exec -i deploy/kafka-tools -- kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --list

`reset.sh` removes it. Idempotent.
