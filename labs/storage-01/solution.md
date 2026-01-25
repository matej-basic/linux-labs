# Solution: storage-01 (Loopback filesystem)

```bash
# 1) Create a 100MB image
fallocate -l 100M /tmp/disk.img

# 2) Make ext4
mkfs.ext4 -F /tmp/disk.img

# 3) Mount at /mnt/data
sudo mkdir -p /mnt/data
sudo mount -o loop /tmp/disk.img /mnt/data
sudo chmod 755 /mnt/data

# 4) Persist via fstab (use UUID)
UUID=$(blkid -s UUID -o value /tmp/disk.img)
echo "UUID=${UUID} /mnt/data ext4 loop 0 0" | sudo tee -a /etc/fstab

# 5) Verify
mountpoint /mnt/data
stat -c %a /mnt/data
df -h /mnt/data
```
