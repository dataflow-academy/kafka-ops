#!/usr/bin/env bash
# Start state "after the lab Helping the dev teams": the wind park without F1, F2, F4 and F5 (F3 stays), and the
# consumer groups behind the poison pill. Idempotent. Run it on node1.
HERE="$(cd "$(dirname "$0")" && pwd)"
# The wind park script waits for deployments that crash on the pill; moving the groups in parallel ends the wait early.
( sleep 60; "$HERE/skip-poison-pill.sh" ) &
"$HERE/../prepare.sh" healthy fixes/f3-alerts.yaml
wait
"$HERE/skip-poison-pill.sh"
# The working file windpark.yaml gets the same state: the healthy wind park with the topic and the ConfigMap of team
# Alerts taken from f3-alerts.yaml (without its comments), so the governance lab can move the team in this file.
awk '
  # Replaces a document of the healthy file by the one from f3-alerts.yaml, keeping its comment lines.
  function flush(   out, i, lines, k) {
    out = doc
    if (doc ~ /\nkind: KafkaTopic\n/ && doc ~ /\n  name: nordwind[.]alerts[.]public[.]windpark-alert[.]event\n/) out = topic
    else if (doc ~ /\nkind: ConfigMap\n/ && doc ~ /\n  name: alerts-config\n/) out = config
    if (out != doc) {
      k = split(substr(doc, 2), lines, "\n")
      for (i = 1; i <= k && lines[i] ~ /^#/; i++) printf "%s\n", lines[i]
      printf "%s", out
    } else printf "%s", substr(doc, 2)
    doc = "\n"
  }
  FNR == 1 { file++; doc = "\n" }
  file == 1 && /^---$/ { n++; next }
  file == 1 && /^#/ { next }
  file == 1 { if (n == 0) topic = topic $0 "\n"; else config = config $0 "\n"; next }
  /^---$/ { flush(); print; next }
  { doc = doc $0 "\n" }
  END { flush() }
' "$HERE/f3-alerts.yaml" "$HERE/../windpark-healthy.yaml" > "$HERE/../windpark.yaml"
