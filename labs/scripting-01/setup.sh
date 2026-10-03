#!/bin/bash
# scripting-01 setup: test directories under /srv/scripting with files of
# known line counts, plus a hidden file and a subdirectory that the
# student's filecount script must ignore. Removes scripts left by an
# earlier run. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/scripting-01"
ROOT=/srv/scripting

owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	owner="${owner:-root}"
fi

# make_file <path> <lines>: a file with that many lines, each ending in a
# newline (0 lines is an empty file)
make_file() {
	local path=$1 n=$2 i
	: > "$path"
	for ((i = 1; i <= n; i++)); do
		printf 'line %d of %s\n' "$i" "${path##*/}" >> "$path"
	done
}

# Remove what an earlier run or the solution left behind
rm -rf "$ROOT"
rm -f /usr/local/bin/filecount /usr/local/bin/userinfo

mkdir -p "$ROOT/reports/archive" "$ROOT/configs/backup" "$ROOT/empty"
make_file "$ROOT/reports/alpha.txt" 3
make_file "$ROOT/reports/beta.txt" 10
make_file "$ROOT/reports/notes" 1
make_file "$ROOT/reports/z-last.csv" 5
make_file "$ROOT/reports/.draft" 4
make_file "$ROOT/reports/archive/old.txt" 7
make_file "$ROOT/configs/app.conf" 12
make_file "$ROOT/configs/db.conf" 6
make_file "$ROOT/configs/empty.conf" 0
make_file "$ROOT/configs/web1.conf" 2
make_file "$ROOT/configs/web10.conf" 8
make_file "$ROOT/configs/web2.conf" 2
make_file "$ROOT/configs/.cache" 2
make_file "$ROOT/configs/backup/app.conf.1" 11
chown -R root:root "$ROOT"
find "$ROOT" -type d -exec chmod 755 {} +
find "$ROOT" -type f -exec chmod 644 {} +

mkdir -p "$STATE_DIR"
echo "$owner" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
