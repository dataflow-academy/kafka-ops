#!/usr/bin/env bash
# Installs a Strimzi release: a thin wrapper around cluster/operator.sh, which does the work (download, sha256
# check, namespace, apply). The upgrade lab does the same steps by hand; this is the rescue path.
#
#   ./operator.sh [version]     default 1.2.0, the release the upgrade lab goes to
HERE="$(cd "$(dirname "$0")/.." && pwd)"
exec "$HERE/cluster/operator.sh" "${1:-1.2.0}"
