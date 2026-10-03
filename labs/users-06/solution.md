# users-06: Accounts that cannot log in

## Hints

1. Try a password login as each user from your own account and read
   the message, then read /var/log/secure. Each account fails for a
   different reason.
2. The account data is in /etc/passwd and /etc/shadow. The command
   chage lists the expiry data of an account. The status option of the
   command passwd shows whether a password is locked, and the command
   getent shows the shell and the home directory.
3. The command usermod changes the expiry date, the shell and the lock
   of a password without touching the password hash. Setting a new
   password would change the hash.
4. Nothing recreates a missing home directory for an existing user.
   Copy /etc/skel yourself, then set the owner, the mode and the
   SELinux labels.

## Solution

1. [sudo] Find the cause for each account:

   ```bash
   su - anna
   sudo tail /var/log/secure
   sudo chage -l anna
   sudo passwd -S ben
   getent passwd carla dario
   ls -ld /home/dario
   sudo faillock --user dario
   ```

2. [sudo] anna has expired. Remove the expiry date:

   ```bash
   sudo chage -E -1 anna
   ```

3. [sudo] The password of ben is locked. Unlock it, which keeps the
   hash:

   ```bash
   sudo usermod -U ben
   ```

4. [sudo] carla has the shell /sbin/nologin. Set bash:

   ```bash
   sudo usermod -s /bin/bash carla
   ```

5. [sudo] The home directory of dario is missing. Create it from
   /etc/skel:

   ```bash
   sudo cp -a /etc/skel /home/dario
   sudo chown -R dario:dario /home/dario
   sudo chmod 0700 /home/dario
   sudo restorecon -R /home/dario
   ```

6. [user] Test each login with the password Harbor-Lantern-58:

   ```bash
   su - anna -c 'pwd; echo $SHELL'
   su - ben -c 'pwd; echo $SHELL'
   su - carla -c 'pwd; echo $SHELL'
   su - dario -c 'pwd; echo $SHELL'
   ```

## Verification

```bash
sudo chage -l anna
sudo passwd -S ben
getent passwd anna ben carla dario
labctl grade users-06
```

## Explanation

A password login goes through two PAM steps. The auth step checks the
password and the account step checks the account. anna gives the right
password but the account step refuses it: chage -l shows an account
expiry date in the past, and su reports that the account has expired.
chage -E -1 removes the date. A date later than 2031-01-01 would also
meet the task.

ben gets an authentication failure even with the right password,
because usermod -L or passwd -l put an exclamation mark in front of
the hash in /etc/shadow and no password can match it any more. passwd
-S shows LK. usermod -U or passwd -u remove the mark, so the old
password works again. Setting the password anew would also work for
the login, but it writes a new hash with a new salt, and the task
asks to keep the password.

carla authenticates, but /sbin/nologin is her shell. It prints a
message and exits, so there is no session. Only the shell field in
/etc/passwd changes.

dario logs in, but su warns that it cannot change to /home/dario and
starts the shell in another directory. useradd creates the home only
when it creates the user. The copy of /etc/skel gives the start
files, chown and chmod set the owner and the mode 0700 that useradd
uses on Rocky Linux 8 and 9, and restorecon gives the directory the
SELinux type of a home directory.

Deleting and creating an account again would give it a new UID and a
new password and leave files of the old UID without an owner. Turning
off a PAM module or a login.defs setting would loosen the policy for
every account. Both behave the same on Rocky Linux 8 and 9.
