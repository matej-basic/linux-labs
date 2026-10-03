# users-05: Sudo rules with drop-in files and command aliases

## Hints

1. The files in /etc/sudoers.d are read in sorted order. One file
   can hold an alias definition and the rules that use it. Read
   man sudoers, the parts on aliases and user specifications.
2. A rule names who, on which host, as which user and which commands.
   A name that starts with a percent sign is a group. The tag
   NOPASSWD before the commands drops the password prompt.
3. The command visudo checks a file without installing it when you
   give it the check option and the file name. Write the file in your
   home directory first and copy it into place only when it parses.
4. The command sudo lists the rights of another user with the options
   for list and user, and it checks a single command when you add the
   command after them.

## Solution

1. [user] Write the drop-in file in your home directory:

   ```bash
   cat > ~/50-lab <<'SUDOERS'
   Cmnd_Alias HTTPD_CMDS = /usr/bin/systemctl restart httpd, \
                           /usr/bin/systemctl status httpd
   %helpdesk ALL=(root) NOPASSWD: HTTPD_CMDS
   auditor   ALL=(root) /usr/bin/journalctl
   SUDOERS
   ```

2. [user] Check the syntax of the file:

   ```bash
   visudo -c -f ~/50-lab
   ```

3. [sudo] Install the file with the right owner and mode, check the
   whole configuration and remove the copy:

   ```bash
   sudo install -m 0440 -o root -g root ~/50-lab /etc/sudoers.d/50-lab
   sudo visudo -c
   rm ~/50-lab
   ```

4. [sudo] List the rights of both users and test single commands:

   ```bash
   sudo -l -U webops
   sudo -l -U auditor
   sudo -l -U webops /usr/bin/systemctl stop httpd
   sudo -l -U auditor /usr/bin/journalctl -u sshd
   ```

## Verification

```bash
ls -l /etc/sudoers.d/50-lab
sudo -l -U webops /usr/bin/cat /etc/shadow
labctl grade users-05
```

The command for /etc/shadow prints nothing and exits 1, because webops
may not run it.

## Explanation

The line #includedir /etc/sudoers.d at the end of /etc/sudoers reads
the drop-in files in sorted order. The hash sign there is part of the
directive, not a comment. When several rules match a command, the
last one wins. 50-lab sorts before opsadmin, so nothing in 50-lab can
take away the passwordless sudo of opsadmin, but a rule for opsadmin
in a file named zz-lab would. sudo skips a drop-in file with a syntax
error, a file that does not belong to root and a file that others can
write. It prints a warning for each, so a broken file costs the rules
in it but not the rest of the configuration.

Editing in place with sudo visudo -f /etc/sudoers.d/50-lab works as
well: visudo locks the file, checks it when the editor closes and
sets owner root and mode 0440 on a new file. Copying a file with mv
keeps its owner, which is why the solution uses install.

(root) limits the target user to root. ALL in that place would allow
every user. NOPASSWD applies to the commands that follow it in the
same rule, so the auditor rule without it asks for the password of
auditor, not the password of root. A command without arguments in
sudoers allows any arguments, so auditor may run journalctl with any
options. The arguments restart httpd and status httpd in the alias
allow exactly those words and nothing more, so systemctl stop httpd
is refused.

sudo -l -U lists the rules of another user and needs root. With a
command after it, sudo prints the full command and exits 0 when the
user may run it, and exits 1 otherwise.
