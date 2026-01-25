# Solution: storage-02 (LVM basics)

```bash
# 1) Create 100MB loopback image
fallocate -l 100M /tmp/lvm.img

# 2) Attach loop device
LOOP=$(sudo losetup --find --show /tmp/lvm.img)

# 3) Build LVM
sudo pvcreate "$LOOP"
sudo vgcreate datavg "$LOOP"
sudo lvcreate -L 80M -n vol0 datavg

# 4) Filesystem and mount
sudo mkfs.ext4 -F /dev/datavg/vol0
sudo mkdir -p /mnt/lvm
sudo mount /dev/datavg/vol0 /mnt/lvm
sudo chmod 755 /mnt/lvm

# 5) Verify
pvs; vgs datavg; lvs /dev/datavg/vol0
df -h /mnt/lvm
```
