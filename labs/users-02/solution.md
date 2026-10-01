# users-02: User accounts, password aging and limits

## Hints

1. Separate the per-account settings (dave, eve) from the system-wide
   defaults. They live in different places and need different tools.
2. For aging and expiry of one account, read man chage. Account
   expiry and password expiry are two separate fields there.
3. In man limits.conf, look at the domain field: a group needs a
   prefix character, and each limit needs a soft and a hard line.
   The item names for open files and processes are in the same page.
4. The defaults are the PASS_ keys in /etc/login.defs. Edit them in
   place so that each key appears only once.

## Solution

1. [sudo] Create the group:

   ```bash
   sudo groupadd contractors
   ```

2. [sudo] Create dave, set the password and the maximum password age:

   ```bash
   sudo useradd -m -g contractors -s /bin/bash dave
   echo 'contractor123' | sudo passwd --stdin dave
   sudo chage -M 30 dave
   ```

3. [sudo] Create eve with an account expiry date, set the password and
   remove the password expiry:

   ```bash
   sudo useradd -m -g contractors -s /bin/bash -e 2030-12-31 eve
   echo 'eve-pass' | sudo passwd --stdin eve
   sudo chage -M -1 eve
   ```

4. [sudo] Write the limits for the group. The leading `@` makes the
   entry a group entry:

   ```bash
   sudo tee /etc/security/limits.d/70-contractors.conf <<'LIMITS'
   @contractors soft nofile 1024
   @contractors hard nofile 1024
   @contractors soft nproc 512
   @contractors hard nproc 512
   LIMITS
   ```

5. [sudo] Set the password aging defaults:

   ```bash
   sudo sed -i -E \
     -e 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' \
     -e 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' \
     -e 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
   ```

## Verification

```bash
sudo chage -l dave
sudo chage -l eve
cat /etc/security/limits.d/70-contractors.conf
grep -E '^PASS_(MAX|MIN|WARN)' /etc/login.defs
labctl grade users-02
```

## Explanation

`chage -M 30` sets the maximum password age of one account, while
`PASS_MAX_DAYS` in `/etc/login.defs` is only the default for accounts
created afterwards, so both are needed. For eve, `chage -M -1` removes
the password expiry and `useradd -e` (or `chage -E`) sets the separate
account expiry date. A maximum age of -1 is shown as "never" by
`chage -l`.

In `limits.conf` syntax a bare name is a user name. Without the `@` the
entries would apply to a user called contractors and not to the group.
The limits are read by pam_limits at login, so they only show up in
`ulimit -n` and `ulimit -u` in a new session of dave or eve.
