#!/bin/bash
# dns-01 cleanup: remove BIND and everything it leaves behind.
systemctl disable --now named >/dev/null 2>&1 || true
dnf -y -q remove bind bind-chroot bind-utils >/dev/null 2>&1 || true
rm -f /opt/linux-labs/state/dns-01
exit 0
