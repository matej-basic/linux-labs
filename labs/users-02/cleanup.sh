#!/bin/bash
userdel -r dave >/dev/null 2>&1
userdel -r eve >/dev/null 2>&1
groupdel contractors >/dev/null 2>&1
rm -f /etc/security/limits.d/70-contractors.conf
