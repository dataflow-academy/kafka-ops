# Storage

Material for the storage lab: what is on the disk of a broker, when retention deletes it, and what compaction keeps.

    ./prepare.sh    # cluster, monitoring and wind park running, no experiment topics
    ./reset.sh      # delete the experiment topics, undo the tuning of the master data topic

`retention-demo.yaml` is the topic of the retention experiment. The compaction experiment uses the master data topic
of the wind park (`turbine-registry`): its team writes a full snapshot every 20 seconds,
so there are many records per key.
