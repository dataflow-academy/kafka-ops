#!/usr/bin/env bash
# Writes the frame of the Connect lab to ~/connect.yaml with the pinned Kafka version filled in, and the frame
# of the connector to ~/jdbc-source.yaml. Refuses to overwrite files that are already there (your work!);
# remove them first or pass FORCE=1 to start over.
. "$(dirname "$0")/../lib/common.sh"
need envsubst
for f in connect jdbc-source; do
  [ -z "${FORCE:-}" ] && [ -e "$HOME/$f.yaml" ] && die "$HOME/$f.yaml exists. Move it away or run FORCE=1 $0 to start over."
done
render "$(dirname "$0")/connect-frame.yaml" > "$HOME/connect.yaml"
cp "$(dirname "$0")/jdbc-source-frame.yaml" "$HOME/jdbc-source.yaml"
echo "Wrote $HOME/connect.yaml and $HOME/jdbc-source.yaml"
