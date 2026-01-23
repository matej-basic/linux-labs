#!/bin/bash

# Reset lab state
userdel -r dave >/dev/null 2>&1
userdel -r eve >/dev/null 2>&1
groupdel contractors >/dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: User Management and Password Policies (users-02)
====================================================

OBJECTIVE:
Manage user accounts with password policies, expiration,
resource limits, and account restrictions.

TASKS:

1. Create a group: contractors

2. Create user dave (contractor account):
   - Home: /home/dave
   - Shell: /bin/bash
   - Group: contractors
   - Password expiration: 30 days from now
   - Set password to: "contractor123"
   
3. Create user eve (limited account):
   - Home: /home/eve
   - Shell: /bin/bash
   - Primary group: contractors
   - Account expiration: 2026-01-31 (near future)
   - Password expires: never (use --expiredate -1)
   - Set password to: "eve-pass"

4. Apply resource limits to contractors group:
   - Max open files: 1024
   - Max processes: 512
   - Create/edit: /etc/security/limits.d/70-contractors.conf

5. Password policy via /etc/login.defs or PAM:
   - PASS_MAX_DAYS: 90
   - PASS_MIN_DAYS: 1
   - PASS_WARN_AGE: 14

NOTES:
- Use useradd, chage, passwd commands
- Verify with: getent passwd, chage -l, cat /etc/security/limits.d/
- Resource limits require user to log in to take effect

When ready, run:
  sudo labctl grade users-02

====================================================

EOF
