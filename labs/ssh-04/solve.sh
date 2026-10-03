#!/bin/bash
# Reference solution for ssh-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Port 22 and the key logins of the task user stay as they are: the
# Match block applies to the group sftponly only, and sshd is reloaded
# only after sshd -t passes.
#
# solve: path /srv/sftp
# solve: path /home/ftpa
# solve: path /home/ftpb
# solve: path /home/opsadmin/sftp-lab.pub
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

KEY=/opt/linux-labs/state/ssh-04.d/sftp-lab
home=$(getent passwd "$SOLVE_USER" | cut -d: -f6)

# Step 1 [sudo]
groupadd sftponly
useradd -m -s /sbin/nologin -G sftponly ftpa
useradd -m -s /sbin/nologin -G sftponly ftpb
id ftpa
id ftpb

# Step 2 [sudo]
for u in ftpa ftpb; do
	install -d -m 0700 -o "$u" -g "$u" "/home/$u/.ssh"
	install -m 0600 -o "$u" -g "$u" "$home/sftp-lab.pub" \
		"/home/$u/.ssh/authorized_keys"
	restorecon -R "/home/$u/.ssh"
done

# Step 3 [sudo]
for u in ftpa ftpb; do
	mkdir -p "/srv/sftp/$u/upload"
	chmod 0755 /srv/sftp "/srv/sftp/$u"
	chown "$u:$u" "/srv/sftp/$u/upload"
	chmod 0755 "/srv/sftp/$u/upload"
done
ls -ld /srv /srv/sftp /srv/sftp/*/ /srv/sftp/*/upload

# Step 4 [sudo]
tee -a /etc/ssh/sshd_config >/dev/null <<'END'

Match Group sftponly
    ChrootDirectory /srv/sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
END
sshd -t
systemctl reload sshd
sleep 1

# Step 5 [sudo]
sshd -T -C user=ftpa,host=localhost,addr=127.0.0.1 |
	grep -E '^(chroot|forcecommand|allowtcp|x11forwarding)'
sshd -T -C user=ftpa,host=localhost,addr=127.0.0.1 |
	grep -x 'forcecommand internal-sftp' >/dev/null
sshd -T -C "user=$SOLVE_USER,host=localhost,addr=127.0.0.1" |
	grep -x 'chrootdirectory none' >/dev/null

# Step 6 [sudo]
out=$(sftp -i "$KEY" -o StrictHostKeyChecking=accept-new -b - ftpa@localhost <<'END'
pwd
put /etc/hostname upload/hostname.txt
ls -l upload
END
)
printf '%s\n' "$out"
printf '%s\n' "$out" | grep -x 'Remote working directory: /' >/dev/null
test "$(stat -c %U /srv/sftp/ftpa/upload/hostname.txt)" = ftpa

# Step 7 [sudo]: the command is refused
out=$(ssh -i "$KEY" ftpa@localhost id </dev/null 2>&1 || true)
printf '%s\n' "$out"
printf '%s\n' "$out" | grep 'sftp connections only' >/dev/null
