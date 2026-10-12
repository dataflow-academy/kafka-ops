#!/usr/bin/env bash
# Prints "<private ip> <interface>" of this VM: the address on the interface that carries the route of the
# private lab network (10.0.0.0/8). k3s needs both for --node-ip and --flannel-iface.
dev="$(ip -4 route show 10.0.0.0/8 | awk '{for(i=1;i<NF;i++) if($i=="dev"){print $(i+1); exit}}')"
[ -n "$dev" ] || { echo "No interface with a route to the private network found." >&2; exit 1; }
ip -4 -o addr show dev "$dev" | awk -v dev="$dev" '{sub("/.*","",$4); print $4, dev; exit}'
