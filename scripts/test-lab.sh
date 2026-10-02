#!/usr/bin/env bash
# Runtime test for converted labs (lab framework 2.0), run from the Mac.
#
# Usage: scripts/test-lab.sh <host> <lab>...
#
# <host> is the workstation. It must have the linux-labs RPM installed, a
# "student" user and root SSH access with a key (BatchMode). The script
# copies the working tree's labctl, lib/*.sh and the lab directories
# (without solve.sh) over the installed RPM files, plus the man page and
# the profile script when they differ, and runs restorecon on them.
#
# A lab with "target: servera" (serverb, serverc) in description.txt runs
# on that server through labctl on the workstation. The server's address
# and the task user (SSH_USER, opsadmin) come from the workstation's lab
# configuration (servera is node 1, serverb node 2, serverc node 3), and
# the Mac needs root SSH access to the server too. solve.sh, the reboot
# and the leftover checks then happen on the server. Workstation and
# multi-node labs run as before on <host>, with student as the task user.
#
# Strictly one lab after the other, it runs:
#
#   su - student -c "sudo labctl start <lab>"    expect exit 0
#   su - student -c "labctl task <lab>"          expect exit 0
#   su - student -c "labctl grade <lab>"         expect exit 1
#   solve.sh as root from a temporary directory  expect exit 0
#     on the lab's machine; run_as_student runs as the task user
#   (reboot that machine and wait for a new boot_id if solve.sh has
#   "# solve: reboot")
#   su - student -c "labctl grade <lab>"         expect exit 0
#   labctl grade <lab> as root                   expect exit 0
#   su - student -c "sudo labctl reset <lab>"    expect exit 0
#   su - student -c "labctl grade <lab>"         expect exit 1
#   the paths and packages declared in solve.sh, the state file
#   /opt/linux-labs/state/<lab> and /opt/linux-labs/.current_lab are gone
#   (on a server target also the server's marker and /var/lib/linux-labs)
#
# A lab without task.txt or solve.sh is a legacy lab and is skipped with a
# message. The run aborts before deploying anything if a lab is active on
# the host, and stops if a lab is still active after its reset.
#
# Output uses the lib/grading.sh format, one block per lab, then a summary.
# The full log (every command, its output and exit status) goes to
# packaging/test-logs/<timestamp>-<host>.log.
#
# Exit status: 0 all labs passed, 1 a lab failed or the run aborted,
# 2 no failures but at least one lab was skipped, 3 usage error.
#
# Nothing on the host is deleted except by the lab's own cleanup.sh and the
# temporary directory this script creates. The replaced RPM files show up
# in "rpm -V linux-labs"; "dnf reinstall linux-labs" restores them.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
# shellcheck source-path=SCRIPTDIR source=../src/opt/linux-labs/lib/grading.sh
source "$ROOT_DIR/src/opt/linux-labs/lib/grading.sh"

LAB_USER=student
REBOOT_TIMEOUT=600
# Server targets, filled in by the preflight from the workstation's config
TARGET_IPS=()
TARGET_USER=""

usage() {
	echo "Usage: $0 <host> <lab>..." >&2
}

if [ "$#" -lt 2 ]; then
	usage
	exit 3
fi
HOST="$1"
shift
LABS=("$@")

for lab in "${LABS[@]}"; do
	if ! printf '%s\n' "$lab" | grep -qxE '[a-z0-9][a-z0-9-]*'; then
		echo "Error: invalid lab name: $lab" >&2
		exit 3
	fi
	if [ ! -d "$ROOT_DIR/labs/$lab" ]; then
		echo "Error: no such lab: $lab" >&2
		exit 3
	fi
done

LOG_DIR="$ROOT_DIR/packaging/test-logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-$HOST.log"
: >"$LOG"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o LogLevel=ERROR)

log() {
	printf '%s\n' "$*" >>"$LOG"
}

