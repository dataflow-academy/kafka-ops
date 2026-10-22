#!/usr/bin/env bash
# Installs a Strimzi operator release into the namespace `kafka`. Run it on node1. Idempotent.
#
#   ./operator.sh [version]     default: STRIMZI_VERSION from versions.env
#
# cluster/prepare.sh and hello/prepare.sh call it without an argument; the upgrade and the ZooKeeper
# migration labs pass the release they need. A version without a checksum in versions.env is refused.
#
# The install file is downloaded from the Strimzi release page with the version and checksum pinned in
# versions.env. That is the flow of Strimzi's own documentation, so participants meet what they will meet
# in production; the checksum protects against a changed or truncated download.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need curl
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."

version="${1:-$STRIMZI_VERSION}"
STRIMZI_URL="https://github.com/strimzi/strimzi-kafka-operator/releases/download/${version}/strimzi-cluster-operator-${version}.yaml"
sha_var="STRIMZI_INSTALL_SHA256_${version//./_}"
[ -n "${!sha_var:-}" ] || die "No checksum for Strimzi ${version} in versions.env (${sha_var}). Add it before installing."

log "Namespace ${KAFKA_NAMESPACE}"
kubectl create namespace "$KAFKA_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

log "Strimzi ${version}"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
curl -sfL "$STRIMZI_URL" -o "$tmp" || die "Download failed: $STRIMZI_URL"
echo "${!sha_var}  $tmp" | sha256sum -c --status || die "Checksum mismatch for $STRIMZI_URL"
# The release file is written for the namespace "myproject".
sed "s/namespace: .*/namespace: ${KAFKA_NAMESPACE}/" "$tmp" | kubectl apply --server-side --force-conflicts -n "$KAFKA_NAMESPACE" -f - >/dev/null
kubectl -n "$KAFKA_NAMESPACE" rollout status deployment/strimzi-cluster-operator --timeout=180s
