# files-07: Incremental rsync snapshots with a systemd timer

## Hints

1. rsync can compare each file with an older copy in another
   directory and create a hard link to it instead of copying, when
   the file is unchanged. Read man rsync, the option --link-dest.
2. Snapshot names in the form YYYY-MM-DD_HHMMSS sort in time order,
   so the last name in a sorted list is the newest snapshot. The
   first run has no earlier snapshot. A relative --link-dest path is
   relative to the new snapshot, so use an absolute one.
3. Archive mode of rsync keeps modes, owners, groups and times, and
   an exclude option leaves out names by pattern. A trailing slash on
   the source copies the contents of the directory. The command ln
   has an option to replace an existing link to a directory instead
   of creating a new link inside it.
4. OnCalendar and Persistent are in man systemd.timer, the calendar
   format in man systemd.time. Enable and start the timer, not the
   service, after systemctl daemon-reload.

## Solution

1. [sudo] Install rsync if it is missing:

   ```bash
   rpm -q rsync || sudo dnf -y install rsync
   ```

2. [sudo] Create the script and make it executable. It is written
   by root, so root owns it:

   ```bash
   sudo tee /usr/local/sbin/snapshot-backup > /dev/null <<'EOF2'
   #!/bin/bash
   # Incremental snapshot of /srv/data in /backup/snapshots
   set -euo pipefail
   DEST=/backup/snapshots
   new=$DEST/$(date +%Y-%m-%d_%H%M%S)

   mkdir -p "$DEST"
   if [ -e "$new" ]; then
     echo "snapshot $new exists already" >&2
     exit 1
   fi

   # The newest earlier snapshot, if there is one
   shopt -s nullglob
   snaps=("$DEST"/????-??-??_??????)
   link=()
   if [ "${#snaps[@]}" -gt 0 ]; then
     link=(--link-dest="${snaps[-1]}")
   fi

   rsync -a --exclude='*.cache' "${link[@]}" /srv/data/ "$new/"
   ln -sfn "${new##*/}" "$DEST/latest"
   EOF2
   sudo chmod 0755 /usr/local/sbin/snapshot-backup
   ```

3. [sudo] Make the first snapshot, simulate a day of work and make
   the second snapshot. Wait at least a second between the two
   snapshots, so that they get different names:

   ```bash
   sudo /usr/local/sbin/snapshot-backup
   sudo /usr/local/sbin/lab-churn
   sleep 1
   sudo /usr/local/sbin/snapshot-backup
   ```

4. [sudo] Create the service and the timer:

   ```bash
   sudo tee /etc/systemd/system/snapshot-backup.service \
       > /dev/null <<'EOF2'
   [Unit]
   Description=Incremental snapshot of /srv/data

   [Service]
   Type=oneshot
   ExecStart=/usr/local/sbin/snapshot-backup
   EOF2
   sudo tee /etc/systemd/system/snapshot-backup.timer \
       > /dev/null <<'EOF2'
   [Unit]
   Description=Daily snapshot of /srv/data

   [Timer]
   OnCalendar=*-*-* 02:30:00
   Persistent=true

   [Install]
   WantedBy=timers.target
   EOF2
   ```

5. [sudo] Load the units, then enable and start the timer:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now snapshot-backup.timer
   ```

## Verification

```bash
ls -l /backup/snapshots
sudo ls -li /backup/snapshots/*/projects
systemctl list-timers snapshot-backup.timer
labctl grade files-07
```

## Explanation

With --link-dest, rsync compares every file of the source with the
file of the same name in the given directory. When size, time, mode
and owner are the same, it creates a hard link in the new snapshot
instead of a copy. Every snapshot is then a complete tree that can be
restored on its own, but an unchanged file uses its disk space only
once. ls -li shows the same inode number for projects/plan.txt in both
snapshots and a link count of 2, and different inodes for
projects/notes.txt, which lab-churn changed. Deleting an old snapshot
removes only the links of that snapshot.

rsync -a keeps modes, owners, groups and times, and as root it can
read every file and set every owner. The trailing slash on /srv/data/
copies the contents rather than a directory named data. A relative
--link-dest path is taken relative to the destination, which is why
the script passes an absolute path. ln -sfn replaces the link latest
itself; without -n, ln would follow the old link and create a new
link inside the previous snapshot.

The secure path of sudo leaves out /usr/local/sbin, so commands there
need their full path. The timer runs the service of the same name.
OnCalendar=*-*-* 02:30:00 (or just 02:30) means every day at 02:30,
and Persistent=true stores the time of the last run in
/var/lib/systemd/timers, so a run missed while the system was off
starts at the next boot. systemd-analyze calendar shows how systemd
reads a calendar expression.
