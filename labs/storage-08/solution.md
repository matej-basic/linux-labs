# storage-08: User and group disk quotas on an XFS file system

## Hints

1. Work in order: file system, persistent mount with the quota
   options, then the limits. XFS reads the quota options only at
   mount time.
2. The fstab entry for an image file is like one for a disk, with
   the image path as the source and loop among the options. Read
   man xfs for the names of the quota mount options.
3. The command xfs_quota changes limits only in expert mode. Its
   state command shows whether accounting and enforcement are on,
   and its limit command takes values such as bhard=100m.
4. A directory where new files inherit its group has the setgid bit,
   the 2 in front of the mode 770.

## Solution

1. [sudo] Create the XFS file system in the image:

   ```bash
   sudo mkfs.xfs /srv/storage-08.img
   ```

2. [sudo] Create the mount point, add the fstab entry and mount the
   image through it:

   ```bash
   sudo mkdir -p /srv/projects
   OPTS=loop,usrquota,grpquota,nofail
   echo "/srv/storage-08.img /srv/projects xfs $OPTS 0 0" |
     sudo tee -a /etc/fstab
   sudo systemctl daemon-reload
   sudo mount /srv/projects
   ```

3. [sudo] Check that user and group quotas are on:

   ```bash
   sudo xfs_quota -x -c state /srv/projects
   ```

4. [sudo] Set the limits for qalice, qbob and qteam:

   ```bash
   sudo xfs_quota -x \
     -c 'limit -u bsoft=80m bhard=100m ihard=1000 qalice' /srv/projects
   sudo xfs_quota -x -c 'limit -u bhard=50m qbob' /srv/projects
   sudo xfs_quota -x -c 'limit -g bhard=200m qteam' /srv/projects
   ```

5. [sudo] Create the shared directory of the group:

   ```bash
   sudo mkdir /srv/projects/team
   sudo chgrp qteam /srv/projects/team
   sudo chmod 2770 /srv/projects/team
   ```

## Verification

```bash
sudo xfs_quota -x -c 'report -u -g -bi -h' /srv/projects
sudo findmnt --verify
ls -ld /srv/projects/team
labctl grade storage-08
```

## Explanation

mkfs.xfs formats a regular file directly, and the option loop in
fstab makes mount attach a loop device to the image. On XFS, quotas
are part of the file system journal state and are switched on at
mount time by usrquota and grpquota (or uquota and gquota). A remount
with new quota options is ignored, so a mount made without them must
be unmounted first. The state command of xfs_quota shows Accounting
and Enforcement for each quota type.

The limit command needs expert mode (-x). Units such as m are
binary, so 100m is 102400 KiB, which is what the report shows. bsoft
can be passed for a grace period; bhard is the point where writes
fail with Disk quota exceeded. The grader checks that by writing as
qbob.

The setgid bit on /srv/projects/team gives new files the group qteam,
so their blocks count against the group limit of qteam as well as
the user limit of their owner. The same commands work on Rocky Linux
8 (xfsprogs 5.0) and 9 (xfsprogs 6.x).
