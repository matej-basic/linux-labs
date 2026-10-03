#!/bin/bash
# scripting-01 grader: runs the student's scripts as the task user with
# LC_ALL=C and compares stdout, stderr and the exit status with the
# expected values. filecount also runs on a directory the grader creates
# with random names and line counts, so hardcoded output fails.
source /opt/linux-labs/lib/grading.sh

ROOT=/srv/scripting
BIN=/usr/local/bin
STATE_FILE=/opt/linux-labs/state/scripting-01

grade_begin scripting-01
grade_require_state scripting-01 "$STATE_FILE"
owner=$(head -n 1 "$STATE_FILE")

WORK=$(mktemp -d /tmp/scripting-01.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
chmod 755 "$WORK"
OUT="$WORK/.out"
ERR="$WORK/.err"
EXP="$WORK/.exp"

# run_user <args...>: run the command as the task user in a login shell
# with LC_ALL=C; stdout to $OUT, stderr to $ERR, returns its exit status
run_user() {
	local cmd="LC_ALL=C" a
	for a in "$@"; do
		cmd+=" $(printf '%q' "$a")"
	done
	timeout 20 runuser -l "$owner" -c "$cmd" >"$OUT" 2>"$ERR" </dev/null
}

# expect <rc> <wanted rc> <stdout text> <stderr text>: compare exactly;
# an empty text means the stream must be empty
expect() {
	[ "$1" = "$2" ] || return 1
	if [ -n "$3" ]; then printf '%s\n' "$3" > "$EXP"; else : > "$EXP"; fi
	cmp -s "$EXP" "$OUT" || return 1
	if [ -n "$4" ]; then printf '%s\n' "$4" > "$EXP"; else : > "$EXP"; fi
	cmp -s "$EXP" "$ERR"
}

rand_word() {
	LC_ALL=C tr -dc '[:lower:]' < /dev/urandom 2>/dev/null | head -c "$1"
}

# The expected filecount output for a directory, computed from its files
expected_count() {
	local dir=$1 name n total=0 out=""
	while IFS= read -r name; do
		n=$(wc -l < "$dir/$name")
		out+="$name $n"$'\n'
		total=$((total + n))
	done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f ! -name '.*' -printf '%f\n' | LC_ALL=C sort)
	printf '%stotal %d' "$out" "$total"
}

# A directory with random file names and line counts, a hidden file and
# a subdirectory with a file in it; every file ends with a newline
make_random_dir() {
	local dir=$1 i j k n name sub
	mkdir -p "$dir"
	k=$((RANDOM % 3 + 3))
	for ((i = 0; i < k; i++)); do
		name="$(rand_word 5)$((RANDOM % 100)).txt"
		n=$((RANDOM % 25))
		: > "$dir/$name"
		for ((j = 1; j <= n; j++)); do
			echo "row $j" >> "$dir/$name"
		done
	done
	printf 'a\nb\nc\n' > "$dir/.$(rand_word 6)"
	sub="$dir/$(rand_word 6)"
	mkdir "$sub"
	printf 'x\ny\n' > "$sub/inner.txt"
	find "$dir" -type d -exec chmod 755 {} +
	find "$dir" -type f -exec chmod 644 {} +
}

# The script exists, is a regular executable file and starts with
# #!/bin/bash
is_bash_script() {
	local f=$1 first
	[ -f "$f" ] || return 1
	[ $((0$(stat -c %a "$f") & 0111)) -ne 0 ] || return 1
	local re='^#!/bin/bash([[:space:]].*)?$'
	IFS= read -r first < "$f" || return 1
	[[ $first =~ $re ]]
}

# The task user can read and run both scripts
user_can_run() {
	runuser -l "$owner" -c "test -r $BIN/filecount && test -x $BIN/filecount && test -r $BIN/userinfo && test -x $BIN/userinfo" </dev/null
}

