# nfs-01: NFS server and persistent client mount

## Hints

1. Both nodes need the package nfs-utils. Node 1 also needs an export
   definition, the running service nfs-server and a firewall rule.
   Node 2 needs a mount point and a line in /etc/fstab.
2. An export line holds the directory, then each client directly
   followed by its options in parentheses, with no space between the
   client and the parenthesis. Read man exports. The command exportfs
   reloads the definitions and shows the active exports.
3. Root squashing maps the user root of node 2 to nobody on node 1, so
   nobody needs write access to /srv/nfsshare. The firewalld service
   for NFS version 4 is called nfs.
4. The first field of the fstab line is the address of node 1, a
   colon and the exported path. Read man nfs. The command mount with
   only the mount point as argument reads the rest from /etc/fstab.

## Solution

All steps run on the workstation as the lab user. They reach the nodes
with run_on_node from the lab library, which uses the SSH settings of
the lab configuration. The same commands work in an SSH session on the
node.

1. [user] Load the lab configuration and the node addresses. Node 1
   is the server, node 2 the client:

   ```bash
   source /opt/linux-labs/lib/load-config.sh
   N1=$(get_node_ip 1); N2=$(get_node_ip 2)
   ```

2. [user] Install nfs-utils on both nodes where it is missing:

   ```bash
   for ip in $N1 $N2; do
     run_on_node "$ip" \
       "rpm -q nfs-utils || sudo -n dnf -y install nfs-utils"
   done
   ```

3. [user] On node 1, give the directory to nobody, so that root of
   node 2 can write to it through root squashing. Then export it
   read-write to node 2 only:

   ```bash
   run_on_node "$N1" "sudo -n chown nobody:nobody /srv/nfsshare"
   echo "/srv/nfsshare $N2(rw)" | run_on_node "$N1" \
     "sudo -n tee /etc/exports.d/nfsshare.exports"
   ```

4. [user] Start the NFS server on node 1, enable it at boot and load
   the export:

   ```bash
   run_on_node "$N1" "sudo -n systemctl enable --now nfs-server"
   run_on_node "$N1" "sudo -n exportfs -rv"
   ```

5. [user] Open the firewall of node 1 for NFS:

   ```bash
   run_on_node "$N1" \
     "sudo -n firewall-cmd --permanent --add-service=nfs"
   run_on_node "$N1" "sudo -n firewall-cmd --reload"
   ```

6. [user] On node 2, create the mount point, add the fstab entry and
   mount it:

   ```bash
   run_on_node "$N2" "sudo -n mkdir -p /mnt/nfsshare"
   echo "$N1:/srv/nfsshare /mnt/nfsshare nfs defaults,_netdev 0 0" |
     run_on_node "$N2" "sudo -n tee -a /etc/fstab"
   run_on_node "$N2" "sudo -n systemctl daemon-reload"
   run_on_node "$N2" "sudo -n mount /mnt/nfsshare"
   ```

## Verification

The export on node 1 names node 2 with rw and root_squash, and node 2
shows the mount with type nfs4:

```bash
run_on_node "$N1" "sudo -n exportfs -v"
run_on_node "$N2" "findmnt /mnt/nfsshare"
run_on_node "$N2" "sudo -n touch /mnt/nfsshare/from-node2"
run_on_node "$N1" "ls -l /srv/nfsshare"
```

Then grade:

```bash
labctl grade nfs-01
```

## Explanation

The NFS server reads its exports from /etc/exports and from the files
ending in .exports in /etc/exports.d. Starting nfs-server loads them,
and exportfs -r loads them again after a change. Each client entry
carries its own options. A space between the client and the
parenthesis is a classic mistake: the options then apply to every
host, and the named client gets the read-only defaults.

Root squashing is on by default. The server treats root of the client
as the user nobody, so a directory owned by root with mode 0755 is
read-only for it. Giving the directory to nobody, or loosening its
permissions, fixes that without no_root_squash, which would make root
of node 2 root of the share.

NFS version 4 uses only TCP port 2049, which the firewalld service nfs
opens. Rocky Linux 8 and 9 both mount version 4.2 by default, so the
services mountd and rpc-bind are not needed in the firewall. They are
for NFS version 3 clients.

In /etc/fstab the option _netdev and the type nfs both tell systemd
that the mount needs the network, so it waits for it at boot. The
daemon-reload makes systemd read the changed fstab before the mount.
