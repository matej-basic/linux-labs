#!/bin/bash
# Reference solution for scripting-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /usr/local/bin/filecount
# solve: path /usr/local/bin/userinfo
# solve: path /srv/scripting
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
cat > /usr/local/bin/filecount <<'SCRIPT'
#!/bin/bash
# Print the number of lines of every regular file in a directory.
if [ "$#" -ne 1 ]; then
  echo "Usage: filecount <directory>" >&2
  exit 2
fi
dir=$1
if [ ! -d "$dir" ]; then
  echo "Not a directory: $dir" >&2
  exit 1
fi
total=0
for path in "$dir"/*; do
  [ -f "$path" ] || continue
  lines=$(wc -l < "$path")
  echo "${path##*/} $lines"
  total=$((total + lines))
done
echo "total $total"
SCRIPT

# Step 2 [sudo]
cat > /usr/local/bin/userinfo <<'SCRIPT'
#!/bin/bash
# Report whether users exist, with their UID and login shell.
if [ "$#" -eq 0 ]; then
  echo "Usage: userinfo <user>..." >&2
  exit 2
fi
status=0
for user; do
  if entry=$(getent passwd "$user"); then
    uid=$(echo "$entry" | cut -d: -f3)
    shell=$(echo "$entry" | cut -d: -f7)
    echo "$user exists $uid $shell"
  else
    echo "$user missing"
    status=1
  fi
done
exit "$status"
SCRIPT

# Step 3 [sudo]
chmod 755 /usr/local/bin/filecount /usr/local/bin/userinfo

# Step 4 [user]
run_as_student <<'STEPS'
filecount /srv/scripting/reports >/dev/null
userinfo root "$USER" >/dev/null
STEPS
