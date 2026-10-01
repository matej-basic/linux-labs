# storage-01: Loopback filesystem with persistent mount

## Solution

1. [sudo] Create the 100 MiB image:

   ```bash
   sudo fallocate -l 100M /srv/disk.img
   ```

2. [sudo] Format it as ext4 (-F because the target is a regular file):

   ```bash
   sudo mkfs.ext4 -F /srv/disk.img
   ```

3. [sudo] Create the mount point and mount the image through a loop
   device:

   ```bash
   sudo mkdir -p /mnt/data
   sudo mount -o loop /srv/disk.img /mnt/data
   sudo chmod 755 /mnt/data
   ```

4. [sudo] Add the persistent entry, with the image path as the source:

   ```bash
   echo '/srv/disk.img /mnt/data ext4 loop,nofail 0 0' |
     sudo tee -a /etc/fstab
   sudo systemctl daemon-reload
   ```

## Verification

```bash
sudo umount /mnt/data
sudo mount -a
findmnt /mnt/data
df -h /mnt/data
stat -c %a /mnt/data
labctl grade storage-01
```

## Explanation

A file only becomes a block device when losetup attaches it, so an
fstab line with `UUID=` of the filesystem inside the image cannot be
resolved at boot: the UUID does not exist until the loop device does.
Using the image path as the source lets mount attach the loop device
itself.

The image lives in /srv because systemd-tmpfiles empties /tmp at boot
on Rocky Linux. With the image gone, a mount entry without nofail
could drop the system into emergency mode. The option nofail turns
that into a skipped mount.

The mode 755 applies to the root directory of the ext4 filesystem once
it is mounted; the permissions of the empty directory underneath are
hidden by the mount. Run chmod after mounting.
