#!/usr/bin/env bash
# Finger weg! HANDS OFF: reading this file spoils the incident. Diagnose the cluster instead.
# Entry point of the incident. Keep the failure choice out of the participant commands and output.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
touch "$HOME/.bad-things2-started"
"$HERE/break.sh" P4
