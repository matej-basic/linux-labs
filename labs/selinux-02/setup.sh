#!/bin/bash

# Reset lab state
rm -rf /webapp

# Ensure selinux is in enforcing mode
sudo setenforce 1 2>/dev/null || true
sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true

# Print task description
cat <<'EOF'

====================================================
LAB: SELinux File Contexts and Denials (selinux-02)
====================================================

OBJECTIVE:
Identify and fix SELinux denials by restoring file contexts
and setting custom contexts for application directories.

TASKS:

1. Create application directories under /webapp:
    - /webapp/www (for web files)
    - /webapp/config (for configuration files)
    - /webapp/data (for data files)

2. Create sample files:
   Create a simple HTML page at /webapp/www/index.html
   Create config file: /webapp/config/db.conf
   Create log file: /webapp/data/app.log

3. Install and configure Apache:
   - Install Apache web server
   - Create a virtual host pointing to /webapp/www
   - Ensure httpd is enabled and running

4. Verify default contexts (use: ls -Z)

5. Fix /webapp/www for Apache access:

6. Check for and resolve SELinux denials:

7. Restore to system defaults:

NOTES:
- Context format: user:role:type:level
- system_u: system user context
- unconfined_u: unconfined user context
- httpd_sys_rw_content_t: Apache read/write content
- Use -Z flag with ls, id, ps to see contexts
- ausearch requires audit daemon (auditd)

When ready, run:
  sudo labctl grade selinux-02

====================================================

EOF
