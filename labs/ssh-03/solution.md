# ssh-03: Key login fails for a user with a non-standard home

## Hints

1. Try the login with the client in verbose mode. The lines
   "Authentications that can continue" list the methods the server
   allows for this user. The command sshd with the option -T prints
   the effective server settings, and -C applies the Match blocks for
   a given user.
2. The server log tells why a key was refused: read the journal of
   the unit sshd or /var/log/secure right after a failed attempt.
   StrictModes checks the owner and the mode of the home directory,
   of .ssh and of authorized_keys.
3. SELinux denials are in the audit log, and the command ausearch
   finds AVC records. Compare the labels in the home directory with a
   home under /home. The command semanage fcontext can make /srv/users
   equivalent to /home, and restorecon applies the rules.
4. A key login that succeeds but closes at once with "This account is
   currently not available" points at the login shell of the account.

## Solution

1. [user] Reproduce the failure. The client in verbose mode shows
   that the server does not offer publickey for webdeploy:

   ```bash
   ssh -v -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
     -i ~/.ssh/webdeploy_ed25519 webdeploy@localhost id -un 2>&1 |
     grep -E 'continue|denied'
   ```

   StrictHostKeyChecking=accept-new stores the host key of localhost
   on the first login. BatchMode=yes stops the client from asking for
   a password when the key is refused.

2. [sudo] Look at the effective settings for webdeploy and find the
   block that turns public key authentication off:

   ```bash
   sudo sshd -T -C user=webdeploy,host=localhost,addr=127.0.0.1 |
     grep -E '^(pubkeyauthentication|strictmodes) '
   sudo grep -n -A 2 '^Match' /etc/ssh/sshd_config
   ```

   The end of /etc/ssh/sshd_config has a Match User webdeploy block
   with PubkeyAuthentication no.

3. [sudo] Delete the two lines of that block, test the configuration
   and reload sshd only when the test passes:

   ```bash
   sudo sed -i '/^Match User webdeploy$/,/PubkeyAuthentication no$/d' \
     /etc/ssh/sshd_config
   sudo sshd -t && sudo systemctl reload sshd
   ```

4. [user] Try again. The server now accepts publickey for webdeploy,
   but refuses the key:

   ```bash
   ssh -v -o BatchMode=yes -i ~/.ssh/webdeploy_ed25519 \
     webdeploy@localhost id -un 2>&1 | grep -E 'Offering|denied'
   ```

5. [sudo] Read the server log and the audit log. On Rocky 9 the
   server log has "Could not open user 'webdeploy' authorized keys
   ... Permission denied"; on Rocky 8 only the AVC record shows it.
   sshd_t may not read a file of type var_t:

   ```bash
   sudo tail -n 5 /var/log/secure
   sudo ausearch -m AVC -ts recent
   ls -ldZ /srv/users/webdeploy
   ls -ldZ /srv/users/webdeploy/.ssh/authorized_keys
   ls -ldZ ~ ~/.ssh
   ```

6. [sudo] Install the SELinux management tools if they are missing.
   Make /srv/users equivalent to /home in the file context rules and
   apply the rules:

   ```bash
   rpm -q policycoreutils-python-utils ||
     sudo dnf -y install policycoreutils-python-utils
   sudo semanage fcontext -a -e /home /srv/users
   sudo restorecon -Rv /srv/users
   ```

7. [user] Try again, then read the server log. The key is still
   refused, and the log says "Authentication refused: bad ownership
   or modes for directory /srv/users/webdeploy":

   ```bash
   ssh -o BatchMode=yes -i ~/.ssh/webdeploy_ed25519 \
     webdeploy@localhost id -un
   sudo tail -n 3 /var/log/secure
   ls -ld /srv/users/webdeploy
   ```

8. [sudo] Take the write permission for the group and others away
   from the home directory:

   ```bash
   sudo chmod 0700 /srv/users/webdeploy
   ```

9. [user] Try again. The key is accepted now, but the connection
   ends with "This account is currently not available":

   ```bash
   ssh -o BatchMode=yes -i ~/.ssh/webdeploy_ed25519 \
     webdeploy@localhost id -un
   getent passwd webdeploy
   ```

10. [sudo] Give webdeploy the login shell /bin/bash:

    ```bash
    sudo usermod -s /bin/bash webdeploy
    ```

11. [user] The login works and the command runs as webdeploy:

    ```bash
    ssh -o BatchMode=yes -i ~/.ssh/webdeploy_ed25519 \
      webdeploy@localhost id -un
    ```

## Verification

```bash
sudo restorecon -n -R -v /srv/users/webdeploy
sudo sshd -t
labctl grade ssh-03
```

## Explanation

Four faults block the login, and each one hides the next. The Match
block is evaluated when the user name is known, so the server never
offers publickey to webdeploy while the block is there; sshd -T
without -C does not show it. Removing the block or setting
PubkeyAuthentication yes in it both work.

sshd runs as sshd_t and may read authorized keys only with a home
type such as ssh_home_t. A home under /srv gets var_t by default. The
equivalence rule makes every path below /srv/users get the label of
the same path below /home, so the home directory gets
user_home_dir_t and .ssh gets ssh_home_t, and a relabel keeps them. A
rule that gives .ssh the type ssh_home_t also passes. chcon alone
does not: the next relabel undoes it. Setting SELinux to permissive
would hide the fault and is not allowed.

StrictModes makes sshd ignore the keys when the home directory, .ssh
or authorized_keys are writable by anyone but the owner. Turning
StrictModes off would let other users plant keys, so the mode is
fixed instead.

/sbin/nologin accepts the login and closes the session at once, so
the key works but no command runs. The account is a system account
(UID below 1000), which is why the SELinux tools do not treat its
home directory as a user home by themselves.
