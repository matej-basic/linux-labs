#!/bin/bash
# Reference solution for storage-07, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/storage-07.img
# solve: path /mnt/secure
# solve: path /etc/luks-keys
# solve: path /root/luks-passphrase
# solve: path /dev/mapper/securedata
# solve: package cryptsetup
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
LOOP=$(head -n 1 /opt/linux-labs/state/storage-07)
run_as_student "lsblk $LOOP"

# Step 2 [sudo]
rpm -q cryptsetup >/dev/null || dnf -y install cryptsetup >/dev/null

# Step 3 [sudo]
head -n 1 /root/luks-passphrase |
	cryptsetup luksFormat -q --type luks2 --pbkdf-memory 65536 "$LOOP"

# Step 4 [sudo]
mkdir -p /etc/luks-keys
chmod 0700 /etc/luks-keys
dd if=/dev/urandom of=/etc/luks-keys/secret.key bs=512 count=1 status=none
chmod 0400 /etc/luks-keys/secret.key
head -n 1 /root/luks-passphrase |
	cryptsetup luksAddKey -q --pbkdf-memory 65536 "$LOOP" \
		/etc/luks-keys/secret.key

# Step 5 [sudo]
cryptsetup open --key-file /etc/luks-keys/secret.key "$LOOP" securedata
mkfs.xfs -q -L SECURE /dev/mapper/securedata

# Step 6 [sudo]
LUKS_UUID=$(blkid -p -o value -s UUID "$LOOP")
echo "securedata UUID=$LUKS_UUID /etc/luks-keys/secret.key nofail" >> /etc/crypttab
echo "/dev/mapper/securedata /mnt/secure xfs defaults,nofail 0 0" >> /etc/fstab
systemctl daemon-reload

# Step 7 [sudo]
mkdir -p /mnt/secure
mount /mnt/secure

# Verification
findmnt --verify
