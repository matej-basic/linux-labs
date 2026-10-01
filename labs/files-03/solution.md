# files-03: Special permissions, ACLs and backup

## Hints

1. Work through the tasks in order and create the archive last, after
   every owner, mode and ACL is set. tar records what the tree looks
   like at that moment.
2. The special bits are the leading digit of a four-digit octal mode:
   setuid, setgid and sticky each have their own value in man chmod.
3. ACL entries are set with setfacl and read back with getfacl. The
   -m option modifies an entry, and the entry syntax is g:name:perms
   for a group or u:name:perms for a user.
4. Run chmod before setfacl, because chmod on the group bits changes
   the ACL mask. For the archive, see the -c, -z and -f options in
   man tar.

## Solution

1. [sudo] Create the group and the user with the required IDs:

   ```bash
   sudo groupadd -g 3000 developers
   sudo useradd -u 1001 alice
   ```

2. [sudo] Create the tree and the setuid script:

   ```bash
   sudo mkdir -p /srv/secure/bin /srv/secure/shared /srv/secure/tmp
   sudo chown root:root /srv/secure
   sudo chmod 755 /srv/secure
   echo 'echo "Deployment tool"' | sudo tee /srv/secure/bin/deploy.sh \
     >/dev/null
   sudo chown root:root /srv/secure/bin/deploy.sh
   sudo chmod 4755 /srv/secure/bin/deploy.sh
   ```

3. [sudo] Set owner, setgid bit and ACL on the shared directory:

   ```bash
   sudo chown root:developers /srv/secure/shared
   sudo chmod 2770 /srv/secure/shared
   sudo setfacl -m g:developers:rwx /srv/secure/shared
   ```

4. [sudo] Set owner, sticky bit and ACL on the tmp directory:

   ```bash
   sudo chown root:root /srv/secure/tmp
   sudo chmod 1777 /srv/secure/tmp
   sudo setfacl -m u:alice:rwx /srv/secure/tmp
   ```

5. [sudo] Archive the finished tree:

   ```bash
   sudo tar -czpf /tmp/backup.tar.gz /srv/secure
   ```

## Verification

```bash
ls -ld /srv/secure /srv/secure/bin/deploy.sh /srv/secure/shared \
  /srv/secure/tmp
getfacl /srv/secure/shared /srv/secure/tmp
tar -tvzf /tmp/backup.tar.gz
labctl grade files-03
```

## Explanation

The leading digit of a four-digit mode holds the special bits: 4 is
setuid, 2 is setgid and 1 is the sticky bit. The kernel ignores setuid
on scripts, so deploy.sh only carries the bit.

Run chmod before setfacl. When a directory has an ACL, the group digit
of its mode shows the ACL mask, and chmod on the group bits changes the
mask. With the order above the mask stays rwx, so the named entries are
fully effective and the mode still reads 2770 and 1777.

tar always stores owners and modes, and it strips the leading slash, so
the members are named srv/secure/.... The archive reflects the tree at
the moment it is made. An archive created before the chmod and chown
steps records the old modes and fails the last criterion. Reading
/srv/secure/shared needs root, because only root and developers may
enter it.
