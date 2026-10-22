#!/usr/bin/env bash
# Installs a Strimzi release: a thin wrapper around cluster/operator.sh, which does the work (download, sha256
# check, namespace, apply). The upgrade lab uses it to name the target version explicitly.
#
#   ./operator.sh [version]     default: STRIMZI_UPGRADE_VERSION from versions.env
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/lib/common.sh"
version="${1:-$STRIMZI_UPGRADE_VERSION}"
# The version goes in as an argument and, for a cluster/operator.sh that only reads the environment, as STRIMZI_VERSION.
STRIMZI_VERSION="$version" exec "$HERE/cluster/operator.sh" "$version"
