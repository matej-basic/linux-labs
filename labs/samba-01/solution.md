# samba-01: Samba file sharing with a persistent CIFS mount

## Hints

1. Node 1 needs the package samba, a share section in the Samba
   configuration, a Samba password for smbuser, the right SELinux type
   on the directory, an open firewall and the running service smb.
   Node 2 needs cifs-utils, the credentials file, the mount point and
   the fstab entry.
2. A share is a section in /etc/samba/smb.conf named after the share.
   Read man smb.conf for the parameters path, writable and valid
   users; a group name in valid users starts with @. The command
   testparm checks the file.
3. Samba keeps its own passwords: the command smbpasswd adds a Samba
   account for an existing Linux user. For SELinux, read man
   semanage-fcontext for a rule with the type samba_share_t, then
   apply it with restorecon.
4. The description of the option credentials in man mount.cifs shows
   the format of the credentials file. In the fstab entry the options
   field is a comma-separated list, and man systemd.mount explains
   _netdev.

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

2. [user] Install samba and the SELinux management tools on node 1
   and cifs-utils on node 2 where they are missing:

   ```bash
   run_on_node "$N1" "rpm -q samba policycoreutils-python-utils ||
     sudo -n dnf -y install samba policycoreutils-python-utils"
   run_on_node "$N2" \
     "rpm -q cifs-utils || sudo -n dnf -y install cifs-utils"
   ```

3. [user] Add the share [team] to the Samba configuration of node 1
   and check it:

   ```bash
   printf '%s\n' "" "[team]" \
     "        path = /srv/samba/team" \
     "        writable = yes" \
     "        valid users = @smbteam" |
     run_on_node "$N1" "sudo -n tee -a /etc/samba/smb.conf"
   run_on_node "$N1" "testparm -s --section-name=team"
   ```

4. [user] Give the directory the type samba_share_t with a file
   context rule and relabel it:

   ```bash
   run_on_node "$N1" "sudo -n semanage fcontext -a \
     -t samba_share_t '/srv/samba/team(/.*)?'"
   run_on_node "$N1" "sudo -n restorecon -Rv /srv/samba/team"
   ```

5. [user] Add the Samba account of smbuser. The option -s reads the
   password twice from standard input; interactively, run
   smbpasswd -a smbuser and type it:

   ```bash
   printf '%s\n' Smb.Team.2468 Smb.Team.2468 |
     run_on_node "$N1" "sudo -n smbpasswd -s -a smbuser"
   run_on_node "$N1" "sudo -n pdbedit -L"
   ```

6. [user] Start smb on node 1, enable it at boot and open the
   firewall:

   ```bash
   run_on_node "$N1" "sudo -n systemctl enable --now smb"
   run_on_node "$N1" \
     "sudo -n firewall-cmd --permanent --add-service=samba"
   run_on_node "$N1" "sudo -n firewall-cmd --reload"
   ```

7. [user] On node 2, write the credentials file readable only by
   root:

   ```bash
   printf '%s\n' username=smbuser password=Smb.Team.2468 |
     run_on_node "$N2" \
     "sudo -n sh -c 'umask 077; cat > /root/team.creds'"
   run_on_node "$N2" "sudo -n ls -l /root/team.creds"
   ```

8. [user] Create the mount point, add the fstab entry and mount it:

   ```bash
   run_on_node "$N2" "sudo -n mkdir -p /mnt/team"
   OPTS=credentials=/root/team.creds,_netdev
   echo "//$N1/team /mnt/team cifs $OPTS 0 0" |
     run_on_node "$N2" "sudo -n tee -a /etc/fstab"
   run_on_node "$N2" "sudo -n systemctl daemon-reload"
   run_on_node "$N2" "sudo -n mount /mnt/team"
   ```

## Verification

A file written on node 2 belongs to smbuser on node 1:

```bash
run_on_node "$N2" "findmnt /mnt/team"
run_on_node "$N2" "sudo -n touch /mnt/team/from-node2"
run_on_node "$N1" "ls -lZ /srv/samba/team"
labctl grade samba-01
```

## Explanation

Samba authenticates SMB clients against its own password database,
not against /etc/shadow, so smbuser needs a Linux account and a Samba
account. smbd then works as that Linux user: files created through the
share belong to smbuser on node 1, whatever user wrote them on node 2.
valid users = @smbteam lets only members of the group connect, and the
setgid bit of the directory gives new files the group smbteam.

SELinux lets smbd read and write only files of the type samba_share_t
(or the booleans samba_export_all_ro and samba_export_all_rw, which
open much more). chcon alone changes the label until the next relabel;
the rule from semanage fcontext puts it in the policy, and restorecon
applies it. matchpathcon shows the type the policy wants for a path.

The credentials file keeps the password out of /etc/fstab, which every
user can read. _netdev marks the mount as a network file system, so
systemd mounts it after the network is up. The fstab entry, the share
and the commands are the same on Rocky Linux 8 and 9; both mount with
SMB version 3 by default.