# hssh <host> <command>: ssh to a host as root
hssh() {
	local h="$1"
	shift
	# shellcheck disable=SC2029 # commands are built locally on purpose
	ssh "${SSH_OPTS[@]}" "root@$h" "$@"
}

rssh() {
	hssh "$HOST" "$@"
}

# remote_at <host> <description> <command>
# Run a command on a host as root, log it, set OUT and RC.
OUT=""
RC=0
remote_at() {
	log ""
	log "---- $2 on $1 ($(date +%H:%M:%S))"
	log "\$ $3"
	OUT=$(hssh "$1" "$3" </dev/null 2>&1)
	RC=$?
	[ -n "$OUT" ] && printf '%s\n' "$OUT" >>"$LOG"
	log "[exit $RC]"
}

# remote <description> <command>: on the workstation
remote() {
	remote_at "$HOST" "$1" "$2"
}

# lab_target <lab>: workstation, servera, serverb or serverc
lab_target() {
	local t
	t=$(sed -n 's/^target: //p' "$ROOT_DIR/labs/$1/description.txt")
	echo "${t:-workstation}"
}

# target_ip <target>: the server's address from the workstation's config
target_ip() {
	case "$1" in
		servera) echo "${TARGET_IPS[0]:-}" ;;
		serverb) echo "${TARGET_IPS[1]:-}" ;;
		serverc) echo "${TARGET_IPS[2]:-}" ;;
	esac
}

# as_student <description> <command>
as_student() {
	remote "$1" "su - $LAB_USER -c '$2'"
}

# expect_rc <criterion text> <expected exit status>
expect_rc() {
	if [ "$RC" -eq "$2" ]; then
		criterion_result "$1" 0
	else
		criterion_result "$1" 1
		log "!! expected exit $2, got $RC"
	fi
}

STAGE=""
TSTAGE=""
TSTAGE_HOST=""
ACTIVE_LAB=""
# shellcheck disable=SC2329 # called from the EXIT trap
cleanup_stage() {
	if [ -n "$STAGE" ]; then
		rssh "rm -rf '$STAGE'" </dev/null >/dev/null 2>&1
	fi
	if [ -n "$TSTAGE" ]; then
		hssh "$TSTAGE_HOST" "rm -rf '$TSTAGE'" </dev/null >/dev/null 2>&1
	fi
	if [ -n "$ACTIVE_LAB" ]; then
		echo "Warning: lab $ACTIVE_LAB may still be active on $HOST. Run: sudo labctl reset $ACTIVE_LAB" >&2
	fi
}
trap cleanup_stage EXIT
trap 'echo "Interrupted." >&2; exit 1' INT TERM

echo "Log: ${LOG#"$ROOT_DIR"/}"
log "test-lab.sh $HOST ${LABS[*]}"
log "git: $(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null) $(git -C "$ROOT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ') changed paths"

# Split labs into testable and legacy
TESTABLE=()
for lab in "${LABS[@]}"; do
	if [ -f "$ROOT_DIR/labs/$lab/task.txt" ] && [ -f "$ROOT_DIR/labs/$lab/solve.sh" ]; then
		TESTABLE+=("$lab")
	fi
done

# --- Preflight and deployment ----------------------------------------------

abort() {
	echo "Error: $*" >&2
	log "ABORT: $*"
	exit 1
}

