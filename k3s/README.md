# k3s

`prepare.sh` does what the first lab does by hand: the latest k3s release with its defaults
(`curl -sfL https://get.k3s.io | sh -`), the server on `node1`, agents on `node2` and `node3`
(`K3S_URL=https://$IP.1:6443`), the kubeconfig copied to `~/.kube/config` and the namespace `kafka` set as the
default of its context.

`reset.sh` uninstalls k3s from all nodes.

Both need `ssh $IP.2` and `ssh $IP.3` from `node1` (the key pair of the image) and `sudo` on the nodes.
