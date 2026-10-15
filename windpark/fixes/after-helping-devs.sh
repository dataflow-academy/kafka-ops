#!/usr/bin/env bash
# Start state "after the lab Helping the dev teams": the wind park without F1, F2, F4 and F5 (F3 stays), and the
# consumer groups behind the poison pill. Idempotent. Run it on node1.
HERE="$(cd "$(dirname "$0")" && pwd)"
# The wind park script waits for deployments that crash on the pill; moving the groups in parallel ends the wait early.
( sleep 60; "$HERE/skip-poison-pill.sh" ) &
"$HERE/../prepare.sh" fixes/after-helping-devs
wait
"$HERE/skip-poison-pill.sh"
