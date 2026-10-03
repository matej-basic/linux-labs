# storage-05: Extend LVM volumes and grow XFS and ext4 file systems

## Hints

1. The volume group needs more space first. A new disk joins a volume
   group as a physical volume, and a loop device makes an image file
   look like a disk. Read man losetup and man vgextend.
2. A logical volume and its file system are two layers. Making the
   volume bigger leaves the file system at its old size until it is
   grown as well.
3. XFS grows with xfs_growfs, which takes the mount point. ext4 grows
   with resize2fs, which takes the device and works while mounted.
4. The command lvextend has an option that grows the file system in
   the same step, for XFS and for ext4. Read man lvextend.

## Solution

1. [sudo] Look at the starting point:

   ```bash
   sudo vgs growvg
   sudo lvs growvg
   df -h /mnt/xfsdata /mnt/extdata
   ```

2. [sudo] Attach the second image to a loop device and add it to the
   volume group:

   ```bash
   LOOP=$(sudo losetup --find --show /srv/growvg/disk2.img)
   echo "$LOOP"
   sudo vgextend growvg "$LOOP"
   sudo pvs -S vg_name=growvg
   ```

3. [sudo] Extend xfslv to 512 MiB, then grow the XFS file system
   through its mount point:

   ```bash
   sudo lvextend -L 512M /dev/growvg/xfslv
   sudo xfs_growfs /mnt/xfsdata
   ```

4. [sudo] Extend extlv to 256 MiB and grow the ext4 file system in
   the same step:

   ```bash
   sudo lvextend -r -L 256M /dev/growvg/extlv
   ```

## Verification

```bash
sudo lvs growvg
df -h /mnt/xfsdata /mnt/extdata
labctl grade storage-05
```

## Explanation

vgextend turns the loop device into a physical volume if it is not one
yet, so pvcreate is optional here. After step 2 the volume group has
enough free extents for both extensions.

lvextend only changes the block device. The XFS file system stays at
320 MiB until xfs_growfs grows it to the end of the device. XFS can
only grow while mounted, and it cannot shrink. Step 4 shows the
shortcut: lvextend -r calls the right tool (resize2fs for ext4,
xfs_growfs for XFS) after it extends the volume. resize2fs grows a
mounted ext4 file system online. The same commands work on Rocky
Linux 8 and 9; on 9 LVM records the new loop device in its devices
file automatically.

df shows less than the volume size for XFS because the internal log
takes space. The grader reads the size from the superblock, compares
the file system UUIDs with the ones from the start and checks the
data files, so creating a new file system fails even at the right
size.
