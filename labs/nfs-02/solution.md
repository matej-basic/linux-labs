# nfs-02: NFS export security and autofs client mounts

## Hints

1. Node 1 needs the package nfs-utils, the two export definitions,
   the running service nfs-server and a firewall rule. Node 2 needs
   nfs-utils, autofs, a master map entry for /shares and a map file
   with one line per share.
2. Squashing is set per client in the export options. Read man
   exports, section User ID Mapping: one option maps every user, two
   more set the user ID and group ID they map to.
3. The master map line holds the mount point /shares and the path of
   the map file. The map file names each key (projects, docs), its
   mount options and the location host:/path. Read man auto.master
   and man 5 autofs.
4. Do not create /shares or its subdirectories by hand. After the
   configuration changes, the service autofs has to read its maps
   again.

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

2. [user] Install nfs-utils on both nodes and autofs on node 2 where
   they are missing:

   ```bash
   run_on_node "$N1" \
     "rpm -q nfs-utils || sudo -n dnf -y install nfs-utils"
   run_on_node "$N2" "rpm -q nfs-utils autofs ||
     sudo -n dnf -y install nfs-utils autofs"
   ```

3. [user] On node 1, export /srv/projects read-write with every user
   mapped to projdata (3001), and /srv/docs read-only:

   ```bash
   printf '%s\n' \
     "/srv/projects $N2(rw,all_squash,anonuid=3001,anongid=3001)" \
     "/srv/docs $N2(ro)" |
     run_on_node "$N1" "sudo -n tee /etc/exports.d/nfs-02.exports"
   ```

4. [user] Start the NFS server on node 1, enable it at boot and load
   the exports:

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

6. [user] On node 2, add the master map entry for /shares and the
   indirect map with the two shares:

   ```bash
   echo "/shares /etc/auto.shares" |
     run_on_node "$N2" "sudo -n tee /etc/auto.master.d/shares.autofs"
   printf '%s\n' \
     "projects -rw $N1:/srv/projects" \
     "docs -ro $N1:/srv/docs" |
     run_on_node "$N2" "sudo -n tee /etc/auto.shares"
   ```

7. [user] Enable autofs on node 2 and restart it, so that it reads
   the new maps also when it was already running:

   ```bash
   run_on_node "$N2" "sudo -n systemctl enable autofs"
   run_on_node "$N2" "sudo -n systemctl restart autofs"
   ```

## Verification

The exports on node 1 show all_squash with the anonymous IDs and ro,
and node 2 mounts the shares when they are accessed:

```bash
run_on_node "$N1" "sudo -n exportfs -v"
run_on_node "$N2" "ls /shares/projects /shares/docs"
run_on_node "$N2" "findmnt -t nfs4"
run_on_node "$N2" "sudo -n touch /shares/projects/from-node2"
run_on_node "$N1" "ls -ln /srv/projects"
run_on_node "$N2" "sudo -n touch /shares/docs/test"
```

The last command fails with "Read-only file system". Then grade:

```bash
labctl grade nfs-02
```

## Explanation

Without extra options an export squashes only root: the client's root
becomes nobody, and every other user keeps its UID. all_squash maps
every client user to the anonymous user, and anonuid and anongid say
which IDs that is. Files from node 2 then belong to projdata on node 1,
whatever user created them, and the mode 0770 of /srv/projects lets
exactly that user write. This suits a shared drop directory where the
client's user IDs do not match the server's.

/srv/docs is exported ro, so the server refuses every write with the
error EROFS, also for users that the directory permissions would let
write. Root squashing stays on as a second line of defence.

autofs reads /etc/auto.master and every file ending in .autofs in
/etc/auto.master.d. An indirect map owns the directory /shares: autofs
mounts /shares itself as an autofs file system and creates
/shares/projects and /shares/docs only while they are mounted. A
directory created there by hand hides the key. After the timeout
(10 minutes by default) an idle share is unmounted again.

The exports and the map are the same on Rocky Linux 8 and 9, and both
mount NFS version 4.2 by default. The firewalld service nfs is enough
for version 4.
