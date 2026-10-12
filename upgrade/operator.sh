#!/usr/bin/env bash
# Installs a Strimzi operator release the way Strimzi's documentation does: download the release's install
# file, check its sha256, point it at the namespace, apply. It does not touch the Kafka resource.
#
#   ./operator.sh [version]     default: STRIMZI_UPGRADE_VERSION from versions.env
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need curl
version="${1:-$STRIMZI_UPGRADE_VERSION}"
url="https://github.com/strimzi/strimzi-kafka-operator/releases/download/${version}/strimzi-cluster-operator-${version}.yaml"
sha_var="STRIMZI_INSTALL_SHA256_${version//./_}"
[ -n "${!sha_var:-}" ] || die "No checksum for ${version} in versions.env (${sha_var})."

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
log "Download ${url##*/}"
curl -sfL "$url" -o "$tmp" || die "Download failed: $url"
echo "${!sha_var}  $tmp" | sha256sum -c --status || die "Checksum mismatch for $url"
log "Apply to namespace ${KAFKA_NAMESPACE}"
kubectl create namespace "$KAFKA_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
sed "s/namespace: .*/namespace: ${KAFKA_NAMESPACE}/" "$tmp" | kubectl apply --server-side --force-conflicts -n "$KAFKA_NAMESPACE" -f - >/dev/null
kubectl -n "$KAFKA_NAMESPACE" rollout status deployment/strimzi-cluster-operator --timeout=180s
