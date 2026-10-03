# storage-06: GPT partitions, swap and file systems mounted by UUID

## Hints

1. Work in three layers: the partition table, then what each
   partition holds, then how the system finds it again. Read the
   loop device name from the state file first.
2. The command parted writes a GPT label and creates partitions with
   start and end positions in MiB. Start the first partition at
   1 MiB. Read man parted.
3. Each partition gets its contents from its own tool: mkfs.xfs (with
   an option for the label), mkswap and mkfs.vfat from dosfstools.
   The command blkid prints the UUID of each one.
4. In /etc/fstab the swap entry has none as its mount point. After
   editing the file, reload systemd and let findmnt verify the file.

## Solution

1. [user] Read the name of the loop device and look at it:

   ```bash
   LOOP=$(head -n 1 /opt/linux-labs/state/storage-06)
   echo "$LOOP"
   lsblk "$LOOP"
   ```

2. [sudo] Write a GPT label and the three partitions: 300 MiB, 128 MiB
   for swap, 100 MiB. Wait for udev to create the device nodes:

   ```bash
   sudo parted -s "$LOOP" mklabel gpt \
     mkpart archive xfs 1MiB 301MiB \
     mkpart swap linux-swap 301MiB 429MiB \
     mkpart exchange fat32 429MiB 529MiB
   sudo udevadm settle
   lsblk "$LOOP"
   ```

3. [sudo] Install dosfstools if it is missing:

   ```bash
   rpm -q dosfstools || sudo dnf -y install dosfstools
   ```

4. [sudo] Create the XFS file system with the label ARCHIVE, the swap
   area and the vfat file system:

   ```bash
   sudo mkfs.xfs -L ARCHIVE "${LOOP}p1"
   sudo mkswap "${LOOP}p2"
   sudo mkfs.vfat "${LOOP}p3"
   ```

5. [sudo] Read the three UUIDs and add the fstab entries:

   ```bash
   U1=$(sudo blkid -p -o value -s UUID "${LOOP}p1")
   U2=$(sudo blkid -p -o value -s UUID "${LOOP}p2")
   U3=$(sudo blkid -p -o value -s UUID "${LOOP}p3")
   echo "UUID=$U1 /mnt/archive xfs defaults,nofail 0 0" |
     sudo tee -a /etc/fstab
   echo "UUID=$U2 none swap defaults,nofail 0 0" |
     sudo tee -a /etc/fstab
   echo "UUID=$U3 /mnt/exchange vfat defaults,nofail 0 0" |
     sudo tee -a /etc/fstab
   sudo systemctl daemon-reload
   ```

6. [sudo] Create the mount points and activate everything from the
   fstab entries:

   ```bash
   sudo mkdir -p /mnt/archive /mnt/exchange
   sudo mount /mnt/archive
   sudo mount /mnt/exchange
   sudo swapon -a
   ```

## Verification

```bash
sudo findmnt --verify
swapon --show
findmnt /mnt/archive
findmnt /mnt/exchange
labctl grade storage-06
```

## Explanation

parted with the -s option runs without questions. In GPT mode the
first word after mkpart is the partition name, and the file system
word only sets the partition type: linux-swap gives partition 2 the
Linux swap type. Starting at 1 MiB keeps the partitions aligned. The
kernel learns the new partitions because the lab attached the image
with partition scanning; without it the loop device would show no
partitions at all.

The UUID belongs to the file system or swap area, not to the
partition, so it changes when the partition is formatted again. A
vfat UUID is the short volume serial number, such as 1A2B-3C4D, and
fstab must carry it in exactly that form. The swap entry uses none
as its mount point. Mounting through the mount points alone, and
swapon -a, prove that the entries work.

nofail matters here: at boot the loop device does not exist, and
without nofail the boot would wait for the missing devices and stop
in emergency mode. findmnt --verify checks every line of fstab,
including that each UUID resolves to a device. The same commands
work on Rocky Linux 8 and 9; on 9, mkfs.xfs refuses file systems
smaller than 300 MiB.