if [ "${#TESTABLE[@]}" -gt 0 ]; then
	remote "connectivity" "rpm -q linux-labs && id $LAB_USER && cat /etc/os-release | head -n 2 && getenforce"
	[ "$RC" -eq 0 ] || abort "cannot reach root@$HOST, or linux-labs or user $LAB_USER is missing (see log)"

	remote "active lab check" "cat /opt/linux-labs/.current_lab 2>/dev/null"
	if [ -n "$OUT" ]; then
		abort "lab '$OUT' is active on $HOST. Reset it first: sudo labctl reset $OUT"
	fi

	# Server targets: addresses and task user from the workstation's
	# config, root access from here, no active lab there
	targets=""
	for lab in "${TESTABLE[@]}"; do
		t=$(lab_target "$lab")
		[ "$t" = workstation ] && continue
		case " $targets " in *" $t "*) ;; *) targets="$targets $t" ;; esac
	done
	if [ -n "$targets" ]; then
		# The config may hold "$HOME"; use student's home as labctl does
		remote "server targets from the lab config" "HOME=/home/$LAB_USER; source /opt/linux-labs/lib/load-config.sh >/dev/null 2>&1; get_node_ip 1; get_node_ip 2; get_node_ip 3; echo \"\$SSH_USER\""
		[ "$RC" -eq 0 ] || abort "cannot read the lab configuration on $HOST (see log)"
		TARGET_IPS=()
		while IFS= read -r line; do TARGET_IPS+=("$line"); done <<<"$OUT"
		TARGET_USER="${TARGET_IPS[3]:-}"
		[ -n "$TARGET_USER" ] || abort "SSH_USER is empty in the lab configuration on $HOST"
		for t in $targets; do
			tip=$(target_ip "$t")
			[ -n "$tip" ] || abort "no address for $t in the lab configuration on $HOST"
			remote_at "$tip" "connectivity to $t" "id $TARGET_USER && getenforce"
			[ "$RC" -eq 0 ] || abort "cannot reach root@$tip ($t), or user $TARGET_USER is missing there (see log)"
			remote_at "$tip" "active lab check on $t" "cat /opt/linux-labs/.current_lab 2>/dev/null"
			if [ -n "$OUT" ]; then
				abort "lab '$OUT' is active on $t ($tip). Reset it first: sudo labctl reset $OUT"
			fi
		done
	fi

	remote "create staging directory" "mktemp -d /tmp/test-lab.XXXXXX"
	[ "$RC" -eq 0 ] || abort "cannot create a temporary directory on $HOST"
	STAGE="$OUT"

	files=(src/usr/bin/labctl scripts/solve-lib.sh src/usr/share/man/man1/labctl.1 src/etc/profile.d/labctl.sh)
	for f in "$ROOT_DIR"/src/opt/linux-labs/lib/*.sh; do
		files+=("src/opt/linux-labs/lib/${f##*/}")
	done
	for lab in "${TESTABLE[@]}"; do
		files+=("labs/$lab")
	done
	log ""
	log "---- upload to $STAGE: ${files[*]}"
	if ! (cd "$ROOT_DIR" && COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${files[@]}") \
		| rssh "tar --warning=no-unknown-keyword -xf - -C '$STAGE'" >>"$LOG" 2>&1; then
		abort "upload to $HOST failed"
	fi

	# labctl and the library always; man page and profile script only when
	# they differ from the installed ones
	remote "install labctl and lib" "set -e
install -m 0755 -o root -g root '$STAGE/src/usr/bin/labctl' /usr/bin/labctl
for f in '$STAGE'/src/opt/linux-labs/lib/*.sh; do
  install -m 0755 -o root -g root \"\$f\" /opt/linux-labs/lib/
done
man=/usr/share/man/man1/labctl.1.gz
if [ \"\$(zcat \$man 2>/dev/null | sha256sum)\" != \"\$(sha256sum < '$STAGE/src/usr/share/man/man1/labctl.1')\" ]; then
  gzip -9 -n -c '$STAGE/src/usr/share/man/man1/labctl.1' > \$man.tmp && mv -f \$man.tmp \$man && chmod 0644 \$man && echo 'man page updated'
fi
prof=/etc/profile.d/labctl.sh
if ! cmp -s '$STAGE/src/etc/profile.d/labctl.sh' \$prof; then
  install -m 0644 -o root -g root '$STAGE/src/etc/profile.d/labctl.sh' \$prof && echo 'profile script updated'
fi
restorecon -R /usr/bin/labctl /opt/linux-labs/lib \$man \$prof"
	[ "$RC" -eq 0 ] || abort "installing labctl and lib on $HOST failed (see log)"
fi

# --- Per-lab test ------------------------------------------------------------

# Install one lab directory from the staging area, without solve.sh
install_lab() {
	local lab="$1"
	remote "install $lab" "set -e
src='$STAGE/labs/$lab'
dst='/opt/linux-labs/labs/$lab'
install -d -m 0755 -o root -g root \"\$dst\"
for f in \"\$src\"/*; do
  name=\${f##*/}
  case \"\$name\" in
    solve.sh) continue ;;
    *.sh) mode=0755 ;;
    *) mode=0644 ;;
  esac
  install -m \$mode -o root -g root \"\$f\" \"\$dst/\$name\"
