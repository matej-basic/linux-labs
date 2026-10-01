# storage-03: LVM snapshots on a loopback volume group

## Solution

1. [sudo] Create the image and attach it to a loop device:

   ```bash
   sudo fallocate -l 150M /tmp/snap.img
   LOOP=$(sudo losetup --find --show /tmp/snap.img)
   echo "$LOOP"
   ```

2. [sudo] Create the physical volume and the volume group:

   ```bash
   sudo pvcreate "$LOOP"
   sudo vgcreate snapvg "$LOOP"
   ```

3. [sudo] Create the 100 MiB logical volume, format it and mount it:

   ```bash
   sudo lvcreate -L 100M -n original snapvg
   sudo mkfs.ext4 /dev/snapvg/original
   sudo mkdir -p /mnt/original /mnt/snap1
   sudo mount /dev/snapvg/original /mnt/original
   ```

4. [sudo] Write the data that must be in the snapshot:

   ```bash
   echo "before snapshot" | sudo tee /mnt/original/before.txt
   ```

5. [sudo] Create the snapshot and mount it:

   ```bash
   sudo lvcreate -L 20M -s -n snap1 /dev/snapvg/original
   sudo mount /dev/snapvg/snap1 /mnt/snap1
   ```

6. [sudo] Create the file that only the origin gets:

   ```bash
   echo "after snapshot" | sudo tee /mnt/original/testfile.txt
   ```

## Verification

```bash
sudo lvs snapvg
ls /mnt/original /mnt/snap1
labctl grade storage-03
```

## Explanation

A snapshot is copy on write. When original changes, LVM first copies
the old blocks into the snapshot's 20 MiB area, so /mnt/snap1 keeps
the state from the moment of the snapshot. testfile.txt was created
afterwards and does not appear there.

The snapshot area is a limit, not a copy of the volume. If more than
20 MiB of blocks change in original, the snapshot becomes invalid and
the grader reports it. The snapshot of a mounted ext4 file system
mounts without extra options because ext4 tolerates the duplicate
UUID. The loop device is gone after a reboot, which is why the lab
needs no fstab entries.
