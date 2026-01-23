#!/bin/bash

# Reset lab state
userdel -r bob >/dev/null 2>&1
userdel -r charlie >/dev/null 2>&1
groupdel devops >/dev/null 2>&1
groupdel analytics >/dev/null 2>&1
rm -rf /srv/shared /home/bob /home/charlie

# Print task description
cat <<'EOF'

====================================================
LAB: Advanced Users and Groups (users-02)
====================================================

OBJECTIVE:
Create users, groups, and shared directories with ACLs and
permissions that enforce access control for different roles.

TASKS:

1. Create groups:
   - devops (GID 2000)
   - analytics (GID 2001)

2. Create user bob:
   - UID: 1010
   - Primary group: devops
   - Supplementary groups: wheel, analytics
   - Home: /home/bob (mode 750, owned bob:devops)
   - Shell: /bin/bash

3. Create user charlie:
   - UID: 1011
   - Primary group: analytics
   - Supplementary group: wheel
   - Home: /home/charlie (mode 750, owned charlie:analytics)
   - Shell: /bin/bash
   - Account expiration: 2099-12-31 (far future for grading)

4. Create shared directory: /srv/shared
   - Owner/group: root:devops
   - Permissions: 750
   - Apply default ACL so new files inherit group devops with rw-
     Example: setfacl -d -m g:devops:rwx /srv/shared

5. Set up sub-directory: /srv/shared/analytics
   - Owner/group: root:analytics
   - Permissions: 750
   - ACL so charlie (analytics member) can read/write
     Example: setfacl -m u:charlie:rwx /srv/shared/analytics

NOTES:
- Use getent, id, chage, getfacl to verify settings.
- Passwords are not graded.
- Focus on UIDs, GIDs, group membership, ACLs, and expiration.

When ready, run:
  sudo labctl grade users-02

====================================================

EOF
