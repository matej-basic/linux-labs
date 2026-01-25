# Solution: storage-03 (LVM snapshots)

```bash
# 1) Create 150MB image and loop (need extra for LVM overhead)
fallocate -l 150M /tmp/snap.img
LOOP=$(sudo losetup --find --show /tmp/snap.img)

# 2) LVM setup
sudo pvcreate "$LOOP"
sudo vgcreate snapvg "$LOOP"
sudo lvcreate -L 100M -n original snapvg

# 3) Filesystem and mount
sudo mkfs.ext4 -F /dev/snapvg/original
sudo mkdir -p /mnt/original /mnt/snap1
sudo mount /dev/snapvg/original /mnt/original

# 4) Create snapshot
sudo lvcreate -L 20M -s -n snap1 /dev/snapvg/original
sudo mount /dev/snapvg/snap1 /mnt/snap1

# 5) Demonstrate snapshot behavior
sudo sh -c 'echo after-snapshot > /mnt/original/testfile.txt'
# testfile should NOT appear in the snapshot view
ls /mnt/snap1/testfile.txt  # should fail/not exist

# 6) Verify
pvs; vgs snapvg; lvs snapvg
mountpoint /mnt/original
mountpoint /mnt/snap1
df -h /mnt/original
```
