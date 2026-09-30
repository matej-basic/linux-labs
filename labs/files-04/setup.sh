#!/bin/bash

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/files-04"

# Lab owner: the user who ran sudo, else "student". If that user does not
# exist, use the first regular user (UID >= 1000), else root.
owner="${SUDO_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	owner="${owner:-root}"
fi

# Reset lab state
rm -rf /srv/archive
mkdir -p /srv/archive
chown "$owner": /srv/archive
chmod 755 /srv/archive

# Record the owner for the grader (readable by unprivileged users)
mkdir -p "$STATE_DIR"
echo "$owner" > "$STATE_FILE"
chmod 644 "$STATE_FILE"

# Print task description
cat <<'EOF'

====================================================
LAB: Brace Expansion and File Organisation (files-04)
====================================================

OBJECTIVE:
Create many files with brace expansion and sort them
into a directory tree by name.

REQUIREMENTS:
- Work as your normal user, NOT as root and without sudo
- In /srv/archive, run exactly this command:

    touch {report,memo,chart}_{sep,oct,nov,dec}_{a,b,c}{1,2,3}

  It creates 108 files.

- Move every file into a directory tree based on its name:

    /srv/archive
    ├── chart
    │   ├── dec
    │   ├── nov
    │   ├── oct
    │   └── sep
    ├── memo
    │   └── (same four months)
    └── report
        ├── dec
        ├── nov
        ├── oct
        └── sep
            ├── report_sep_a1
            ├── report_sep_a2
            ├── ...
            └── report_sep_c3

  Every file goes to <type>/<month>/ in the same way
  (for example chart_dec_b2 goes to chart/dec/).
  Each of the 12 month directories ends up with 9 files.

- Nothing else may be left in /srv/archive or in the
  type directories, and everything must belong to your user

NOTES:
- You may use any valid Linux commands
- The grading script checks only the final state
- Command history is NOT evaluated
- Tips: man mv, mkdir --help, and Tab completion

When ready, run:
  sudo labctl grade files-04

====================================================

EOF
