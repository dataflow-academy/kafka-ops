# Wind park workload (legacy)

Superseded by `windpark/` (own namespace, faults F1-F6, repairs). Kept only as the reference for the Kustomize layout; the labs do not use it.

See the root README for the knobs and the Kustomize layout.

    ./prepare.sh              # overlays/training: the wind park as participants meet it
    ./prepare.sh healthy      # without faults
    ./reset.sh                # remove producer, consumers and the topic
