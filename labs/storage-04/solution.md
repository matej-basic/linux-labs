# storage-04: Swap file, swappiness and a tuned profile

## Hints

1. A swap file is a regular file of the right size with a swap
   signature written into it. The kernel refuses a file with holes,
   so write the whole file instead of only reserving its size.
2. Read man mkswap and man swapon: swapon has an option for the
   priority, and in /etc/fstab the same priority goes into the
   options field as pri=10.
3. Kernel parameters persist through a key = value line in a .conf
   file under /etc/sysctl.d. The command sysctl can load such a file
   right away.
4. The command tuned-adm lists the profiles, selects one and shows
   the active one. Remember to enable the tuned service as well.

## Solution

1. [sudo] Create the 512 MiB file with real data blocks and set its
   owner and mode:

   ```bash
   sudo dd if=/dev/zero of=/swapfile bs=1M count=512
   sudo chown root:root /swapfile
   sudo chmod 600 /swapfile
   ```

2. [sudo] Write the swap signature and activate the file with
   priority 10:

   ```bash
   sudo mkswap /swapfile
   sudo swapon -p 10 /swapfile
   swapon --show
   ```

3. [sudo] Add the persistent entry:

   ```bash
   echo '/swapfile none swap pri=10,nofail 0 0' |
     sudo tee -a /etc/fstab
   sudo systemctl daemon-reload
   ```

4. [sudo] Set vm.swappiness persistently and load the file:

   ```bash
   echo 'vm.swappiness = 20' |
     sudo tee /etc/sysctl.d/90-swappiness.conf
   sudo sysctl -p /etc/sysctl.d/90-swappiness.conf
   ```

5. [sudo] Install tuned if it is missing, enable and start it, and
   select the profile:

   ```bash
   rpm -q tuned || sudo dnf -y install tuned
   sudo systemctl enable --now tuned
   sudo tuned-adm profile throughput-performance
   tuned-adm active
   ```

6. [sudo] Check the swappiness again, because the profile sets it
   too, then reboot and connect again:

   ```bash
   sysctl vm.swappiness
   sudo systemctl reboot
   ```

## Verification

```bash
swapon --show
grep swap /etc/fstab
sysctl vm.swappiness
tuned-adm active
systemctl is-enabled tuned
labctl grade storage-04
```

## Explanation

The swap file is written with dd so that every block is allocated.
swapon rejects a file with holes, and on some filesystems also one
created by fallocate. Mode 600 keeps other users from reading memory
pages that were swapped out; swapon warns about insecure permissions
otherwise.

Swap areas with a higher priority are used first, and the existing
swap logical volume has a negative default priority, so pages go to
/swapfile before the logical volume. The volume group and its swap
logical volume stay untouched.

In /etc/fstab the mount point field of a swap entry is none and the
priority goes into the options as pri=10. A swap entry for a file
that is missing at boot only fails its own swap unit, and nofail
makes sure no other unit waits for it.

Both throughput-performance and virtual-guest set vm.swappiness
themselves. tuned reapplies the files from /etc/sysctl.d after its
own settings (reapply_sysctl in /etc/tuned/tuned-main.conf is on by
default), so the value 20 from 90-swappiness.conf wins at boot and
when the profile changes. tuned remembers the selected profile in
/etc/tuned/active_profile and applies it again when the service
starts at boot, which is why it must be enabled.

Rocky Linux 8 installs tuned with the profile virtual-guest on a
virtual machine; a minimal Rocky Linux 9 install may not have it,
and the solution installs it only when it is missing.
