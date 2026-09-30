#!/bin/bash
rm -rf /tmp/webfiles /tmp/config

# Remove the apache user only if setup.sh created it (httpd not installed)
if ! rpm -q httpd >/dev/null 2>&1 && getent passwd apache >/dev/null; then
    userdel apache
fi
