#!/bin/bash
# packages-04 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/packages-04
export LANG=C

grade_begin packages-04
grade_require_state packages-04 "$STATE_FILE"

start_id=$(< "$STATE_FILE")
case "$start_id" in
	'' | *[!0-9]*) grade_abort "Lab state is valid (run labctl reset, then start again)" ;;
esac

last_id=$(dnf history list 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {print $1}' | sort -n | tail -n 1)
last_id=${last_id:-0}

# First transaction after the start that installed joe from a local file
# (dnf shows the repository @commandline), then the first transaction after
# that one that removed joe.
install_id=""
remove_id=""
for ((id = start_id + 1; id <= last_id; id++)); do
	info=$(dnf history info "$id" 2>/dev/null) || continue
	if [ -z "$install_id" ]; then
		grep -Eq '^[[:space:]]+Install[[:space:]]+joe-[0-9].*@@?commandline[[:space:]]*$' <<< "$info" && install_id=$id
	elif [ -z "$remove_id" ]; then
		grep -Eq '^[[:space:]]+Removed[[:space:]]+joe-[0-9]' <<< "$info" && remove_id=$id
	fi
done

rc=1; [ -n "$install_id" ] && rc=0
criterion_result "joe was installed with dnf from a local RPM file" "$rc"
rc=1; [ -n "$remove_id" ] && rc=0
criterion_result "joe was removed with dnf after the file install" "$rc"
criterion "Package joe is not installed" bash -c '! rpm -q joe'
criterion "Command joe is not available" bash -c '! command -v joe'
grade_end
