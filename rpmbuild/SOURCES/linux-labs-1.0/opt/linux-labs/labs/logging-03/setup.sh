#!/bin/bash
# Logging Lab 03: Persistent Journal and Boot Troubleshooting (Advanced)

cat <<'EOF'
====================================================
LAB: Logging 03 - Persistent Journal & Boot Analysis
====================================================

OBJECTIVE
Enable persistent systemd journal storage, query previous boots,
and analyze boot performance.

REQUIREMENTS
1) Create /var/log/journal with mode 755.
2) Restart systemd-journald to enable persistent storage.
3) Verify journal is persistent: journalctl --disk-usage
4) Create test service at /etc/systemd/system/labtest-fail.service with the following settings:
   - Unit:
     * Description: Lab Test Fail Service
   - Service:
     * Type: simple
     * ExecStart: /bin/false
   - Install:
     * WantedBy: multi-user.target
5) Reload daemon and start the service (it should fail).

USEFUL COMMANDS
- journalctl --list-boots          List all boot sessions
- journalctl -b -1                 Query previous boot
- journalctl -b                    Current boot
- journalctl -u labtest-fail       Query test service logs
- systemd-analyze time             Show boot time
- systemd-analyze blame            Show slow services
- systemd-analyze critical-chain   Show boot dependency chain
- dmesg                            Kernel ring buffer
- journalctl -b -g kernel          Kernel messages from journal

Run grading when done:
  sudo labctl grade logging-03
====================================================
EOF
