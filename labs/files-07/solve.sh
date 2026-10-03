#!/bin/bash
# Reference solution for files-07, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package rsync
# solve: path /usr/local/sbin/snapshot-backup
# solve: path /usr/local/sbin/lab-churn
# solve: path /etc/systemd/system/snapshot-backup.service
# solve: path /etc/systemd/system/snapshot-backup.timer
# solve: path /srv/data
# solve: path /backup
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q rsync >/dev/null || dnf -y install rsync >/dev/null

# Step 2 [sudo]
cat > /usr/local/sbin/snapshot-backup <<'EOF2'
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
chmod 0755 /usr/local/sbin/snapshot-backup

# Step 3 [sudo]
/usr/local/sbin/snapshot-backup
/usr/local/sbin/lab-churn >/dev/null
sleep 1
/usr/local/sbin/snapshot-backup

# Step 4 [sudo]
cat > /etc/systemd/system/snapshot-backup.service <<'EOF2'
[Unit]
Description=Incremental snapshot of /srv/data

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/snapshot-backup
EOF2
cat > /etc/systemd/system/snapshot-backup.timer <<'EOF2'
[Unit]
Description=Daily snapshot of /srv/data

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF2

# Step 5 [sudo]
systemctl daemon-reload
systemctl enable --now snapshot-backup.timer
