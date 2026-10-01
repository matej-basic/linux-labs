# users-01: Users, groups and shared directories

## Hints

1. Most of this is one tool: man useradd. Read the options for the
   primary group, supplementary groups, home directory and shell.
2. A system account is created with a different option than a normal
   user, and it gets no home directory by default. Check what the
   home directory options do for such an account.
3. The command useradd does not set the permissions 750 or the owner
   of a home directory that you created by hand. Use chown and chmod
   for that.
4. For /srv/project, the leading digit of the four-digit mode in
   man chmod is the setgid bit.

## Solution

1. [sudo] Create the group:

   ```bash
   sudo groupadd project
   ```

2. [sudo] Create alice with primary group project, supplementary
   group wheel, a home directory and bash:

   ```bash
   sudo useradd -m -g project -G wheel -s /bin/bash alice
   ```

3. [sudo] Create the system account svcapp with home /srv/svcapp, and
   set ownership and permissions of the home directory:

   ```bash
   sudo useradd -r -M -d /srv/svcapp -g project \
     -s /usr/sbin/nologin svcapp
   sudo mkdir -p /srv/svcapp
   sudo chown svcapp:project /srv/svcapp
   sudo chmod 750 /srv/svcapp
   ```

4. [sudo] Create the shared directory with the setgid bit:

   ```bash
   sudo mkdir -p /srv/project
   sudo chown root:project /srv/project
   sudo chmod 2775 /srv/project
   ```

## Verification

```bash
id alice
id svcapp
ls -ld /home/alice /srv/svcapp /srv/project
labctl grade users-01
```

## Explanation

useradd -g sets the primary group and -G the supplementary groups, so
alice ends up in project and wheel. -m creates the home directory from
/etc/skel with alice:project as owner, because the primary group is
project and not a private group named alice.

-r makes svcapp a system account with a UID below 1000. Such accounts
get no home directory by default, and -M keeps useradd from creating
one, so the directory is made and owned by hand. The shell
/usr/sbin/nologin refuses interactive logins.

The leading 2 in 2775 is the setgid bit: files created in /srv/project
get the group project instead of the primary group of their creator.
The grader compares the full mode, so 775 alone fails.
