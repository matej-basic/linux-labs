# ssh-04: SFTP-only group chrooted to per-user directories

## Hints

1. A Match block at the end of the main sshd configuration file can
   give one group its own settings. The command sshd with the option
   -T prints the effective settings, and -C applies the Match blocks
   for a given user.
2. Read ChrootDirectory in man sshd_config. The chroot directory and
   every directory above it must belong to root and must not be
   writable by anyone else, so the user cannot write to the top of
   the chroot. A subdirectory owned by the user can take the uploads.
3. With ForceCommand set to internal-sftp, the chroot needs no shell
   and no programs. The keys are read from the real home directory
   before the chroot, so the authorized keys file goes in
   /home/<user>/.ssh with the usual owner and modes.
4. Test with the sftp client in batch mode, as root with the lab
   private key. A plain command over SSH as ftpa should be refused.

## Solution

1. [sudo] Create the group and the two accounts with the shell
   /sbin/nologin and a home directory in /home:

   ```bash
   sudo groupadd sftponly
   sudo useradd -m -s /sbin/nologin -G sftponly ftpa
   sudo useradd -m -s /sbin/nologin -G sftponly ftpb
   id ftpa; id ftpb
   ```

2. [sudo] Install the lab public key as the authorized keys file of
   both accounts, with the owner and modes that StrictModes expects:

   ```bash
   for u in ftpa ftpb; do
     sudo install -d -m 0700 -o "$u" -g "$u" "/home/$u/.ssh"
     sudo install -m 0600 -o "$u" -g "$u" ~/sftp-lab.pub \
       "/home/$u/.ssh/authorized_keys"
     sudo restorecon -R "/home/$u/.ssh"
   done
   ```

3. [sudo] Build the chroot directories. They and /srv belong to root
   with mode 0755; only upload belongs to the user:

   ```bash
   for u in ftpa ftpb; do
     sudo mkdir -p "/srv/sftp/$u/upload"
     sudo chmod 0755 /srv/sftp "/srv/sftp/$u"
     sudo chown "$u:$u" "/srv/sftp/$u/upload"
     sudo chmod 0755 "/srv/sftp/$u/upload"
   done
   ls -ld /srv /srv/sftp /srv/sftp/*/ /srv/sftp/*/upload
   ```

4. [sudo] Append a Match block for the group to the end of
   /etc/ssh/sshd_config, test the configuration and reload sshd only
   when the test passes:

   ```bash
   sudo tee -a /etc/ssh/sshd_config >/dev/null <<'END'

   Match Group sftponly
       ChrootDirectory /srv/sftp/%u
       ForceCommand internal-sftp
       AllowTcpForwarding no
       X11Forwarding no
   END
   sudo sshd -t && sudo systemctl reload sshd
   ```

   On Rocky 9 the Include of /etc/ssh/sshd_config.d is at the top of
   the main file, so a block at the end of the main file is the last
   thing sshd reads on both releases.

5. [sudo] Compare the effective settings of ftpa and of yourself:

   ```bash
   sudo sshd -T -C user=ftpa,host=localhost,addr=127.0.0.1 |
     grep -E '^(chroot|forcecommand|allowtcp|x11forwarding)'
   sudo sshd -T -C user=$USER,host=localhost,addr=127.0.0.1 |
     grep -E '^(chrootdirectory|forcecommand)'
   ```

   For ftpa the output shows /srv/sftp/%u and internal-sftp, for you
   it shows none.

6. [sudo] Open an SFTP session as ftpa with the lab key, check the
   working directory and upload a file:

   ```bash
   sudo sftp -i /opt/linux-labs/state/ssh-04.d/sftp-lab \
     -o StrictHostKeyChecking=accept-new -b - ftpa@localhost <<'END'
   pwd
   put /etc/hostname upload/hostname.txt
   ls -l upload
   END
   ls -l /srv/sftp/ftpa/upload
   ```

   The session reports the remote working directory /, and the file
   belongs to ftpa.

7. [sudo] Try a command over SSH as ftpa. sshd answers with "This
   service allows sftp connections only." and runs nothing:

   ```bash
   sudo ssh -i /opt/linux-labs/state/ssh-04.d/sftp-lab \
     ftpa@localhost id < /dev/null
   ```

## Verification

```bash
sudo sshd -t
labctl grade ssh-04
```

## Explanation

ChrootDirectory makes sshd change the root directory of the session
after the user has logged in. sshd refuses the chroot when the
directory or any directory above it belongs to someone other than
root or is writable by the group or others, so the users write into
an upload directory of their own instead. %u expands to the user
name, so one block serves every member of the group.

ForceCommand internal-sftp runs the SFTP server inside sshd. It needs
no shell and no files in the chroot, and it refuses every other
command, so the nologin shell is never used. AllowTcpForwarding no
and X11Forwarding no close the other channels an SSH connection can
open.

The authorized keys file is read with the real file system before
the chroot, so it stays in /home/<user>/.ssh, where the default
SELinux labels apply. The chroot under /srv needs no SELinux change:
the session runs in the user's context, which may write to the
default type of /srv. The Match block applies only to the group, so
the settings of every other account stay as they were.
