#!/bin/bash
# logging-01 cleanup: removes the working directory and the state file.
# The test entries stay in the journal; journald rotates them itself.
STATE_FILE=/opt/linux-labs/state/logging-01

if [ -r "$STATE_FILE" ]; then
	dir=$(sed -n 's/^DIR=//p' "$STATE_FILE")
	case "$dir" in
		/*/journal-lab) rm -rf "$dir" ;;
	esac
fi
rm -f "$STATE_FILE"
exit 0
