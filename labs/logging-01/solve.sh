#!/bin/bash
# Reference solution for logging-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /home/opsadmin/journal-lab
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

dir=$(getent passwd "$SOLVE_USER" | cut -d: -f6)/journal-lab

# Steps 1 to 5 [sudo]. Root runs journalctl; the files are then given to
# the task user, as the redirection would do for a user running sudo.
cd "$dir"
journalctl -t labjournal > all.txt
journalctl -t labjournal -p err > errors.txt
journalctl -t labjournal -p warning > warnings.txt
journalctl -t labjournal -n 3 -q | tac > latest.txt
journalctl -t labjournal -p err -o json > errors.json
chown "$SOLVE_USER": all.txt errors.txt warnings.txt latest.txt errors.json
