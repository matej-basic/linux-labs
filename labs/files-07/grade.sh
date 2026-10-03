#!/bin/bash
# files-07 grader. The snapshot before lab-churn is the newest older
# snapshot that still has the file lab-churn deletes, so extra runs of
# the script or of the timer do not change the result.
source /opt/linux-labs/lib/grading.sh

LAB=files-07
STATE_DIR=/opt/linux-labs/state/$LAB
SCRIPT=/usr/local/sbin/snapshot-backup
DATA=/srv/data
SNAPS=/backup/snapshots
SERVICE="snapshot-backup.service"
TIMER="snapshot-backup.timer"
UNCHANGED=projects/plan.txt
CHANGED=projects/notes.txt
ADDED=reports/q3.csv
DELETED=reports/q2.csv
export LC_ALL=C

grade_begin files-07
grade_require_state files-07 "$STATE_DIR/flags"

# The snapshot directories, oldest first
snaps=()
for d in "$SNAPS"/*; do
	[ -d "$d" ] && [ ! -L "$d" ] || continue
	[[ ${d##*/} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$ ]] || continue
	snaps+=("${d##*/}")
done
newest=""
before=""
if [ "${#snaps[@]}" -gt 0 ]; then
	newest=$SNAPS/${snaps[${#snaps[@]} - 1]}
	for ((i = ${#snaps[@]} - 2; i >= 0; i--)); do
		if [ -e "$SNAPS/${snaps[i]}/$DELETED" ]; then
			before=$SNAPS/${snaps[i]}
			break
		fi
	done
fi

# manifest <dir>: one line per entry below the directory, sorted by
# path, without .cache files: <path> <type> <mode> <owner> <group>
# <mtime> <sha256>, where mtime and sha256 are "-" for anything but a
# regular file
manifest() (
	cd "$1" 2>/dev/null || exit 1
	find . -mindepth 1 ! -name '*.cache' | sort | while read -r p; do
		if [ -L "$p" ]; then t=l
		elif [ -d "$p" ]; then t=d
		elif [ -f "$p" ]; then t=f
		else t=o
		fi
		m=- s=-
		if [ "$t" = f ]; then
			m=$(stat -c %Y "$p")
			s=$(sha256sum < "$p" | cut -c 1-64)
		fi
		printf '%s %s %s %s %s\n' "$p" "$t" "$(stat -c '%a %U %G' "$p")" "$m" "$s"
	done
)

source_now=$(manifest "$DATA")
snapshot=""
[ -n "$newest" ] && snapshot=$(manifest "$newest")

# same <fields> <expected> <actual>: the selected fields of two
# manifests are equal and neither is empty
same() {
	[ -n "$2" ] && [ -n "$3" ] || return 1
	[ "$(printf '%s\n' "$2" | cut -d ' ' -f "$1")" = "$(printf '%s\n' "$3" | cut -d ' ' -f "$1")" ]
}

script_ok() {
	local mode
	[ -f "$SCRIPT" ] && [ ! -L "$SCRIPT" ] || return 1
	[ "$(stat -c %U "$SCRIPT")" = root ] || return 1
	mode=$(stat -c %a "$SCRIPT")
	[ $((0$mode & 0100)) -ne 0 ]
}

latest_ok() {
	[ -n "$newest" ] && [ -L "$SNAPS/latest" ] || return 1
	[ "$(readlink -f "$SNAPS/latest")" = "$(readlink -f "$newest")" ]
}

no_cache() {
	[ "${#snaps[@]}" -gt 0 ] || return 1
	[ -z "$(find "$SNAPS" -name '*.cache' -print -quit 2>/dev/null)" ]
}

churn_ran() {
	[ -s "$STATE_DIR/churn" ]
}

inode() {
	stat -c %i "$1" 2>/dev/null
}

unchanged_linked() {
	local a b
	[ -n "$before" ] || return 1
	[ -f "$before/$UNCHANGED" ] && [ -f "$newest/$UNCHANGED" ] || return 1
	a=$(inode "$before/$UNCHANGED")
	b=$(inode "$newest/$UNCHANGED")
	[ "$a" = "$b" ]
}

changed_copied() {
	local a b
	[ -n "$before" ] || return 1
	[ -f "$before/$CHANGED" ] && [ -f "$newest/$CHANGED" ] || return 1
	a=$(inode "$before/$CHANGED")
	b=$(inode "$newest/$CHANGED")
	[ "$a" != "$b" ]
}

deleted_gone() {
	[ -n "$newest" ] && [ ! -e "$newest/$DELETED" ]
}

added_present() {
	[ -n "$newest" ] && [ -f "$newest/$ADDED" ]
}

prop() {
	systemctl show -p "$2" --value "$1" 2>/dev/null
}

service_ok() {
	[ "$(prop "$SERVICE" LoadState)" = loaded ] || return 1
	[ "$(prop "$SERVICE" Type)" = oneshot ] || return 1
	prop "$SERVICE" ExecStart | grep -q "path=$SCRIPT ;"
}

# Exactly one calendar event, daily at 02:30. systemctl shows it
# normalized (systemd 239 and 252 alike), so 02:30 and *-*-* 02:30:00
# both give *-*-* 02:30:00.
daily_0230() {
	local cal
	[ "$(prop "$TIMER" LoadState)" = loaded ] || return 1
	cal=$(prop "$TIMER" TimersCalendar | grep -o 'OnCalendar=[^;]*' |
		sed 's/^OnCalendar=//; s/ *$//')
	[ "$cal" = "*-*-* 02:30:00" ]
}

criterion "$SCRIPT is root-owned and executable" script_ok
criterion "2 or more YYYY-MM-DD_HHMMSS snapshots in $SNAPS" test "${#snaps[@]}" -ge 2
criterion "$SNAPS/latest links to the newest snapshot" latest_ok
criterion "No snapshot contains a .cache file" no_cache
criterion "lab-churn has run" churn_ran
criterion "The newest snapshot has no $DELETED" deleted_gone
criterion "The newest snapshot has $ADDED" added_present
criterion "The newest snapshot has the files of $DATA" same 1,2,7 "$source_now" "$snapshot"
criterion "The snapshot keeps owners, groups and modes" same 1,3,4,5 "$source_now" "$snapshot"
criterion "The snapshot keeps the file modification times" same 1,6 "$source_now" "$snapshot"
criterion "Unchanged $UNCHANGED is a hard link to the older copy" unchanged_linked
criterion "Changed $CHANGED is a new copy, not a hard link" changed_copied
criterion "$SERVICE is oneshot and runs the script" service_ok
criterion "$TIMER runs every day at 02:30" daily_0230
criterion "$TIMER has Persistent=true" test "$(prop "$TIMER" Persistent)" = yes
criterion "$TIMER is enabled" systemctl is-enabled --quiet "$TIMER"
criterion "$TIMER is active" systemctl is-active --quiet "$TIMER"
grade_end
