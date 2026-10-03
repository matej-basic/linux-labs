# storage-11: Full file system and a broken fstab entry

## Hints

1. The use that df reports counts every allocated block, while du adds
   up only the files it can reach by name. Let du list every file to
   see where the visible space goes, including directories whose names
   start with a dot, which ls hides. Whatever df counts beyond that
   belongs to files that no longer have a name.
2. A deleted file keeps its blocks while a process still has it open.
   Every process lists its open files as links under /proc/<pid>/fd,
   and the target of a deleted one ends in (deleted). The space comes
   back when the process closes the file, for a service when it is
   restarted.
3. The command findmnt has a mode that checks /etc/fstab and names the
   field that is wrong. Compare the type in the entry with the type
   that blkid finds in the image.
4. After editing /etc/fstab, reload systemd, then mount the file
   system by its mount point only, so that the entry itself is used.

## Solution

1. [sudo] Compare what df and du report for /srv/appdata:

   ```bash
   df -h /srv/appdata
   sudo du -sh /srv/appdata
   sudo du -ah /srv/appdata | sort -h | tail -n 5
   ```

2. [sudo] Delete the dump in the hidden cache directory:

   ```bash
   sudo ls -la /srv/appdata/.cache
   sudo rm -f /srv/appdata/.cache/core.*
   ```

3. [sudo] Find the process that keeps a deleted file open, and restart
   the service it belongs to:

   ```bash
   sudo find /proc/[0-9]*/fd -lname '/srv/appdata/*(deleted)' \
     -printf '%h %l\n' 2>/dev/null
   systemctl status app-logger.service
   sudo systemctl restart app-logger.service
   df -h /srv/appdata
   ```

4. [sudo] Check /etc/fstab and the real type of the archive image:

   ```bash
   sudo findmnt --verify
   sudo blkid /srv/storage-11-archive.img
   ```

5. [sudo] Change the type in the /srv/archive entry from ext4 to xfs,
   reload systemd and mount the file system from its entry:

   ```bash
   sudo sed -i '/ \/srv\/archive /s/ ext4 / xfs /' /etc/fstab
   sudo systemctl daemon-reload
   sudo findmnt --verify
   sudo mount /srv/archive
   ls -lR /srv/archive
   ```

## Verification

```bash
df -h /srv/appdata /srv/archive
sudo du -sh /srv/appdata
systemctl is-active app-logger.service
sudo findmnt --verify
labctl grade storage-11
```

## Explanation

df asks the file system how many blocks are allocated, du walks the
directory tree and adds up the files it finds. Two things make them
disagree here. A 70 MiB core dump sits in /srv/appdata/.cache, a
directory that ls hides without the option -a, although du counts
it. And a 70 MiB log was deleted while app-logger still had it open:
the name is gone, so du cannot see it, but the inode and its blocks
stay until the last open file descriptor is closed. The link under
/proc/<pid>/fd shows the old path with (deleted) appended. Restarting
the service closes the descriptor, frees the blocks and opens a new
log. Emptying the file through /proc/<pid>/fd would free the space
as well, but the deleted file would stay open. lsof +L1 lists the
same files when lsof is installed.

The archive entry named the type ext4 while the image holds XFS.
findmnt --verify reads the on-disk type and reports the mismatch as
an error, and mount refuses the file system. A wrong image path would
only be a warning there, because of nofail. After the change, systemd
must reload its generated mount units, and mount with only the mount
point uses the fstab entry, which also sets up the loop device. The
same commands work on Rocky Linux 8 (util-linux 2.32) and 9 (2.37).