done
for f in \"\$dst\"/*; do
  [ -e \"\$src/\${f##*/}\" ] || echo \"note: \$f is not in the working tree (left in place)\"
done
restorecon -R \"\$dst\"
cp '$STAGE/scripts/solve-lib.sh' \"\$src/solve-lib.sh\""
	[ "$RC" -eq 0 ]
}

# Print the "# solve:" directives of a lab: "<kind> <value>"
directives() {
	sed -n 's/^# solve: \([a-z]*\) *\(.*\)$/\1 \2/p' "$ROOT_DIR/labs/$1/solve.sh"
}

boot_id() {
	hssh "$1" "cat /proc/sys/kernel/random/boot_id" </dev/null 2>/dev/null
}

# reboot_host <host>: reboot, wait for SSH, a new boot_id and the boot end
reboot_host() {
	local h="$1" old new waited=0
	old=$(boot_id "$h")
	log ""
	log "---- reboot $h (boot_id $old)"
	hssh "$h" "systemctl reboot" </dev/null >>"$LOG" 2>&1
	while [ "$waited" -lt "$REBOOT_TIMEOUT" ]; do
		sleep 10
		waited=$((waited + 10))
		new=$(boot_id "$h")
		if [ -n "$new" ] && [ "$new" != "$old" ]; then
			log "host is back after ${waited}s (boot_id $new)"
			# systemd 239 (EL8) has no "is-system-running --wait": poll
			# until the boot is no longer initializing or starting
			remote_at "$h" "wait for boot to finish" "for i in \$(seq 60); do
  state=\$(systemctl is-system-running)
  case \$state in initializing|starting) sleep 5 ;; *) echo \$state; exit 0 ;; esac
done
echo \$state; exit 1"
			[ "$RC" -eq 0 ]
			return
		fi
	done
	log "host did not come back within ${REBOOT_TIMEOUT}s"
	return 1
}

# stage_solve <host> <lab>: copy solve.sh and solve-lib.sh to a temporary
# directory on a server target, set TSTAGE
stage_solve() {
	local h="$1" lab="$2"
	remote_at "$h" "create staging directory" "mktemp -d /tmp/test-lab.XXXXXX"
	[ "$RC" -eq 0 ] || return 1
	TSTAGE="$OUT"
	TSTAGE_HOST="$h"
	log "---- upload solve.sh and solve-lib.sh to $h:$TSTAGE"
	(cd "$ROOT_DIR" && COPYFILE_DISABLE=1 tar --no-xattrs -cf - "labs/$lab/solve.sh" scripts/solve-lib.sh) \
		| hssh "$h" "tar --warning=no-unknown-keyword -xf - -C '$TSTAGE' && cp '$TSTAGE/scripts/solve-lib.sh' '$TSTAGE/labs/$lab/'" >>"$LOG" 2>&1
}

