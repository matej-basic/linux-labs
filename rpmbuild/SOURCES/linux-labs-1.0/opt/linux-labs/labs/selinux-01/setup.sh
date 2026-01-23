#!/bin/bash

# Print task description
cat <<'EOF'

====================================================
LAB: SELinux Basics - Modes and Status (selinux-01)
====================================================

OBJECTIVE:
Understand and manage SELinux modes (enforcing, permissive, disabled)
and configure persistent SELinux policy settings.

TASKS:

1. Check current SELinux status:
   - Run: getenforce
   - Run: sestatus (or sestatus -v for verbose)
   - Note the current mode (likely enforcing or permissive)

2. Understand the three SELinux modes:
   - enforcing: Policy is enforced, violations are blocked and logged
   - permissive: Policy is NOT enforced, violations are only logged (useful for debugging)
   - disabled: SELinux is completely disabled

3. Temporarily switch to permissive mode (requires root):
   - Command: setenforce 0
   - Verify: getenforce (should show "Permissive")
   - This change is temporary (lost on reboot)

4. Switch back to enforcing mode:
   - Command: setenforce 1
   - Verify: getenforce (should show "Enforcing")

5. Make SELinux mode persistent:
   - Edit /etc/selinux/config
   - Find the line: SELINUX=<mode>
   - Set it to: SELINUX=enforcing
   - Save and verify with: grep "^SELINUX=" /etc/selinux/config

6. Check SELinux policy type:
   - Run: getenforce (or cat /etc/selinux/config)
   - Typical policies: targeted, mls, strict
   - Verify with: sestatus | grep "Loaded policy"

NOTES:
- All commands require root (use sudo)
- Changes to /etc/selinux/config take effect after reboot
- Temporary mode changes with setenforce are useful for troubleshooting
- The lab verifies final state, not the history of commands used

When ready, run:
  sudo labctl grade selinux-01

====================================================

EOF
