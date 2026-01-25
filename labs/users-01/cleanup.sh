#!/bin/bash
userdel -r alice >/dev/null 2>&1
userdel -r svcapp >/dev/null 2>&1
groupdel project >/dev/null 2>&1
rm -rf /home/alice /srv/project /srv/svcapp