test_lab() {
	local lab="$1" title first leftover kind value target lab_host task_user solve_dir header
	title=$(sed -n 's/^title: //p' "$ROOT_DIR/labs/$lab/description.txt")
	target=$(lab_target "$lab")
	lab_host="$HOST"
	task_user="$LAB_USER"
	solve_dir="$STAGE/labs/$lab"
	if [ "$target" != workstation ]; then
		lab_host=$(target_ip "$target")
		task_user="$TARGET_USER"
		log "target $target ($lab_host), task user $task_user"
	fi

	if ! install_lab "$lab"; then
		criterion_result "Lab files are installed on the host" 1
		return
	fi
	criterion_result "Lab files are installed on the host" 0

	ACTIVE_LAB="$lab"
	as_student "start" "sudo labctl start $lab"
	expect_rc "labctl start exits 0" 0
	local started="$RC"
	first=$(printf '%s\n' "$OUT" | head -n 1)
	if [ "$first" = "$lab: $title" ] && printf '%s\n' "$OUT" | grep -qx 'GRADING'; then
		criterion_result "labctl start prints the header and the task" 0
	else
		criterion_result "labctl start prints the header and the task" 1
	fi
	# The header ends at the ==== line; a server target has the connect
	# line as its last line, a workstation lab has none
	header=$(printf '%s\n' "$OUT" | sed -n '1,/^====/p' | sed '$d')
	if [ "$target" = workstation ]; then
		if printf '%s\n' "$header" | grep -q '^Work on '; then
			criterion_result "Header has no connect line (workstation lab)" 1
		else
			criterion_result "Header has no connect line (workstation lab)" 0
		fi
	else
		if printf '%s\n' "$header" | tail -n 1 | grep -qE "^Work on $target: ssh ([^ ]+ )*$task_user@($target|$lab_host)\$"; then
			criterion_result "Header ends with the connect line for $target" 0
		else
			criterion_result "Header ends with the connect line for $target" 1
		fi
		remote_at "$lab_host" "marker on $target" "cat /opt/linux-labs/.current_lab && test -f /etc/profile.d/labctl.sh && test -d /var/lib/linux-labs/labs/$lab"
		if [ "$started" -ne 0 ] || { [ "$RC" -eq 0 ] && [ "$OUT" = "$lab" ]; }; then
			criterion_result "$target has the lab copy, prompt script and marker" 0
		else
			criterion_result "$target has the lab copy, prompt script and marker" 1
		fi
	fi

	if [ "$started" -eq 0 ]; then
		as_student "task" "labctl task $lab"
		expect_rc "labctl task exits 0" 0

		as_student "grade before solving" "labctl grade $lab"
		expect_rc "Grade before solving exits 1" 1
		if printf '%s\n' "$OUT" | grep -qE '^Overall result \.+ FAIL$'; then
			criterion_result "Grade output ends with Overall result FAIL" 0
		else
			criterion_result "Grade output ends with Overall result FAIL" 1
		fi

		if [ "$target" != workstation ]; then
			if stage_solve "$lab_host" "$lab"; then
				solve_dir="$TSTAGE/labs/$lab"
			else
				solve_dir=""
				log "!! cannot stage solve.sh on $target"
			fi
		fi
		if [ -n "$solve_dir" ]; then
			remote_at "$lab_host" "solve.sh" "SOLVE_USER='$task_user' LAB_USER='$task_user' bash '$solve_dir/solve.sh'"
		else
			RC=1
		fi
		expect_rc "solve.sh exits 0" 0

		if directives "$lab" | grep -q '^reboot'; then
			if reboot_host "$lab_host"; then
				criterion_result "Host reboots and comes back with a new boot_id" 0
			else
				criterion_result "Host reboots and comes back with a new boot_id" 1
			fi
		fi

		as_student "grade as student" "labctl grade $lab"
		expect_rc "Grade as student after solving exits 0" 0
		if printf '%s\n' "$OUT" | grep -qE '^Overall result \.+ PASS$' \
			&& printf '%s\n' "$OUT" | tail -n 1 | grep -qE '^([0-9]+) of \1 criteria met\.$'; then
			criterion_result "Grade output ends with Overall result PASS" 0
		else
			criterion_result "Grade output ends with Overall result PASS" 1
		fi

		remote "grade as root" "labctl grade $lab"
		expect_rc "Grade as root after solving exits 0" 0
	fi

	as_student "reset" "sudo labctl reset $lab"
	expect_rc "labctl reset exits 0" 0

	as_student "grade after reset" "labctl grade $lab"
	expect_rc "Grade after reset exits 1" 1

	leftover=""
	while read -r kind value; do
		case "$kind" in
			path)
				remote_at "$lab_host" "leftover path $value" "test ! -e '$value' && test ! -L '$value'"
				[ "$RC" -eq 0 ] || leftover="$leftover $value"
				;;
			package)
				remote_at "$lab_host" "leftover package $value" "! rpm -q '$value'"
				[ "$RC" -eq 0 ] || leftover="$leftover $value"
				;;
		esac
	done < <(directives "$lab")
	if [ -z "$leftover" ]; then
		criterion_result "Paths and packages declared in solve.sh are gone" 0
	else
		criterion_result "Paths and packages declared in solve.sh are gone" 1
		log "!! leftovers:$leftover"
	fi

	remote_at "$lab_host" "state file" "test ! -e /opt/linux-labs/state/$lab"
	expect_rc "State file /opt/linux-labs/state/$lab is gone" 0

	if [ "$target" != workstation ]; then
		remote_at "$lab_host" "lab copy and marker on $target" "test ! -e /var/lib/linux-labs && test ! -e /opt/linux-labs/.current_lab"
		expect_rc "$target has no lab copy and no marker after reset" 0
		if [ -n "$TSTAGE" ]; then
			hssh "$TSTAGE_HOST" "rm -rf '$TSTAGE'" </dev/null >/dev/null 2>&1
			TSTAGE=""
		fi
	fi

	remote "active lab" "test ! -e /opt/linux-labs/.current_lab"
	expect_rc "No lab is active after reset" 0
	[ "$RC" -eq 0 ] && ACTIVE_LAB=""
}

