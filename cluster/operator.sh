#!/usr/bin/env bash
# Installs a Strimzi operator release into the namespace `kafka`, the same steps as the first lab: download the
# release file to ~/strimzi-<version>.yaml, set the namespace with sed, kubectl apply. Run it on node1. Idempotent.
#
#   ./operator.sh [version]     default 1.1.0, the release the labs start with; the upgrade lab passes 1.2.0,
#                               the ZooKeeper migration lab 0.45.1 (the last release with ZooKeeper)
#
# The checksum protects against a changed or truncated download; a version without one below is refused.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need curl
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."

version="${1:-1.1.0}"
case "$version" in
  1.1.0) sha256=ee7e38d61452fb7b3be08a3b0fb4497ee0e38d50eb38f41fa4c2276078f68fd0 ;;
  1.2.0) sha256=a0b1ae3e375a7da0674eb3894df8aa955bc50abe8190bc9344e30b83bbee4775 ;;
  0.45.1) sha256=4ba1762b7dd1338546b2f7a3e48881a21218d4dc16b6496014a59533c82a60ce ;;
  *) die "No checksum for Strimzi ${version} in $0. Add it before installing." ;;
esac
url="https://github.com/strimzi/strimzi-kafka-operator/releases/download/${version}/strimzi-cluster-operator-${version}.yaml"
file="$HOME/strimzi-${version}.yaml"

log "Namespace ${KAFKA_NAMESPACE}"
kubectl create namespace "$KAFKA_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

log "Strimzi ${version}"
curl -sfL "$url" -o "$file" || die "Download failed: $url"
echo "$sha256  $file" | sha256sum -c --status || die "Checksum mismatch for $url"
# The release file is written for the namespace "myproject".
sed -i "s/namespace: .*/namespace: ${KAFKA_NAMESPACE}/" "$file"
kubectl apply -f "$file" >/dev/null
kubectl -n "$KAFKA_NAMESPACE" rollout status deployment/strimzi-cluster-operator --timeout=180s
