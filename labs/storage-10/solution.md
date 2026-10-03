# storage-10: Software RAID 1 with a hot spare and a disk replacement

## Hints

1. Work in layers: the array from the three loop devices, then the
   file system on the array, then the two files that describe both
   for the boot. Read the loop device names from the state file
   first.
2. The command mdadm creates, inspects and changes md arrays. Read
   man mdadm: the create mode with its options for the level, the
   number of active devices, the spares, the metadata and the name,
   and the manage mode for faulty, remove and add.
3. The detail mode of mdadm prints an ARRAY line in the format of
   /etc/mdadm.conf. The file /proc/mdstat shows the state of each
   array and the progress of a rebuild, and mdadm has an option that
   waits for it to finish.
4. In /etc/fstab use the UUID of the XFS file system, which blkid
   shows, not the UUID of the array. Reload systemd after editing the
   file and let findmnt verify it.

## Solution

1. [user] Read the names of the three loop devices:

   ```bash
   D1=$(sed -n 1p /opt/linux-labs/state/storage-10)
   D2=$(sed -n 2p /opt/linux-labs/state/storage-10)
   D3=$(sed -n 3p /opt/linux-labs/state/storage-10)
   echo "$D1 $D2 $D3"
   lsblk "$D1" "$D2" "$D3"
   ```

2. [sudo] Install mdadm if it is missing:

   ```bash
   rpm -q mdadm || sudo dnf -y install mdadm
   ```

3. [sudo] Create the RAID 1 array with two active devices and one
   spare, and wait for the initial sync:

   ```bash
   sudo mdadm --create /dev/md/labraid --run --level=1 \
     --metadata=1.2 --name=labraid --raid-devices=2 "$D1" "$D2" \
     --spare-devices=1 "$D3"
   sudo mdadm --wait /dev/md/labraid
   cat /proc/mdstat
   ```

4. [sudo] Create the file system, the fstab entry and the mount point,
   mount it and write the test file:

   ```bash
   sudo mkfs.xfs -L RAIDDATA /dev/md/labraid
   U=$(sudo blkid -p -o value -s UUID /dev/md/labraid)
   echo "UUID=$U /mnt/raid xfs defaults,nofail 0 0" |
     sudo tee -a /etc/fstab
   sudo systemctl daemon-reload
   sudo mkdir -p /mnt/raid
   sudo mount /mnt/raid
   echo "Written before the disk failure" |
     sudo tee /mnt/raid/before.txt
   ```

5. [sudo] Record the array in /etc/mdadm.conf:

   ```bash
   sudo mdadm --detail --brief /dev/md/labraid |
     sudo tee -a /etc/mdadm.conf
   ```

6. [sudo] Fail and remove the device from line 2, then wait until the
   spare has been rebuilt:

   ```bash
   sudo mdadm /dev/md/labraid --fail "$D2"
   sudo mdadm /dev/md/labraid --remove "$D2"
   sudo mdadm --wait /dev/md/labraid
   cat /proc/mdstat
   ```

7. [sudo] Add the device from line 2 back as the new spare:

   ```bash
   sudo mdadm /dev/md/labraid --add "$D2"
   sudo mdadm --detail /dev/md/labraid
   ```

## Verification

```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md/labraid
cat /mnt/raid/before.txt
sudo findmnt --verify
labctl grade storage-10
```

## Explanation

mdadm writes a superblock to every member. With metadata 1.2 it sits
4 KiB from the start of each device and stores the array UUID and its
name. The name gets the host name as a prefix, so mdadm --detail
shows servera:labraid, and udev links /dev/md/labraid to the real
device, usually /dev/md127. The option --run skips the question
mdadm asks when a device looks used.

A hot spare is a member without a slot. When an active member fails,
the kernel starts a recovery onto the spare at once; /proc/mdstat
shows its progress and mdadm --wait blocks until it is done. A device
must be marked faulty before it can be removed. A disk added to an
array that is not degraded becomes a spare, which is why the old
disk from line 2 returns as the new hot spare. mdadm --wait may exit
with status 1 when nothing was running.

/etc/mdadm.conf lets mdadm assemble the array by its UUID under the
same name at boot, and the fstab entry mounts the XFS file system by
its own UUID, which is a different value. nofail matters here: at
boot the loop devices do not exist, and without nofail the boot would
wait for them and stop in emergency mode. The same commands work on
Rocky Linux 8 (mdadm 4.2) and 9.