RESULTS=()
failed=0
skipped=0
passed=0
for lab in "${LABS[@]}"; do
	printf 'Testing %s on %s\n\n' "$lab" "$HOST"
	log ""
	log "======== $lab"
	if [ ! -f "$ROOT_DIR/labs/$lab/task.txt" ] || [ ! -f "$ROOT_DIR/labs/$lab/solve.sh" ]; then
		echo "Skipped: $lab is a legacy lab (no task.txt or solve.sh)."
		echo "Convert it to the 2.0 contract before testing it."
		echo ""
		log "skipped: legacy lab"
		RESULTS+=("$lab|SKIP")
		skipped=$((skipped + 1))
		continue
	fi
	grade_reset
	test_lab "$lab"
	if grade_summary; then
		RESULTS+=("$lab|PASS")
		passed=$((passed + 1))
	else
		RESULTS+=("$lab|FAIL")
		failed=$((failed + 1))
	fi
	echo ""
	if [ -n "$ACTIVE_LAB" ]; then
		echo "Error: lab $ACTIVE_LAB is still active on $HOST, stopping." >&2
		log "ABORT: $ACTIVE_LAB still active"
		break
	fi
done

echo "Summary for $HOST"
echo ""
for r in "${RESULTS[@]}"; do
	grade_line "${r%%|*}" "${r#*|}"
done
echo ""
tested=$((passed + failed))
if [ "$failed" -gt 0 ] || [ "${#RESULTS[@]}" -lt "${#LABS[@]}" ]; then
	grade_line "Overall result" FAIL
elif [ "$tested" -eq 0 ]; then
	grade_line "Overall result" SKIP
else
	grade_line "Overall result" PASS
fi
echo "$passed of $tested tested labs pass, $skipped skipped."
echo "Log: ${LOG#"$ROOT_DIR"/}"

if [ "$failed" -gt 0 ] || [ "${#RESULTS[@]}" -lt "${#LABS[@]}" ]; then
	exit 1
fi
if [ "$skipped" -gt 0 ]; then
	exit 2
fi
exit 0
