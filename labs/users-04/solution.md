# users-04: Password policy with pwquality, faillock and pwhistory

## Hints

Task 1: authselect

1. authselect builds the PAM files from a profile plus optional
   features. Look at what is selected now before you change anything.
2. Read man authselect: one subcommand adds a feature to the current
   profile and keeps the rest, unlike selecting a profile again.
3. The subcommand check of authselect tells you whether the files in
   /etc/pam.d still match what authselect generated.

Task 2: password quality

1. pam_pwquality reads its settings from pwquality.conf and from the
   files in the directory pwquality.conf.d. Read man pwquality.conf.
2. Each setting is a name = value line. enforce_for_root is a flag on
   a line of its own. The command pwscore tests a password against the
   settings.

Task 3: lockout and history (also task 4)

1. faillock.conf and pwhistory.conf already list every option as a
   comment. Uncomment the ones you need and set their values.
2. The command faillock shows and resets the failure records of an
   account. Use it on pamtest after the practice logins.

## Solution

1. [sudo] Look at the current configuration, then enable the two
   features on the selected profile:

   ```bash
   sudo authselect current
   sudo authselect enable-feature with-faillock
   sudo authselect enable-feature with-pwhistory
   sudo authselect current
   sudo authselect check
   ```

2. [sudo] Create the pwquality drop-in file:

   ```bash
   sudo tee /etc/security/pwquality.conf.d/50-policy.conf <<'CONF'
   minlen = 12
   minclass = 3
   dictcheck = 1
   enforce_for_root
   CONF
   ```

3. [sudo] Set the lockout values in faillock.conf:

   ```bash
   sudo sed -i -E \
     -e 's/^#? *deny *=.*/deny = 3/' \
     -e 's/^#? *unlock_time *=.*/unlock_time = 600/' \
     /etc/security/faillock.conf
   ```

4. [sudo] Set the history values in pwhistory.conf:

   ```bash
   sudo sed -i -E \
     -e 's/^#? *remember *=.*/remember = 5/' \
     -e 's/^#? *enforce_for_root.*/enforce_for_root/' \
     /etc/security/pwhistory.conf
   ```

## Verification

```bash
grep -Ev '^(#|$)' /etc/security/faillock.conf
grep -Ev '^(#|$)' /etc/security/pwhistory.conf
echo 'Vt9-plum-Or' | pwscore
echo 'Vt9-plum-Orbit-x' | pwscore
for i in 1 2 3; do echo wrong | su pamtest -c true; done
sudo faillock --user pamtest
sudo faillock --user pamtest --reset
labctl grade users-04
```

## Explanation

authselect owns system-auth, password-auth and the other files it
links into /etc/pam.d. A hand edit there is lost the next time
authselect writes the files, and authselect check reports it.
enable-feature regenerates the files from the selected profile with
the extra feature, so pam_faillock lands in the auth and account
stacks and pam_pwhistory in the password stack. Selecting a profile
again would drop features that were enabled before. On Rocky Linux 8
and 9 the same authselect version offers both features, and pam reads
faillock.conf and pwhistory.conf on both releases, so no module
options are needed in the PAM files.

libpwquality reads the files in pwquality.conf.d first and
pwquality.conf last, so a value in the main file would override the
drop-in file. minclass counts the classes lower case, upper case,
digits and other characters. Without enforce_for_root, root only sees
a warning and passwd sets a weak password anyway; with it, passwd
refuses the password for root too. pwhistory.conf has its own
enforce_for_root, otherwise root may reuse an old password.

After three failures pam_faillock refuses even the correct password
until unlock_time has passed or faillock --reset clears the records.
Logins with an SSH key do not go through the auth stack, so they are
not counted and are not blocked.