filecount_usage() {
	local rc u="Usage: filecount <directory>"
	run_user "$BIN/filecount"; rc=$?
	expect "$rc" 2 "" "$u" || return 1
	run_user "$BIN/filecount" "$ROOT/reports" "$ROOT/configs"; rc=$?
	expect "$rc" 2 "" "$u"
}

filecount_notdir() {
	local rc missing
	missing="$ROOT/no-$(rand_word 6)"
	run_user "$BIN/filecount" "$ROOT/reports/alpha.txt"; rc=$?
	expect "$rc" 1 "" "Not a directory: $ROOT/reports/alpha.txt" || return 1
	run_user "$BIN/filecount" "$missing"; rc=$?
	expect "$rc" 1 "" "Not a directory: $missing"
}

filecount_dir() {
	local rc
	[ -d "$1" ] || return 1
	run_user "$BIN/filecount" "$1"; rc=$?
	expect "$rc" 0 "$(expected_count "$1")" ""
}

filecount_setup() {
	filecount_dir "$ROOT/reports" &&
		filecount_dir "$ROOT/configs" &&
		filecount_dir "$ROOT/empty"
}

filecount_random() {
	local d1 d2
	d1="$WORK/$(rand_word 8)"
	d2="$WORK/$(rand_word 8)"
	make_random_dir "$d1"
	make_random_dir "$d2"
	filecount_dir "$d1" && filecount_dir "$d2"
}

# userinfo line for an existing user, from the passwd database
info_line() {
	getent passwd "$1" | awk -F: -v n="$1" '{ print n " exists " $3 " " $7 }'
}

# Pick existing users in a random order: the task user, root and two
# other accounts with a login shell field
pick_users() {
	{
		getent passwd | awk -F: -v o="$owner" \
			'$1 != "root" && $1 != o && $7 != "" { print $1 }' | shuf -n 2
		echo root
		echo "$owner"
	} | shuf
}

missing_name() {
	local n
	while :; do
		n="nouser$(rand_word 6)"
		getent passwd "$n" >/dev/null || { echo "$n"; return; }
	done
}

userinfo_existing() {
	local rc u users=() exp=""
	mapfile -t users < <(pick_users)
	for u in "${users[@]}"; do
		exp+="$(info_line "$u")"$'\n'
	done
	run_user "$BIN/userinfo" "${users[@]}"; rc=$?
	expect "$rc" 0 "${exp%$'\n'}" ""
}

userinfo_missing() {
	local rc users=() m1 m2 exp
	mapfile -t users < <(pick_users)
	m1=$(missing_name)
	m2=$(missing_name)
	exp="$(info_line "${users[0]}")"$'\n'"$m1 missing"$'\n'
	exp+="$(info_line "${users[1]}")"$'\n'"$m2 missing"
	run_user "$BIN/userinfo" "${users[0]}" "$m1" "${users[1]}" "$m2"; rc=$?
	expect "$rc" 1 "$exp" "" || return 1
	run_user "$BIN/userinfo" "$m1"; rc=$?
	expect "$rc" 1 "$m1 missing" ""
}

userinfo_usage() {
	local rc
	run_user "$BIN/userinfo"; rc=$?
	expect "$rc" 2 "" "Usage: userinfo <user>..."
}

criterion "$BIN/filecount is an executable Bash script" is_bash_script "$BIN/filecount"
criterion "$BIN/userinfo is an executable Bash script" is_bash_script "$BIN/userinfo"
criterion "Both scripts can be run by $owner without root" user_can_run
criterion "filecount without exactly one argument: usage, exit 2" filecount_usage
criterion "filecount on a non-directory: error message, exit 1" filecount_notdir
criterion "filecount output is correct for the $ROOT directories" filecount_setup
criterion "filecount output is correct for new directories" filecount_random
criterion "userinfo reports existing users in order, exit 0" userinfo_existing
criterion "userinfo reports missing users, exit 1" userinfo_missing
criterion "userinfo without arguments: usage, exit 2" userinfo_usage
grade_end
