# clustering-03: Quorum and split-brain protection

## Solution

1. [user] On the workstation, load the lab configuration and define
   a helper that runs a command on a node over SSH. All following
   commands run on the workstation:

   ```bash
   source /opt/linux-labs/lib/load-config.sh
   load_lab_config
   NODES="$(get_node_ip 1) $(get_node_ip 2) $(get_node_ip 3)"
   NODE1=$(get_node_ip 1)
   CONF=/etc/corosync/corosync.conf
   n() { local ip=$1; shift; ssh -n "$SSH_USER@$ip" "$@"; }
   ```

2. [user] Check the starting state. Every node should show 3 expected
   votes and the flag Quorate, and the cluster property
   no-quorum-policy should be ignore:

   ```bash
   for ip in $NODES; do n "$ip" "sudo corosync-quorumtool -s"; done
   n "$NODE1" "sudo pcs property config"
   ```

3. [user] Set the votequorum options in the quorum block of
   corosync.conf on every node. The first sed command deletes
   existing values, the second adds the three options after the
   provider line:

   ```bash
   DEL='/^[[:space:]]*(wait_for_all|last_man_standing|'
   DEL="$DEL"'last_man_standing_window):/d'
   ADD='/^quorum {/,/^}/ s/^\([[:space:]]*\)provider:.*/&'
   ADD="$ADD"'\n\1wait_for_all: 1\n\1last_man_standing: 1'
   ADD="$ADD"'\n\1last_man_standing_window: 10000/'
   for ip in $NODES; do
     n "$ip" "sudo sed -i -E '$DEL' $CONF"
     n "$ip" "sudo sed -i '$ADD' $CONF"
   done
   n "$NODE1" "sudo sed -n '/^quorum {/,/^}/p' $CONF"
   ```

4. [user] Restart the cluster services one node at a time and wait
   until the node has rejoined, so that the other two nodes keep
   quorum:

   ```bash
   for ip in $NODES; do
     n "$ip" "sudo systemctl stop pacemaker corosync"
     n "$ip" "sudo systemctl start pacemaker"
     for i in $(seq 1 60); do
       n "$ip" "sudo corosync-quorumtool -s |
         grep -Eq '^Nodes:[[:space:]]+3\$'" && break
       sleep 2
     done
   done
   ```

5. [user] Make a partition without quorum stop its resources:

   ```bash
   n "$NODE1" "sudo pcs property set no-quorum-policy=stop"
   ```

## Verification

```bash
for ip in $NODES; do n "$ip" "sudo corosync-quorumtool -s"; done
n "$NODE1" "sudo pcs property config"
n "$NODE1" "sudo pcs status"
labctl grade clustering-03
```

## Explanation

Votequorum gives every node one vote, and the cluster is quorate while
a strict majority, 2 of 3, is connected. A node in the minority
partition must not run resources, otherwise both halves start
apache_web and write to the same data. Pacemaker enforces that with
no-quorum-policy: the lab starts with the value ignore, which lets the
minority keep running, and stop makes it stop every resource.

wait_for_all keeps a freshly started cluster inactive until all nodes
have been seen once, so a single node that boots first cannot become
quorate on its own. last_man_standing recalculates the expected votes
after the window of 10000 ms when nodes leave, so the cluster can
shrink step by step and stay quorate. Corosync reads corosync.conf only
at start, so the restart in step 4 is required, and the grader checks
the running cluster as well as the file. The nodes are restarted one at
a time because stopping two at once costs the cluster its quorum.

STONITH stays enabled: quorum decides who may run resources, fencing
makes sure the other side is really off. The two_node option is meant
for clusters of exactly two nodes and stays off here.
