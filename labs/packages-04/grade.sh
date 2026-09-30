#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

STATE_FILE=/opt/linux-labs/state/packages-04
export LANG=C

if [[ ! -r "$STATE_FILE" ]]; then
	fail "Start state not found. Run: sudo labctl start packages-04"
	echo ""
	echo "Results: $passcount passed, $failcount failed"
	fail "Lab incomplete"
	exit 1
fi
start_id=$(< "$STATE_FILE")
if [[ ! "$start_id" =~ ^[0-9]+$ ]]; then
	fail "Start state is corrupt. Run: sudo labctl reset packages-04, then start the lab again"
	echo ""
	echo "Results: $passcount passed, $failcount failed"
	fail "Lab incomplete"
	exit 1
fi

last_id=$(dnf history list 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {print $1}' | sort -n | tail -1)
last_id=${last_id:-0}

# First transaction after start that installed joe from a local file (dnf shows repo @commandline),
# and first transaction after that one that removed joe.
install_id=""
remove_id=""
for ((id = start_id + 1; id <= last_id; id++)); do
	info=$(dnf history info "$id" 2>/dev/null) || continue
	if [[ -z "$install_id" ]]; then
		grep -Eq '^[[:space:]]+Install[[:space:]]+joe-[0-9].*@@?commandline[[:space:]]*$' <<< "$info" && install_id=$id
	elif [[ -z "$remove_id" ]]; then
		grep -Eq '^[[:space:]]+Removed[[:space:]]+joe-[0-9]' <<< "$info" && remove_id=$id
	fi
done

[[ -n "$install_id" ]] && pass "joe was installed with dnf from a local RPM file (transaction $install_id)" || { fail "No dnf transaction installed joe from a downloaded RPM file"; rc=1; }
[[ -n "$remove_id" ]] && pass "joe was removed with dnf after it was installed (transaction $remove_id)" || { fail "No dnf transaction removed joe after the file install"; rc=1; }
! rpm -q joe &>/dev/null && pass "joe package is not installed now" || { fail "joe package is still installed"; rc=1; }
! command -v joe &>/dev/null && pass "joe command is not available now" || { fail "joe command still found"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi
