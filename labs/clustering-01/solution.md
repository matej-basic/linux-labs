# clustering-01: Basic three-node Pacemaker cluster

## Hints

1. Three things come before the cluster exists: the packages from the
   High Availability repository, the firewall, and a password for the
   hacluster account with the pcs daemon running on every node.
2. The pcs tool does the rest from one node. Read man pcs, the
   sections host (authentication) and cluster (setup), and use the
   --start and --enable options of the setup subcommand.
3. In the setup, pass each node as its host name with an addr value
   holding its IP address. The firewall service for the cluster is
   called high-availability.
4. For the resource, look at man ocf_heartbeat_apache. The cluster
   starts httpd itself, so httpd must stay disabled in systemd, and
   Pacemaker will not start resources while stonith-enabled is true.

## Solution

All steps run on the workstation as the lab user. They reach the nodes
with run_on_node from the lab library, which uses the SSH settings of
the lab configuration.

1. [user] Load the lab configuration and collect the node addresses
   and host names:

   ```bash
   source /opt/linux-labs/lib/load-config.sh
   N1=$(get_node_ip 1); N2=$(get_node_ip 2); N3=$(get_node_ip 3)
   ALL="$N1 $N2 $N3"
   H1=$(run_on_node "$N1" uname -n)
   H2=$(run_on_node "$N2" uname -n)
   H3=$(run_on_node "$N3" uname -n)
   ```

2. [user] Install Pacemaker, pcs and httpd on all three nodes. The
   High Availability repository is called ha on release 8 and
   highavailability on release 9:

   ```bash
   EL=$(run_on_node "$N1" \
     '. /etc/os-release; echo ${VERSION_ID%%.*}')
   if [ "$EL" = 8 ]; then HA_REPO=ha; else HA_REPO=highavailability; fi
   for ip in $ALL; do
     run_on_node "$ip" "sudo -n dnf -y install \
       --enablerepo=$HA_REPO pacemaker pcs httpd"
   done
   ```

3. [user] On every node open the firewall for the cluster, set a
   password for the hacluster account and start the pcs daemon:

   ```bash
   for ip in $ALL; do
     run_on_node "$ip" "
       sudo -n firewall-cmd --permanent \
         --add-service=high-availability &&
       sudo -n firewall-cmd --reload &&
       echo 'hacluster:LabPass-2024' | sudo -n chpasswd &&
       sudo -n systemctl enable --now pcsd"
   done
   ```

4. [user] Authenticate the nodes to each other and create the cluster
   from node 1. The cluster is started and enabled at boot:

   ```bash
   NODES="$H1 addr=$N1 $H2 addr=$N2 $H3 addr=$N3"
   run_on_node "$N1" \
     "sudo -n pcs host auth $NODES -u hacluster -p LabPass-2024"
   run_on_node "$N1" \
     "sudo -n pcs cluster setup ha_cluster $NODES --start --enable"
   ```

5. [user] Wait until the cluster has quorum, then disable STONITH,
   because the nodes have no fence devices:

   ```bash
   run_on_node "$N1" "sudo -n crm_node -q"
   run_on_node "$N1" "sudo -n pcs property set stonith-enabled=false"
   ```

   The first command prints 1 when the cluster has quorum. Repeat it
   after a few seconds if it prints 0.

6. [user] Write a page that names each node and make sure httpd does
   not start at boot, so that only the cluster starts it:

   ```bash
   for ip in $ALL; do
     run_on_node "$ip" "
       echo \"HA Cluster - \$(uname -n)\" |
         sudo -n tee /var/www/html/index.html >/dev/null
       sudo -n systemctl disable httpd"
   done
   ```

7. [user] Create the Apache resource:

   ```bash
   run_on_node "$N1" "sudo -n pcs resource create apache_web \
     ocf:heartbeat:apache configfile=/etc/httpd/conf/httpd.conf \
     op monitor interval=1min"
   ```

## Verification

```bash
run_on_node "$N1" "sudo -n pcs status"
labctl grade clustering-01
```

## Explanation

pcs is the supported way to build the cluster on Rocky and RHEL 8 and
9. The pcs daemon on each node (pcsd, port 2224, opened by the
high-availability firewall service) lets pcs on node 1 write
corosync.conf and the authentication key to all nodes, so no files
need to be copied between nodes, which cannot log in to each other as
root anyway. The addr= values put the node IP addresses into the
corosync node list, and the node names are the host names that
Pacemaker expects. Corosync with three votes gives a quorum of 2:
the cluster survives the loss of one node.

Pacemaker refuses to start resources while STONITH is enabled and no
fence device exists, so apache_web would stay stopped. The resource
agent ocf:heartbeat:apache starts httpd itself, which is why httpd
must not be enabled in systemd: two managers would fight over port
80. The grader checks that httpd runs on one node only.

The repository id differs between releases (ha and highavailability),
and the pcs commands are the same on both. pcs resource create starts
the resource on its own; there is no separate start command.
