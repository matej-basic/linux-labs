#!/bin/bash
# storage-08 grader
source /opt/linux-labs/lib/grading.sh

IMG=/srv/storage-08.img
MNT=/srv/projects
TEAM=$MNT/team
STATE_FILE=/opt/linux-labs/state/storage-08

grade_begin storage-08
grade_require_state storage-08 "$STATE_FILE"

# $MNT is a mount point whose source is a loop device backed by $IMG
mounted_from_image() {
	local src
	[ -e "$IMG" ] || return 1
	src=$(findmnt -rn -M "$MNT" -o SOURCE 2>/dev/null | tail -n 1)
	[ -n "$src" ] || return 1
	losetup -j "$IMG" -O NAME -n 2>/dev/null | grep -qx "$src"
}

mounted_as_xfs() {
	mounted_from_image || return 1
	[ "$(findmnt -rn -M "$MNT" -o FSTYPE 2>/dev/null | tail -n 1)" = xfs ]
}

# Accounting and enforcement are ON for the quota type <User|Group>.
# The output of the state command is read section by section, so the
# lines that differ between xfsprogs 5.0 (EL8) and 6.x (EL9) do not
# matter.
quota_on() {
	mounted_as_xfs || return 1
	xfs_quota -x -c state "$MNT" 2>/dev/null | awk -v type="$1" '
		/quota state on/ { sec = ($1 == type); next }
		sec && $1 == "Accounting:" && $2 == "ON" { acct = 1 }
		sec && $1 == "Enforcement:" && $2 == "ON" { enf = 1 }
		END { exit !(acct && enf) }'
}

# The limits of a user or group, in KiB for blocks and as a count for
# inodes: limit <-u|-g> <name> <-b|-i> <soft> <hard>. The report is
# numeric (-n, #<id>) and without header (-N); its fields are id, used,
# soft, hard. An empty <soft> is not compared.
limit() {
	local kind=$1 name=$2 what=$3 soft=$4 hard=$5 id
	mounted_as_xfs || return 1
	if [ "$kind" = -u ]; then
		id=$(id -u "$name" 2>/dev/null)
	else
		id=$(getent group "$name" 2>/dev/null | cut -d: -f3)
	fi
	[ -n "$id" ] || return 1
	xfs_quota -x -c "report -N -n $kind $what" "$MNT" 2>/dev/null |
		awk -v id="#$id" -v soft="$soft" -v hard="$hard" '
			$1 == id {
				found = 1
				if (soft != "" && $3 != soft) bad = 1
				if ($4 != hard) bad = 1
			}
			END { exit !(found && !bad) }'
}

# qbob writes 60 MiB into a scratch directory; the write must fail with
# the quota error and stop at 50 MiB
qbob_stopped() {
	local dir=$MNT/.storage-08-grade size rc
	quota_on User || return 1
	id qbob >/dev/null 2>&1 || return 1
	rm -rf "$dir"
	mkdir "$dir" || return 1
	if ! chown qbob: "$dir"; then
		rm -rf "$dir"
		return 1
	fi
	runuser -u qbob -- dd if=/dev/zero of="$dir/fill" bs=1M count=60 \
		conv=fsync >/dev/null 2>"$dir.err"
	rc=$?
	size=$(stat -c %s "$dir/fill" 2>/dev/null || echo 0)
	grep -qi 'quota' "$dir.err" || rc=0
	rm -rf "$dir" "$dir.err"
	[ "$rc" -ne 0 ] && [ "$size" -le $((50 * 1048576)) ]
}

# Active fstab line: image path, $MNT, xfs
fstab_line() {
	awk -v img="$IMG" -v mnt="$MNT" '
		/^[[:space:]]*#/ { next }
		$1 == img && $2 == mnt && $3 == "xfs" { print $4 }' /etc/fstab
}

fstab_entry() {
	[ -n "$(fstab_line)" ]
}

# Every given option group is present in that line; each group is a
# list of alternatives separated by |
fstab_opts() {
	local line
	line=$(fstab_line)
	[ -n "$line" ] || return 1
	printf '%s\n' "$line" | awk -v want="$*" '
		{
			n = split($0, o, ",")
			for (i = 1; i <= n; i++) have[o[i]] = 1
		}
		END {
			k = split(want, w, " ")
			for (i = 1; i <= k; i++) {
				m = split(w[i], alt, "|")
				ok = 0
				for (j = 1; j <= m; j++) if (alt[j] in have) ok = 1
				if (!ok) exit 1
			}
			exit 0
		}'
}

team_dir() {
	mounted_from_image || return 1
	[ -d "$TEAM" ] &&
		[ "$(stat -c %G "$TEAM" 2>/dev/null)" = qteam ] &&
		[ "$(stat -c %a "$TEAM" 2>/dev/null)" = 2770 ]
}

criterion "$MNT is a loop mount of $IMG" mounted_from_image
criterion "$MNT shows an XFS file system" mounted_as_xfs
criterion "User quota accounting and enforcement are on" quota_on User
criterion "Group quota accounting and enforcement are on" quota_on Group
criterion "fstab mounts $IMG on $MNT as xfs" fstab_entry
criterion "That fstab entry has the options loop and nofail" fstab_opts loop nofail
criterion "That fstab entry enables user and group quotas" \
	fstab_opts "usrquota|uquota|quota" "grpquota|gquota"
criterion "qalice has the block limits soft 80 MiB, hard 100 MiB" \
	limit -u qalice -b 81920 102400
criterion "qalice has the inode hard limit 1000" limit -u qalice -i "" 1000
criterion "qbob has the block hard limit 50 MiB" limit -u qbob -b "" 51200
criterion "qteam has the block hard limit 200 MiB" limit -g qteam -b "" 204800
criterion "Writes by qbob stop at 50 MiB" qbob_stopped
criterion "$TEAM belongs to group qteam with mode 2770" team_dir
criterion "/etc/fstab verifies without errors" findmnt --verify
grade_end
