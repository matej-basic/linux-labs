# storage-02: LVM basics on a loopback device

## Hints

1. LVM works on block devices, so the image file needs a loop device
   first. After that the order is physical volume, volume group,
   logical volume, file system.
2. See man losetup for the options that pick a free loop device and
   print its name. Then man pvcreate, man vgcreate and man lvcreate.
3. The file system goes on the logical volume under /dev/datavg, not
   on the image. For lvcreate, the options -L and -n set size and name.
4. Set the mode 755 after mounting, because before the mount it only
   changes the empty directory underneath.

## Solution

1. [sudo] Create the 100 MB image and attach it to a free loop device.
   Keep the terminal open: the next steps use the variable LOOP.

   ```bash
   sudo fallocate -l 100M /tmp/lvm.img
   LOOP=$(sudo losetup --find --show /tmp/lvm.img)
   echo "$LOOP"
   ```

2. [sudo] Initialise the loop device as a physical volume:

   ```bash
   sudo pvcreate "$LOOP"
   ```

3. [sudo] Create the volume group datavg on it:

   ```bash
   sudo vgcreate datavg "$LOOP"
   ```

4. [sudo] Create the 80 MB logical volume vol0:

   ```bash
   sudo lvcreate -L 80M -n vol0 datavg
   ```

5. [sudo] Create the ext4 file system:

   ```bash
   sudo mkfs.ext4 /dev/datavg/vol0
   ```

6. [sudo] Create the mount point, mount the volume and set the mode:

   ```bash
   sudo mkdir -p /mnt/lvm
   sudo mount /dev/datavg/vol0 /mnt/lvm
   sudo chmod 755 /mnt/lvm
   ```

## Verification

```bash
sudo pvs
sudo vgs datavg
sudo lvs datavg
df -h /mnt/lvm
labctl grade storage-02
```

## Explanation

A loop device turns the image file into a block device, so LVM can use
it like a disk. pvcreate writes the LVM label, vgcreate pools the
physical volume into datavg, and lvcreate carves vol0 out of the pool.
The volume group uses 4 MiB extents, so the 100 MB image gives 24
extents (96 MiB) and the 80 MB volume takes 20 of them.

The file system is created on the logical volume, not on the image.
chmod must run after the mount: before it, it would change the empty
directory underneath, while the mounted file system root keeps the mode
mkfs gave it.
