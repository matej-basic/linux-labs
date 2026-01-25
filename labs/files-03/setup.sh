#!/bin/bash

# Reset lab state
rm -rf /srv/secure /tmp/backup

# Print task description
cat <<'EOF'

====================================================
LAB: Advanced Permissions, ACLs, and Special Bits (files-03)
====================================================

OBJECTIVE:
Apply advanced file permissions including ACLs, setuid/setgid/sticky bits,
and special file attributes to secure a shared system.

TASKS:

1. Create directory: /srv/secure
   - Owner/group: root:root
   - Permissions: 755

2. Create subdirectories and files:
   /srv/secure/bin/           (shared executable location)
   ├── deploy.sh              (setuid root, executable)
   /srv/secure/shared/        (shared directory for team)
   /srv/secure/tmp/           (world-writable with sticky bit)

3. Set special permissions:
   - /srv/secure/bin/deploy.sh:
     * Owner: root, mode: 4755 (setuid)
     * Content: simple script like "echo Deployment tool"
   
   - /srv/secure/shared/:
     * Owner/group: root:developers (GID 3000, must create group)
     * Permissions: 2770 (setgid)
     * ACL: allow read/write for group developers
   
   - /srv/secure/tmp/:
     * Owner: root, mode: 1777 (sticky bit, world writable)
     * ACL: allow alice (UID 1001, create if needed) rwx access

4. Create a backup archive:
   - /tmp/backup.tar.gz
   - Contains everything from /srv/secure with permissions preserved
   - Command: tar -czpf /tmp/backup.tar.gz /srv/secure

NOTES:
- setuid (4xxx): execute as owner
- setgid (2xxx): execute as group or inherit group on files
- sticky bit (1xxx): only owner/root can delete files in directory
- Use stat -c '%a' to check final permissions (should show 4 for setuid, etc)
- Use getfacl to verify ACLs

When ready, run:
  sudo labctl grade files-03

====================================================

EOF
