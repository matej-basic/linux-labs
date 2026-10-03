#!/bin/bash
# scripting-01 cleanup: remove the test directories, both scripts and the
# state file. Safe when the lab was never started.
rm -rf /srv/scripting
rm -f /usr/local/bin/filecount /usr/local/bin/userinfo
rm -f /opt/linux-labs/state/scripting-01
rm -rf /tmp/scripting-01.*
exit 0
