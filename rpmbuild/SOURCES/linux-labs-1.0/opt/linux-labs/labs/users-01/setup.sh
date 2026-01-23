#!/bin/bash

# Reset lab state
userdel -r alice >/dev/null 2>&1
userdel -r svcapp >/dev/null 2>&1
groupdel project >/dev/null 2>&1
rm -rf /home/alice /srv/project /srv/svcapp

# Print task description
cat <<'EOF'

====================================================
LAB: Users and Groups (users-01)
====================================================

OBJECTIVE:
Create the required users, groups, and shared directories so the
system matches the expected final state.

TASKS:
- Create a group: project
- Create a user: alice
  - Primary group: project
  - Supplementary group: wheel
  - Home: /home/alice (owned alice:project)
  - Shell: /bin/bash
- Create a system user: svcapp
  - Primary group: project
  - Home: /srv/svcapp (owned svcapp:project, mode 750)
  - Shell: /usr/sbin/nologin
- Create a shared directory: /srv/project
  - Owner/group: root:project
  - Permissions: 2775 (setgid for group inheritance)

NOTES:
- Run commands as root.
- Passwords are not graded; focus on identity, groups, ownership, and permissions.

When ready, run:
  sudo labctl grade users-01

====================================================

EOF
