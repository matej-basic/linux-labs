#!/bin/bash
# Reference solution for files-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /tmp/webfiles
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
mkdir -p /tmp/webfiles/app /tmp/webfiles/config /tmp/webfiles/data

# Step 2 [sudo]
touch /tmp/webfiles/app/index.php /tmp/webfiles/app/upload.php
touch /tmp/webfiles/config/db.conf
touch /tmp/webfiles/data/app.log /tmp/webfiles/data/error.log

# Step 3 [sudo]
chown root:root /tmp/webfiles /tmp/webfiles/config
chown apache:apache /tmp/webfiles/app /tmp/webfiles/data
chmod 755 /tmp/webfiles /tmp/webfiles/app /tmp/webfiles/data
chmod 700 /tmp/webfiles/config

# Step 4 [sudo]
chown apache:apache /tmp/webfiles/app/index.php \
	/tmp/webfiles/app/upload.php /tmp/webfiles/data/app.log
chown root:root /tmp/webfiles/config/db.conf /tmp/webfiles/data/error.log
chmod 644 /tmp/webfiles/app/index.php /tmp/webfiles/app/upload.php \
	/tmp/webfiles/data/error.log
chmod 640 /tmp/webfiles/data/app.log
chmod 600 /tmp/webfiles/config/db.conf
