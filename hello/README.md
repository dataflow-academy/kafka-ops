# Hello Strimzi

`hello.yaml` is the smallest Kafka cluster Strimzi runs: one node that is controller and broker, ephemeral
storage, NodePort 31094 for the self-checks. `topic.yaml` is the topic `hello`.

    ./prepare.sh    # k3s on three nodes, the Strimzi operator, Kafka UI, the cluster `hello`, one message in the topic `hello`
    ./reset.sh      # delete the cluster `hello` (k3s, the operator and Kafka UI stay)
