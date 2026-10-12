#!/usr/bin/env bash
# Rebuilds the cluster at the installed versions (see prepare.sh). Destroys all data. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
"$HERE/cluster/reset.sh"
"$HERE/cluster/prepare.sh"
"$HERE/monitoring/prepare.sh"
"$HERE/windpark/prepare.sh" healthy
