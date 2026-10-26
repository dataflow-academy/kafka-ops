#!/usr/bin/env bash
# Finger weg! HANDS OFF: reading this file spoils the incident. Diagnose the cluster instead.
# Second part of incident 1, run by the BOFH of the lab: one more broker goes while nobody brings brokers back.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/break.sh" P1b
touch "$HOME/.bad-things1b-started"
