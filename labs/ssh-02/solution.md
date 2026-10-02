# ssh-02: Hardening the SSH server

## Hints

1. Work in this order: SELinux port type and firewall first, then the
   sshd settings, then the syntax test, then a reload. Keep a second
   session open. The command sshd -T prints the effective settings,
   and its option -C applies Match blocks for a given user.
2. On Rocky 9, sshd_config reads /etc/ssh/sshd_config.d at the top,
   and a file there already allows root password logins. On Rocky 8,
   sshd_config has no Include line, and the directory may not exist.
   The first value sshd reads for a keyword wins.
3. PermitRootLogin has a value that allows keys but no passwords. A
   Match Group block at the end of a file can turn
   PasswordAuthentication off for one group. Port is the one keyword
   that adds up: name port 22 and port 2222.
4. The command semanage port with the option -a adds a port to a type
   (package policycoreutils-python-utils). The command firewall-cmd
   adds ports with --add-port, once with --permanent and once without.

## Solution

1. [sudo] Install the SELinux management tools if they are missing,
   and give port 2222/tcp the type ssh_port_t:

   ```bash
   rpm -q policycoreutils-python-utils ||
     sudo dnf -y install policycoreutils-python-utils
   sudo semanage port -a -t ssh_port_t -p tcp 2222
   sudo semanage port -l | grep ssh_port_t
   ```

2. [sudo] Open the port in the default zone, permanently and at
   runtime:

   ```bash
   sudo firewall-cmd --permanent --add-port=2222/tcp
   sudo firewall-cmd --reload
   sudo firewall-cmd --list-ports
   ```

3. [sudo] Make sshd read the drop-in directory before everything else.
   On Rocky 9 the Include line is already there and nothing changes:

   ```bash
   sudo mkdir -p /etc/ssh/sshd_config.d
   sudo chmod 700 /etc/ssh/sshd_config.d
   sudo grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' \
     /etc/ssh/sshd_config ||
     sudo sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' \
       /etc/ssh/sshd_config
   ```

4. [sudo] Write the hardening drop-in. Its name sorts before every
   other file in the directory, so its values win:

   ```bash
   sudo tee /etc/ssh/sshd_config.d/00-hardening.conf <<'CONF'
   Port 22
   Port 2222
   PermitRootLogin prohibit-password

   Match Group automation
       PasswordAuthentication no
       PubkeyAuthentication yes
   CONF
   sudo chmod 600 /etc/ssh/sshd_config.d/00-hardening.conf
   sudo restorecon -R /etc/ssh
   ```

5. [sudo] Test the configuration, check the effective values and
   reload sshd only when the test passes:

   ```bash
   sudo sshd -t && echo syntax OK
   sudo sshd -T | grep -E '^(port|permitrootlogin) '
   sudo sshd -T -C user=svcbackup,host=localhost,addr=127.0.0.1 |
     grep -E '^(passwordauthentication|pubkeyauthentication) '
   sudo sshd -T -C user=$USER,host=localhost,addr=127.0.0.1 |
     grep '^passwordauthentication '
   sudo sshd -t && sudo systemctl reload sshd
   sudo ss -tlnp | grep sshd
   ```

6. [user] Log in as svcbackup with the key on both ports. A password
   login with the key disabled is now refused:

   ```bash
   ssh -i ~/svcbackup_ed25519 -p 22 svcbackup@localhost id -un
   ssh -i ~/svcbackup_ed25519 -p 2222 svcbackup@localhost id -un
   ssh -o PubkeyAuthentication=no svcbackup@localhost
   ```

## Verification

```bash
sudo sshd -t
sudo ss -tlnp | grep sshd
labctl grade ssh-02
```

## Explanation

sshd uses the first value it reads for most keywords, and an Include
line reads the files at the place where the line stands. On Rocky 9
the Include line is the first line of sshd_config, and the installer
can write 01-permitrootlogin.conf with PermitRootLogin yes. A file
named 00-hardening.conf is read before it, so its value wins. Deleting
the installer's file works as well. On Rocky 8 sshd_config sets
PermitRootLogin yes itself and has no Include line, so the solution
adds one at the top. Editing sshd_config directly is also fine: the
grader reads the effective configuration, not a file.

prohibit-password (shown as without-password by sshd -T) allows root
keys and refuses root passwords. PermitRootLogin no would also lock
out every root key login, including tools that log in as root with a
key.

Port is the exception to the first value rule: every Port line adds a
port. Without any Port line sshd listens on 22. A drop-in with only
Port 2222 would drop port 22, and with it labctl and your own session
after the next reload. sshd binds a port only when SELinux allows
ssh_port_t on it, so the semanage step comes first.

A Match block lasts until the next Match line or the end of the file
it is in, so it goes at the end of the drop-in. sshd -T alone shows
the values without any Match; with -C and a user it applies the Match
blocks for that user. A reload makes sshd read the configuration
again and keeps open sessions.
