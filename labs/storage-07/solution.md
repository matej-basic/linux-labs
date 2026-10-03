# storage-07: Encrypted LUKS volume unlocked at boot by a key file

## Hints

1. Work from the bottom up: the LUKS header on the loop device, then
   the opened mapping, then the file system, then the two files that
   describe both layers for the boot.
2. The command cryptsetup formats, opens and closes LUKS volumes and
   adds key slots. Read man cryptsetup, the actions luksFormat, open
   and luksAddKey, and the options for the key derivation memory. On
   Rocky Linux 9 each action has its own page, such as
   man cryptsetup-luksFormat.
3. A key file is just random bytes. Create the directory and the file
   with strict permissions before you add the file as a key slot.
4. In /etc/crypttab the fields are the mapping name, the device, the
   key file and the options. The command blkid shows the UUID of the
   LUKS header on the loop device and the UUID of the XFS file system
   inside the mapping. Reload systemd after editing both files.

## Solution

1. [user] Read the name of the loop device:

   ```bash
   LOOP=$(head -n 1 /opt/linux-labs/state/storage-07)
   echo "$LOOP"
   lsblk "$LOOP"
   ```

2. [sudo] Install cryptsetup if it is missing:

   ```bash
   rpm -q cryptsetup || sudo dnf -y install cryptsetup
   ```

3. [sudo] Format the loop device as LUKS2 with the starting
   passphrase. cryptsetup reads the passphrase from standard input up
   to the line end. The memory option keeps the key derivation at
   64 MiB:

   ```bash
   sudo head -n 1 /root/luks-passphrase |
     sudo cryptsetup luksFormat -q --type luks2 \
       --pbkdf-memory 65536 "$LOOP"
   ```

4. [sudo] Create the key file and add it as a second key slot. The
   existing passphrase authorises the new slot:

   ```bash
   sudo mkdir -p /etc/luks-keys
   sudo chmod 0700 /etc/luks-keys
   sudo dd if=/dev/urandom of=/etc/luks-keys/secret.key bs=512 count=1
   sudo chmod 0400 /etc/luks-keys/secret.key
   sudo head -n 1 /root/luks-passphrase |
     sudo cryptsetup luksAddKey -q --pbkdf-memory 65536 "$LOOP" \
       /etc/luks-keys/secret.key
   ```

5. [sudo] Open the volume with the key file and create the file
   system:

   ```bash
   sudo cryptsetup open --key-file /etc/luks-keys/secret.key \
     "$LOOP" securedata
   sudo mkfs.xfs -L SECURE /dev/mapper/securedata
   ```

6. [sudo] Add the crypttab and fstab entries:

   ```bash
   LUKS_UUID=$(sudo blkid -p -o value -s UUID "$LOOP")
   echo "securedata UUID=$LUKS_UUID /etc/luks-keys/secret.key nofail" |
     sudo tee -a /etc/crypttab
   echo "/dev/mapper/securedata /mnt/secure xfs defaults,nofail 0 0" |
     sudo tee -a /etc/fstab
   sudo systemctl daemon-reload
   ```

7. [sudo] Create the mount point and mount it from the fstab entry:

   ```bash
   sudo mkdir -p /mnt/secure
   sudo mount /mnt/secure
   ```

## Verification

```bash
sudo cryptsetup luksDump "$LOOP"
sudo cryptsetup status securedata
sudo findmnt --verify
systemctl status systemd-cryptsetup@securedata.service
labctl grade storage-07
```

## Explanation

LUKS keeps a header at the start of the device with up to 32 key
slots. Each slot holds the same volume key, encrypted with a key that
is derived from one passphrase or key file. That is why a key file can
be added in a second slot while the passphrase keeps working, and why
adding a slot needs an existing passphrase.

cryptsetup reads a passphrase from standard input up to the first line
end, but a key file is read in full, including any line end. The lab
passphrase file ends with a line end, so it must not be used as a key
file for slot 0.

LUKS2 derives slot keys with Argon2, which is designed to use a lot of
memory. On a small VM the default can take most of the RAM, so
--pbkdf-memory limits it to 64 MiB. Rocky Linux 8 (cryptsetup 2.3)
uses argon2i and Rocky Linux 9 uses argon2id; both commands are the
same.

/etc/crypttab names the encrypted device by the UUID of the LUKS
header, which blkid reports as TYPE crypto_LUKS. The XFS file system
inside has its own UUID. At boot, systemd-cryptsetup-generator turns
each crypttab line into a systemd-cryptsetup@<name>.service unit that
opens the mapping, and the fstab entry then mounts it. nofail matters
in both files: the loop device does not exist at boot, and without
nofail the boot would wait for it and stop in emergency mode.
