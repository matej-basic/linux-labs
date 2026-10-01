#!/bin/bash
# packages-03 cleanup: remove the file list. curl stays installed (it is
# part of the base system and other tools depend on it).
rm -f /tmp/curl-files.txt
exit 0
