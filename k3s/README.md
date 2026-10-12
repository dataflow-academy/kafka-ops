# k3s

`prepare.sh` installs the pinned k3s version: the server on `node1`, agents on `node2` and `node3`.
Traefik and the service load balancer are disabled (everything is reached through NodePorts).
The nodes talk over the private lab network; the script finds its interface and addresses itself.

`reset.sh` uninstalls k3s from all nodes. Needs `ssh node1..3` and `sudo` on the nodes.
