# users-03: Users, groups and ACLs for shared directories

## Hints

1. Fixed IDs are options of groupadd and useradd, see their man
   pages. Create the groups first, so the users can refer to them.
2. The command useradd creates home directories with mode 700, so the
   mode 750 needs a separate step. The account expiry date is set with
   chage.
3. ACLs are handled by setfacl and getfacl (man setfacl). A default
   ACL is a different option than an ordinary entry. Set owner and
   mode of a directory before the ACL, because chmod changes the mask.
4. charlie can not reach /srv/shared/analytics through the group
   devops. Give charlie only the search permission (execute) on
   /srv/shared with one more ACL entry for that user.

## Solution

1. [sudo] Create the two groups with fixed GIDs:

   ```bash
   sudo groupadd -g 2000 devops
   sudo groupadd -g 2001 analytics
   ```

2. [sudo] Create bob and set the home directory mode:

   ```bash
   sudo useradd -u 1010 -m -g devops -G wheel,analytics -s /bin/bash bob
   sudo chmod 750 /home/bob
   ```

3. [sudo] Create charlie, set the home directory mode and the account
   expiry date:

   ```bash
   sudo useradd -u 1011 -m -g analytics -G wheel -s /bin/bash charlie
   sudo chmod 750 /home/charlie
   sudo chage -E 2099-12-31 charlie
   ```

4. [sudo] Create /srv/shared with its owner, mode and default ACL:

   ```bash
   sudo mkdir -p /srv/shared/analytics
   sudo chown root:devops /srv/shared
   sudo chmod 750 /srv/shared
   sudo setfacl -d -m g:devops:rwx /srv/shared
   ```

5. [sudo] Set owner and mode of the sub-directory, then add the ACL
   entry for charlie. Set the mode first: chmod would reset the ACL
   mask afterwards.

   ```bash
   sudo chown root:analytics /srv/shared/analytics
   sudo chmod 750 /srv/shared/analytics
   sudo setfacl -m u:charlie:rwx /srv/shared/analytics
   ```

6. [sudo] Let charlie traverse /srv/shared with an execute-only ACL
   entry:

   ```bash
   sudo setfacl -m u:charlie:x /srv/shared
   ```

## Verification

```bash
id bob
id charlie
sudo chage -l charlie
getfacl /srv/shared /srv/shared/analytics
sudo -u charlie touch /srv/shared/analytics/t
sudo rm /srv/shared/analytics/t
labctl grade users-03
```

## Explanation

useradd -m creates the home directory with mode 700 on Rocky Linux,
so the 750 mode needs an explicit chmod. The group of the home
directory is already devops or analytics because of -g.

An ACL entry for a named user changes the ACL mask, and ls and stat
then show the mask in the group position. The grader therefore checks
the base entries user::, group:: and other:: with getfacl instead of
the mode shown by ls. If chmod runs after setfacl on
/srv/shared/analytics, the mask drops to r-x and charlie loses write
access even though the entry says rwx.

charlie is in analytics but not in devops, so without step 6 the
directory /srv/shared (group devops, others none) would block access
to /srv/shared/analytics. The named entry u:charlie:x gives search
permission on /srv/shared only, and the mask there stays r-x, so the
base permissions stay rwxr-x---. Adding charlie to devops or opening
the directory to others would pass the traversal but fail other
criteria.

The default ACL on /srv/shared only affects objects created later in
it. It does not change /srv/shared itself.
