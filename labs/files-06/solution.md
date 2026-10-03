# files-06: Archives and rsync transfer between nodes

## Hints

1. Some files are readable only by root, and only root can set the
   owner of an extracted or copied file. Run tar and rsync as root,
   on both ends of the transfer.
2. In man tar, look for the option that changes to a directory before
   the archive is created, and for the option that selects xz. Inside
   the archive the paths are relative to that directory.
3. rsync must be installed on node 1 and on node 2. Its archive mode
   keeps modes, owners, groups and times, and it has an option that
   leaves out files by a pattern.
4. With sudo, rsync starts ssh as root, which has no key for node 2.
   The rsync options -e and --rsync-path choose the ssh command with
   its key and the remote command, which can start with sudo.

## Solution

1. [user] From the workstation, log in to node 1 as opsadmin. Use the
   node 1 address from the TOPOLOGY section of the task:

   ```bash
   ssh opsadmin@172.25.250.10
   ```

2. [sudo] On node 1, set the node 2 address and install rsync on both
   nodes where it is missing. The first connection to node 2 asks to
   confirm its host key; answer yes:

   ```bash
   N2=172.25.250.11
   rpm -q rsync || sudo dnf -y install rsync
   ssh "$N2" 'rpm -q rsync || sudo dnf -y install rsync'
   ```

3. [sudo] Create the archive from /srv, so that the member names
   start with projects/, and list it:

   ```bash
   sudo tar -C /srv -cJf /srv/projects.tar.xz projects
   sudo tar -tvJf /srv/projects.tar.xz
   ```

4. [sudo] Copy the tree to node 2 without the .tmp files. The source
   has no trailing slash, so rsync creates /srv/backup/projects:

   ```bash
   sudo rsync -a --exclude='*.tmp' \
     -e 'ssh -i /home/opsadmin/.ssh/id_ed25519' \
     --rsync-path='sudo rsync' \
     /srv/projects "opsadmin@$N2:/srv/backup/"
   ```

5. [sudo] Extract the archive into /srv/restore:

   ```bash
   sudo tar -C /srv/restore -xJf /srv/projects.tar.xz
   ```

## Verification

```bash
sudo ls -lR /srv/restore/projects
ssh "$N2" 'sudo ls -lR /srv/backup/projects'
labctl grade files-06
```

Run labctl grade on the workstation.

## Explanation

tar stores the owner, group, mode and modification time of every
member. When root extracts the archive, tar sets all of them again, so
`sudo` matters for both steps: as opsadmin the 0600 and 0750 entries of
beta cannot be read, and an extracted file would belong to opsadmin.
`-C /srv` makes tar work relative to /srv, so the members are
`projects/...` instead of `srv/projects/...`, and the same option on
extraction puts the copy below /srv/restore. `-J` selects xz; the file
starts with the xz magic bytes, whatever its name.

`rsync -a` is short for `-rlptgoD`: recursive, symbolic links,
permissions, times, group, owner and devices. Owners and groups are
set only when the receiving rsync runs as root, which is what
`--rsync-path='sudo rsync'` does on node 2. The local `sudo` lets
rsync read every file, but its ssh then runs as root, so `-e` names
the opsadmin key explicitly. rsync matches owners by name, and the lab
users have the same IDs on both nodes anyway. `--exclude='*.tmp'`
skips the three temporary files. Without the trailing slash on the
source, rsync copies the directory itself into /srv/backup; with
`/srv/projects/` the contents would land directly in /srv/backup.
