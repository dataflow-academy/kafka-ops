#!/usr/bin/env bash
# Plain copy of rescue-pod.yaml to ~/rescue.yaml; change claimName before applying it with kubectl apply -f.
cp "$(dirname "$0")/rescue-pod.yaml" "$HOME/rescue.yaml"
echo "Edit ~/rescue.yaml, then apply it with kubectl apply -f ~/rescue.yaml."
