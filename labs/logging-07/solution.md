# logging-07: File integrity checks with AIDE

## Hints

Task 2: the configuration

1. An AIDE configuration has three parts: settings such as the
   database paths, rule definitions that name groups of attributes,
   and selection lines that pick the paths to check. Keep the first
   two parts and replace the third.
2. A selection line starts with a path, which AIDE reads as a
   regular expression. A line that starts with ! excludes the paths
   it matches. man aide.conf calls them selection lines on Rocky
   Linux 8 (section SELECTION LINES) and rules on Rocky Linux 9
   (section RULES).
3. The attributes have short names, such as p for the permissions.
   A definition of the form NAME = attribute+attribute names a group
   of attributes for the selection lines. See man aide.conf, section
   DEFAULT GROUPS on Rocky Linux 8 and ATTRIBUTES on Rocky Linux 9.

Task 4: the database and the check

1. The command aide has options to initialise the database, to check
   the file system against it and to test the configuration.
2. The database_out setting names the file an initialisation writes.
   The active database is the file named by database (Rocky Linux 8)
   or database_in (Rocky Linux 9). Rename the new file to that name.
3. A shell redirection to a file in /root runs with your own
   permissions, not with those of sudo. The command tee can write the
   file as root.

## Solution

1. [sudo] Install AIDE if it is missing and look at the shipped
   configuration:

   ```bash
   rpm -q aide || sudo dnf -y install aide
   sudo grep -nE '^(database|report_url|[A-Z_]+ =)' /etc/aide.conf
   ```

2. [sudo] Remove all selection lines from /etc/aide.conf, then add
   the rule and the selection lines for /srv/app:

   ```bash
   sudo cp -p /etc/aide.conf /etc/aide.conf.orig
   sudo sed -i -E '/^[[:space:]]*[!=]?\//d' /etc/aide.conf
   sudo tee -a /etc/aide.conf >/dev/null <<'CONF'

   # logging-07: the application tree only
   APPRULE = p+u+g+sha512
   /srv/app APPRULE
   !/srv/app/data
   CONF
   sudo rm /etc/aide.conf.orig
   sudo aide --config-check
   ```

3. [sudo] Initialise the database and make it the active one:

   ```bash
   sudo aide --init
   sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
   ```

4. [sudo] Run the helper once:

   ```bash
   sudo /usr/local/sbin/lab-tamper
   ```

5. [sudo] Check the tree and save the report:

   ```bash
   sudo aide --check | sudo tee /root/aide-report.txt
   ```

## Verification

```bash
sudo grep -A 12 '^Added entries:' /root/aide-report.txt
labctl grade logging-07
```

## Explanation

AIDE records the attributes of the selected files in a database and
compares the file system with it later. The shipped /etc/aide.conf
selects most of the system, and initialising it on a small virtual
machine takes many minutes. Removing the selection lines and adding
one for /srv/app keeps the database settings and the predefined rules,
and limits the work to a few files.

The rule p+u+g+sha512 checks the permissions, the owner, the group and
a SHA-512 checksum of the content. It leaves out the modification
time, the inode and the link count, so the added file does not also
show up as a change of its directory. The selection line !/srv/app/data
excludes that directory and everything below it, because the
application changes those files all the time.

aide --init writes /var/lib/aide/aide.db.new.gz and never replaces the
active database itself. An administrator reviews a new database before
moving it into place, ideally to read-only media. The setting that
names the active database is database on Rocky Linux 8 (AIDE 0.16) and
database_in on Rocky Linux 9 (AIDE 0.19). Editing the shipped file
keeps the right one on both releases.

aide --check exits with a bit mask: 1 for added, 2 for removed and 4
for changed files, so this check exits 5. The report shows the added
helper script, the changed configuration and the set-user-ID bit on
appctl. The grader runs its own check with your configuration and
database and expects exactly these three entries, and it tests the
rule on a copy of the tree. aide --update would build a new database
from the current state after a review.
