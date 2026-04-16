#!/bin/bash
echo "Cleaning up files-03 lab environment..."
rm -rf /srv/secure /tmp/backup.tar.gz
userdel -r alice >/dev/null 2>&1 || true
groupdel developers >/dev/null 2>&1 || true
echo "Cleanup complete."
