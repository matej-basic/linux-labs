#!/bin/bash
userdel -r bob >/dev/null 2>&1
userdel -r charlie >/dev/null 2>&1
groupdel devops >/dev/null 2>&1
groupdel analytics >/dev/null 2>&1
rm -rf /srv/shared /home/bob /home/charlie
