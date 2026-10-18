#!/usr/bin/env bash
# Finger weg! HANDS OFF: reading this file spoils the incident. Diagnose the cluster instead.
# Trainer entry point. Keep the failure choice out of the participant commands and output.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/break.sh" P5
touch "$HOME/.bad-things3-started"
