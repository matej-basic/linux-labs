# storage-09: iSCSI target and a persistent initiator login

## Hints

1. Node 1 needs the package targetcli and node 2 the package
   iscsi-initiator-utils. targetcli works like a file system tree:
   backstores, then the target with its target portal group, its
   LUNs, ACLs and portals. Read man targetcli.
2. An ACL names the initiator by its IQN, so the initiator name of
   node 2 has to match it before node 2 logs in. iscsid reads the
   name from /etc/iscsi/initiatorname.iscsi when it starts.
3. On node 2, iscsiadm has a discovery mode that asks node 1 for its
   targets, and a node mode that logs in and shows or updates a node
   record, including node.startup. Read the examples in man iscsiadm.
4. The persistent names in /dev/disk/by-path name the iSCSI disk by
   portal, target and LUN. The command blkid prints the UUID of the
   new file system for the fstab line.

## Solution

1. [user] From the workstation, log in to node 1 as opsadmin. Use the
   node 1 address from the TOPOLOGY section of the task:

   ```bash
   ssh opsadmin@172.25.250.10
   ```

2. [sudo] On node 1, install targetcli where it is missing and start
   the target service, enabled at boot:

   ```bash
   rpm -q targetcli || sudo dnf -y install targetcli
   sudo systemctl enable --now target
   ```

3. [sudo] Create the sparse 512 MiB file backstore, the target, LUN 0
   and the ACL for node 2. The target gets a portal on all addresses,
   port 3260, by default:

   ```bash
   sudo mkdir -p /srv/iscsi
   sudo targetcli /backstores/fileio create disk1 \
     /srv/iscsi/disk1.img 512M
   sudo targetcli /iscsi create iqn.2026-10.lab.example:storage
   T=/iscsi/iqn.2026-10.lab.example:storage/tpg1
   sudo targetcli $T/luns create /backstores/fileio/disk1
   sudo targetcli $T/acls create iqn.2026-10.lab.example:node2
   ```

4. [sudo] Save the configuration and check it:

   ```bash
   sudo targetcli saveconfig
   sudo targetcli ls
   sudo ss -ltn sport = :3260
   ```

5. [sudo] Open the firewall for iSCSI, now and permanently:

   ```bash
   sudo firewall-cmd --add-service=iscsi-target
   sudo firewall-cmd --permanent --add-service=iscsi-target
   ```

6. [user] Log out of node 1 and log in to node 2 from the
   workstation:

   ```bash
   exit
   ssh opsadmin@172.25.250.11
   ```

7. [sudo] On node 2, install the initiator tools where they are
   missing, set the initiator name and restart iscsid so that it
   reads the name:

   ```bash
   rpm -q iscsi-initiator-utils ||
     sudo dnf -y install iscsi-initiator-utils
   echo "InitiatorName=iqn.2026-10.lab.example:node2" |
     sudo tee /etc/iscsi/initiatorname.iscsi
   sudo systemctl restart iscsid
   ```

8. [sudo] Discover the targets of node 1, log in, and make sure that
   the node record logs in at boot. Use the node 1 address:

   ```bash
   IQN=iqn.2026-10.lab.example:storage
   sudo iscsiadm -m discovery -t sendtargets -p 172.25.250.10
   sudo iscsiadm -m node -T $IQN -p 172.25.250.10 -l
   sudo iscsiadm -m node -T $IQN -p 172.25.250.10 \
     -o update -n node.startup -v automatic
   sudo iscsiadm -m session
   ```

9. [sudo] Create the XFS file system on the disk, add the fstab entry
   by UUID and mount it. The mount runs before the daemon-reload, so
   that systemd does not mount it at the same moment:

   ```bash
   DISK=/dev/disk/by-path/ip-172.25.250.10:3260-iscsi-$IQN-lun-0
   sudo mkfs.xfs $DISK
   UUID=$(sudo blkid -s UUID -o value $DISK)
   sudo mkdir -p /mnt/iscsi
   echo "UUID=$UUID /mnt/iscsi xfs _netdev,nofail 0 0" |
     sudo tee -a /etc/fstab
   sudo mount /mnt/iscsi
   sudo systemctl daemon-reload
   sudo findmnt --verify
   ```

## Verification

On node 2:

```bash
lsblk -o NAME,TRAN,SIZE,MOUNTPOINT
sudo iscsiadm -m node -T $IQN -p 172.25.250.10 | grep startup
```

On the workstation:

```bash
labctl grade storage-09
```

## Explanation

targetcli configures the LIO target in the kernel. A fileio backstore
keeps the data of a LUN in a file; targetcli creates the file sparse
by default, so it uses disk space on node 1 only as data is written.
The target portal group tpg1 ties the LUNs, the ACLs and the portals
together. A new target gets a portal on 0.0.0.0, port 3260, and a new
ACL maps every existing LUN, so creating the LUN before the ACL saves
a step. The configuration lives in the kernel until saveconfig writes
it to /etc/target/saveconfig.json, which target.service loads at boot.

The ACL admits only the initiator with the IQN it names. iscsid sends
the name from /etc/iscsi/initiatorname.iscsi, and it reads the file
only when it starts, hence the restart after the change. A login with
the wrong name fails with an authorization error. The default
node.startup in /etc/iscsi/iscsid.conf is automatic on Rocky Linux 8
and 9, so a discovered node record already logs in at boot through
iscsi.service; the update in step 8 makes that explicit.

The disk name such as sdb depends on the order in which disks appear,
so the fstab entry uses the UUID. _netdev orders the mount after the
network and the iSCSI login, and nofail keeps a boot going when node 1
is down. findmnt --verify checks every fstab line, including that the
UUID exists. The same commands work on Rocky Linux 8 and 9.
