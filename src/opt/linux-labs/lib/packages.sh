#!/bin/bash
# Package snapshot and restore for lab setup.sh and cleanup.sh (lab
# framework 2.0, see "Packages" in docs/author/framework.md).
#
# The rule: labctl reset removes every package that was not installed
# when the lab first started (dependencies, repo keys and anything the
# student added included), and puts back every package of that moment
# that is missing (current repository version). Packages that were there
# stay; reset never downgrades. An upgrade pulled in during the lab stays
# (known limit). Reset also removes the system users and groups (UID or
# GID 1 to 999) that appeared since the first start, such as apache,
# mysql or named from a package's install scriptlet, but only those that
# own no file on the local filesystems.
#
#   source /opt/linux-labs/lib/packages.sh
#
#   setup.sh:    pkg_snapshot <lab>    first, before setup changes packages
#   cleanup.sh:  pkg_restore <lab>     after the lab's own cleanup
#
# pkg_snapshot records the package set once: a second start of the same
# lab keeps the first snapshot. pkg_restore restores it and deletes it;
# when it fails it keeps the snapshot, so the next reset tries again.
#
# A snapshot is the directory /opt/linux-labs/state/<lab>.packages (mode
# 0700) on the machine the script runs on (the workstation, or the server
# target, where labctl runs setup.sh and cleanup.sh):
#
#   packages       the package set: <name>.<arch> for every package and
#                  gpg-pubkey-<version> for every imported repo key
#   userinstalled  <name>.<arch> of the packages dnf marks as installed
#                  by the user (missing when dnf could not tell)
#   keys/          the armored repo keys, to import a removed key again
#   modules.d/     copy of /etc/dnf/modules.d (module stream state)
#   yum.repos.d/   copy of /etc/yum.repos.d (repository files)
#   accounts       user:<name> and group:<name> of every user and group
#                  (missing in a snapshot taken before accounts were
#                  recorded; restore then leaves accounts alone)
#
# Packages are compared by name and architecture, so an upgrade is not a
# new package and a kernel or other install-only package with a second
# version is not new either. Each repo key is its own gpg-pubkey package,
# so keys are compared by name-version.
#
# Multi-node labs run setup.sh and cleanup.sh on the workstation and the
# nodes have no lib/. pkg_snapshot_node and pkg_restore_node run the same
# functions on a node through run_on_node from load-config.sh;
# pkg_node_script prints the self-contained script they send.
#
# A new system user or group that still owns a file is left in place:
# pkg_restore names it on stderr and fails, so the lab author notices
# that cleanup.sh must remove that data (/var/lib/mysql, /var/named)
# before it calls pkg_restore. Users and groups with an ID of 1000 or
# more and accounts that existed at the first start are never touched.
#
# pkg_was_installed <lab> <name> tells cleanup.sh whether a package was
# installed at the first start, so it can remove the data directories of
# a server the lab installed before it calls pkg_restore.
#
# All functions are quiet on success, print errors to stderr and return
# non-zero on failure. They are safe under set -eu. They need root.

PKG_STATE_DIR=/opt/linux-labs/state

# _pkg_err <message>: print an error to stderr
_pkg_err() {
	echo "packages: $*" >&2
}

# _pkg_check_lab <lab>: lab names are lowercase letters, digits and dashes
_pkg_check_lab() {
	if [ -z "${1:-}" ] || ! printf '%s\n' "$1" | grep -qxE '[a-z0-9][a-z0-9-]*'; then
		_pkg_err "invalid lab name: ${1:-}"
		return 1
	fi
	return 0
}

# _pkg_set: print the package set, sorted: <name>.<arch> for every
# package, gpg-pubkey-<version> for every repo key
_pkg_set() {
	local list
	list=$(LC_ALL=C rpm -qa --qf '%{NAME} %{ARCH} %{VERSION}\n') || {
		_pkg_err "rpm -qa failed"
		return 1
	}
	printf '%s\n' "$list" | awk '
		$1 == "gpg-pubkey" { print "gpg-pubkey-" $3; next }
		NF { print $1 "." $2 }
	' | LC_ALL=C sort -u
}

# _pkg_userinstalled: print <name>.<arch> of the packages installed by the
# user according to dnf, sorted; non-zero when dnf cannot tell
_pkg_userinstalled() {
	local out
	out=$(LC_ALL=C dnf -q --disablerepo='*' history userinstalled </dev/null 2>/dev/null) || return 1
	# Lines are name-[epoch:]version-release.arch; the header has spaces
	printf '%s\n' "$out" | awk '
		/^[^ ]+-[^- ]+-[^- ]+\.[^. ]+$/ {
			s = $0
			a = s
			sub(/.*\./, "", a)
			sub(/\.[^.]*$/, "", s)
			sub(/-[^-]*-[^-]*$/, "", s)
			print s "." a
		}
	' | LC_ALL=C sort -u
}

# _pkg_quiet <command...>: run a command with its output captured; on
# failure print the last lines of it to stderr
_pkg_quiet() {
	local out rc=0
	out=$("$@" </dev/null 2>&1) || rc=$?
	if [ "$rc" -ne 0 ]; then
		printf '%s\n' "$out" | tail -n 5 | sed 's/^/  /' >&2
	fi
	return "$rc"
}

# _pkg_restore_dir <saved copy> <live directory>
# Make the live directory match the saved copy: delete entries that are
# not in the copy and that no installed package owns (files a package
# still owns stay), and write back every saved entry that differs.
_pkg_restore_dir() {
	local saved="$1" live="$2" f name rc=0
	[ -d "$saved" ] || return 0
	if [ ! -d "$live" ]; then
		mkdir -p "$live" || return 1
	fi
	for f in "$live"/* "$live"/.[!.]*; do
		[ -e "$f" ] || [ -L "$f" ] || continue
		name="${f##*/}"
		if [ -e "$saved/$name" ] || [ -L "$saved/$name" ]; then
			continue
		fi
		rpm -qf -- "$f" >/dev/null 2>&1 && continue
		rm -rf -- "$f" || rc=1
	done
	for f in "$saved"/* "$saved"/.[!.]*; do
		[ -e "$f" ] || [ -L "$f" ] || continue
		name="${f##*/}"
		if [ -f "$f" ] && [ ! -L "$f" ] && [ -f "$live/$name" ] && [ ! -L "$live/$name" ] \
			&& cmp -s -- "$f" "$live/$name"; then
			continue
		fi
		rm -rf -- "${live:?}/$name" || rc=1
		cp -a -- "$f" "$live/$name" || rc=1
	done
	if command -v restorecon >/dev/null 2>&1; then
		restorecon -R "$live" >/dev/null 2>&1 || true
	fi
	return "$rc"
}

# _pkg_removable <name.arch>...: print the packages of the list that can
# be removed without removing any package outside the list. A package
# that something outside the list needs (an upgraded package that now
# requires a new dependency, for example) is left out, and so is
# everything it needs in turn.
_pkg_removable() {
	local -a set
	local out caps cap keep p k changed
	set=("$@")
	while [ "${#set[@]}" -gt 0 ]; do
		out=$(LC_ALL=C rpm -e --test --allmatches -- "${set[@]}" 2>&1) && break
		caps=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*\(.*\) is needed by (installed) .*$/\1/p')
		if [ -z "$caps" ]; then
			_pkg_err "cannot work out which packages to remove:"
			printf '%s\n' "$out" | tail -n 5 | sed 's/^/  /' >&2
			return 1
		fi
		keep=""
		while IFS= read -r cap; do
			cap="${cap%% *}"
			cap="${cap#(}"
			[ -n "$cap" ] || continue
			keep="$keep $(rpm -q --whatprovides --qf '%{NAME}.%{ARCH}\n' -- "$cap" 2>/dev/null | tr '\n' ' ')"
		done <<<"$caps"
		changed=0
		local -a next=()
		for p in "${set[@]}"; do
			k=0
			case " $keep " in *" $p "*) k=1 ;; esac
			if [ "$k" -eq 1 ]; then
				changed=1
			else
				next+=("$p")
			fi
		done
		if [ "$changed" -eq 0 ]; then
			_pkg_err "cannot work out which packages to remove:"
			printf '%s\n' "$out" | tail -n 5 | sed 's/^/  /' >&2
			return 1
		fi
		set=("${next[@]+"${next[@]}"}")
	done
	[ "${#set[@]}" -gt 0 ] && printf '%s\n' "${set[@]}"
	return 0
}

# _pkg_accounts: print user:<name> for every user and group:<name> for
# every group, sorted
_pkg_accounts() {
	local p g
	p=$(getent passwd) || { _pkg_err "getent passwd failed"; return 1; }
	g=$(getent group) || { _pkg_err "getent group failed"; return 1; }
	{
		printf '%s\n' "$p" | awk -F: 'NF { print "user:" $1 }'
		printf '%s\n' "$g" | awk -F: 'NF { print "group:" $1 }'
	} | LC_ALL=C sort -u
}

# _pkg_file_owners: print "u <uid>" and "g <gid>" for every owner and
# group of a file on the local filesystems (tmpfs and other memory
# filesystems left out; /proc and /sys are not local filesystems)
_pkg_file_owners() {
	local -a mnts=(/)
	local m out
	while IFS= read -r m; do
		[ -n "$m" ] && [ "$m" != / ] && mnts+=("$m")
	done < <(df -l --output=target -x tmpfs -x devtmpfs -x squashfs -x overlay \
		</dev/null 2>/dev/null | tail -n +2)
	out=$(find "${mnts[@]}" -xdev -printf 'u %U\ng %G\n' 2>/dev/null | awk '!seen[$0]++')
	if [ -z "$out" ]; then
		_pkg_err "cannot list the file owners on the local filesystems"
		return 1
	fi
	printf '%s\n' "$out"
}

# _pkg_restore_accounts <snapshot dir>
# Remove the local system users, then the system groups (ID 1 to 999)
# that are not in the snapshot and own no file. A user goes before its
# group, and a group stays while a user has it as primary group. Every
# account that cannot go is named on stderr and the status is 1.
_pkg_restore_accounts() {
	local dir="$1" name id gid owners e rc=0
	local -a users=() groups=()
	[ -s "$dir/accounts" ] || return 0
	while IFS=: read -r name _ id _; do
		case "$id" in '' | *[!0-9]*) continue ;; esac
		[ "$id" -ge 1 ] && [ "$id" -le 999 ] || continue
		grep -qxF "user:$name" "$dir/accounts" && continue
		users+=("$name:$id")
	done </etc/passwd
	while IFS=: read -r name _ id _; do
		case "$id" in '' | *[!0-9]*) continue ;; esac
		[ "$id" -ge 1 ] && [ "$id" -le 999 ] || continue
		grep -qxF "group:$name" "$dir/accounts" && continue
		groups+=("$name:$id")
	done </etc/group
	[ "${#users[@]}" -gt 0 ] || [ "${#groups[@]}" -gt 0 ] || return 0
	owners=$(_pkg_file_owners) || return 1

	for e in "${users[@]+"${users[@]}"}"; do
		name=${e%:*}
		id=${e##*:}
		if printf '%s\n' "$owners" | grep -qxF "u $id"; then
			_pkg_err "the system user $name (UID $id) is new since the snapshot and still owns files; it stays"
			rc=1
			continue
		fi
		# userdel also removes the group of the same name when it is the
		# user's primary group. When that group must stay (it existed at
		# the snapshot or owns files), move the user to another primary
		# group first.
		gid=$(getent passwd "$name" | cut -d: -f4)
		if getent group "$name" >/dev/null &&
			[ "$(getent group "$name" | cut -d: -f3)" = "$gid" ] &&
			{ grep -qxF "group:$name" "$dir/accounts" ||
				printf '%s\n' "$owners" | grep -qxF "g $gid"; }; then
			if pgrep -u "$id" >/dev/null 2>&1; then
				_pkg_err "the system user $name (UID $id) is new since the snapshot and still runs processes; it stays"
				rc=1
				continue
			fi
			_pkg_quiet usermod -g 65534 "$name" || {
				_pkg_err "cannot remove the system user $name (UID $id)"
				rc=1
				continue
			}
		fi
		_pkg_quiet userdel "$name" || {
			_pkg_err "cannot remove the system user $name (UID $id)"
			rc=1
		}
	done

	for e in "${groups[@]+"${groups[@]}"}"; do
		name=${e%:*}
		id=${e##*:}
		# userdel may have removed it together with its user
		getent group "$name" >/dev/null || continue
		if awk -F: -v g="$id" '$4 == g { f = 1 } END { exit !f }' /etc/passwd; then
			_pkg_err "the system group $name (GID $id) is new since the snapshot and still the primary group of a user; it stays"
			rc=1
			continue
		fi
		if printf '%s\n' "$owners" | grep -qxF "g $id"; then
			_pkg_err "the system group $name (GID $id) is new since the snapshot and still owns files; it stays"
			rc=1
			continue
		fi
		_pkg_quiet groupdel "$name" || {
			_pkg_err "cannot remove the system group $name (GID $id)"
			rc=1
		}
	done
	return "$rc"
}

# pkg_was_installed <lab> <name>
# True when a package called <name> (any architecture) was installed at
# the first start of the lab. Also true when there is no snapshot, so a
# caller that removes data only for a package the lab installed removes
# nothing when it cannot tell.
pkg_was_installed() {
	local lab="${1:-}" name="${2:-}" dir
	_pkg_check_lab "$lab" || return 1
	dir="$PKG_STATE_DIR/$lab.packages"
	[ -s "$dir/packages" ] || return 0
	awk -v n="$name" '{ sub(/\.[^.]*$/, "") } $0 == n { f = 1 } END { exit !f }' "$dir/packages"
}

# pkg_snapshot <lab>
# Record the package set, the repo keys, the module stream state, the
# repository files and the users and groups, unless a snapshot of this lab already exists (a
# restarted lab keeps the snapshot of its first start).
pkg_snapshot() {
	local lab="${1:-}" dir tmp nvr set users
	_pkg_check_lab "$lab" || return 1
	dir="$PKG_STATE_DIR/$lab.packages"
	[ -d "$dir" ] && return 0
	tmp="$dir.tmp"
	mkdir -p "$PKG_STATE_DIR" || return 1
	rm -rf -- "$tmp" || return 1
	mkdir -m 0700 "$tmp" "$tmp/keys" || return 1

	set=$(_pkg_set) || { rm -rf -- "$tmp"; return 1; }
	if [ -z "$set" ]; then
		_pkg_err "the package list is empty"
		rm -rf -- "$tmp"
		return 1
	fi
	printf '%s\n' "$set" >"$tmp/packages" || { rm -rf -- "$tmp"; return 1; }
	if users=$(_pkg_userinstalled) && [ -n "$users" ]; then
		printf '%s\n' "$users" >"$tmp/userinstalled" || { rm -rf -- "$tmp"; return 1; }
	fi
	for nvr in $(rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' 2>/dev/null | grep '^gpg-pubkey-'); do
		rpm -q --qf '%{DESCRIPTION}\n' "$nvr" >"$tmp/keys/$nvr.asc" 2>/dev/null || {
			_pkg_err "cannot save the repo key $nvr"
			rm -rf -- "$tmp"
			return 1
		}
	done
	if [ -d /etc/dnf/modules.d ]; then
		cp -a /etc/dnf/modules.d "$tmp/modules.d" || { rm -rf -- "$tmp"; return 1; }
	fi
	if [ -d /etc/yum.repos.d ]; then
		cp -a /etc/yum.repos.d "$tmp/yum.repos.d" || { rm -rf -- "$tmp"; return 1; }
	fi
	if ! _pkg_accounts >"$tmp/accounts" || [ ! -s "$tmp/accounts" ]; then
		_pkg_err "cannot record the users and groups"
		rm -rf -- "$tmp"
		return 1
	fi
	# Only a complete snapshot counts as taken
	mv -- "$tmp" "$dir" || { rm -rf -- "$tmp"; return 1; }
	return 0
}

# pkg_restore <lab>
# Restore the snapshot of the lab and delete it. Without a snapshot (the
# lab was never started) it does nothing.
pkg_restore() {
	local lab="${1:-}" dir now added missing p f rc=0
	local -a new=() gone=() keys=() remove=() mark_user=() mark_dep=()
	_pkg_check_lab "$lab" || return 1
	dir="$PKG_STATE_DIR/$lab.packages"
	rm -rf -- "$dir.tmp"
	[ -d "$dir" ] || return 0
	if [ ! -s "$dir/packages" ]; then
		_pkg_err "the snapshot $dir has no package list"
		return 1
	fi

	# 1. Remove the packages that are not in the snapshot. Their
	# dependencies that are not in the snapshot are in the list too, so dnf
	# removes exactly the list and needs no repository.
	now=$(_pkg_set) || return 1
	added=$(printf '%s\n' "$now" | LC_ALL=C comm -13 "$dir/packages" -)
	for p in $added; do
		case "$p" in gpg-pubkey-*) ;; *) new+=("$p") ;; esac
	done
	if [ "${#new[@]}" -gt 0 ]; then
		if ! f=$(_pkg_removable "${new[@]}"); then
			rc=1
		elif [ -n "$f" ]; then
			while IFS= read -r p; do remove+=("$p"); done <<<"$f"
			if ! _pkg_quiet dnf -y --disablerepo='*' \
				--setopt=clean_requirements_on_remove=False remove "${remove[@]}"; then
				_pkg_err "cannot remove: ${remove[*]}"
				rc=1
			fi
		fi
	fi

	# 2. Module stream state and repository files as they were, so that
	# missing packages come back from the same streams and repositories
	_pkg_restore_dir "$dir/modules.d" /etc/dnf/modules.d || rc=1
	_pkg_restore_dir "$dir/yum.repos.d" /etc/yum.repos.d || rc=1

	# 3. Install the packages of the snapshot that are missing, in the
	# current repository version. A package from a repository that is
	# disabled by default (the High Availability repo, for example) needs
	# the second attempt with every repository enabled.
	now=$(_pkg_set) || return 1
	missing=$(printf '%s\n' "$now" | LC_ALL=C comm -23 "$dir/packages" -)
	for p in $missing; do
		case "$p" in gpg-pubkey-*) ;; *) gone+=("$p") ;; esac
	done
	if [ "${#gone[@]}" -gt 0 ]; then
		if ! dnf -y install "${gone[@]}" </dev/null >/dev/null 2>&1 \
			&& ! _pkg_quiet dnf -y --enablerepo='*' --setopt='*.skip_if_unavailable=True' \
				install "${gone[@]}"; then
			_pkg_err "cannot install again: ${gone[*]}"
			rc=1
		fi
	fi

	# 4. Repo keys: remove the ones imported since the snapshot (also by
	# the installs above), import the removed ones again
	now=$(_pkg_set) || return 1
	added=$(printf '%s\n' "$now" | LC_ALL=C comm -13 "$dir/packages" -)
	for p in $added; do
		case "$p" in
			gpg-pubkey-*)
				rpm -e --allmatches "$p" >/dev/null 2>&1 || {
					_pkg_err "cannot remove the repo key $p"
					rc=1
				}
				;;
		esac
	done
	missing=$(printf '%s\n' "$now" | LC_ALL=C comm -23 "$dir/packages" -)
	for p in $missing; do
		case "$p" in gpg-pubkey-*) keys+=("$p") ;; esac
	done
	for p in "${keys[@]+"${keys[@]}"}"; do
		for f in "$dir/keys/$p"-*.asc; do
			[ -f "$f" ] || continue
			rpm --import "$f" >/dev/null 2>&1 || {
				_pkg_err "cannot import the repo key $p"
				rc=1
			}
		done
	done

	# 5. Repository files once more: a package installed again in step 3
	# may have written its own repo file over the recorded one
	_pkg_restore_dir "$dir/modules.d" /etc/dnf/modules.d || rc=1
	_pkg_restore_dir "$dir/yum.repos.d" /etc/yum.repos.d || rc=1

	# 6. Install reason (user or dependency) as recorded, so that a later
	# dnf autoremove sees the system as before the lab
	if [ -s "$dir/userinstalled" ] && now=$(_pkg_set) && f=$(_pkg_userinstalled) && [ -n "$f" ]; then
		while IFS= read -r p; do
			[ -n "$p" ] && mark_user+=("$p")
		done < <(printf '%s\n' "$f" | LC_ALL=C comm -13 - "$dir/userinstalled" \
			| LC_ALL=C comm -12 - <(printf '%s\n' "$now"))
		while IFS= read -r p; do
			[ -n "$p" ] && mark_dep+=("$p")
		done < <(printf '%s\n' "$f" | LC_ALL=C comm -23 - "$dir/userinstalled" \
			| LC_ALL=C comm -12 - "$dir/packages")
		if [ "${#mark_user[@]}" -gt 0 ]; then
			_pkg_quiet dnf -y --disablerepo='*' mark install "${mark_user[@]}" || rc=1
		fi
		if [ "${#mark_dep[@]}" -gt 0 ]; then
			_pkg_quiet dnf -y --disablerepo='*' mark remove "${mark_dep[@]}" || rc=1
		fi
	fi

	# 7. System users and groups the packages (or anything else) created
	# since the snapshot, once the packages are back as they were: a
	# failed package removal can leave a package that needs its user
	if [ "$rc" -eq 0 ]; then
		_pkg_restore_accounts "$dir" || rc=1
	fi

	if [ "$rc" -ne 0 ]; then
		_pkg_err "the snapshot of $lab is not fully restored; the snapshot $dir stays for the next reset"
		return 1
	fi
	rm -rf -- "$dir"
	return 0
}

# pkg_node_script <snapshot|restore> <lab>
# Print a bash script that runs pkg_snapshot or pkg_restore for <lab> on
# another machine. It carries the functions of this file, so the machine
# needs no lib/. Run it there as root with bash -s. After a successful
# restore it also removes /opt/linux-labs/state and /opt/linux-labs when
# they are empty, since nothing else cleans them up on a node.
pkg_node_script() {
	local mode="${1:-}" lab="${2:-}"
	_pkg_check_lab "$lab" || return 1
	case "$mode" in
		snapshot|restore) ;;
		*) _pkg_err "pkg_node_script: unknown mode: $mode"; return 1 ;;
	esac
	echo '{'
	declare -p PKG_STATE_DIR
	declare -f _pkg_err _pkg_check_lab _pkg_set _pkg_userinstalled _pkg_quiet \
		_pkg_restore_dir _pkg_removable _pkg_accounts _pkg_file_owners \
		_pkg_restore_accounts pkg_snapshot pkg_restore
	if [ "$mode" = snapshot ]; then
		printf 'pkg_snapshot %q || exit 1\n' "$lab"
	else
		printf 'pkg_restore %q || exit 1\n' "$lab"
		# shellcheck disable=SC2016 # expanded on the node
		echo 'rmdir "$PKG_STATE_DIR" /opt/linux-labs 2>/dev/null'
	fi
	echo 'exit 0'
	echo '} </dev/null'
}

# pkg_snapshot_node <ip> <lab>, pkg_restore_node <ip> <lab>
# pkg_snapshot and pkg_restore on a node, as root through
# "run_on_node <ip> sudo -n bash -s" (source load-config.sh first). The
# node's errors come through on stderr; the status is the node's.
pkg_snapshot_node() {
	_pkg_node "${1:-}" snapshot "${2:-}"
}

pkg_restore_node() {
	_pkg_node "${1:-}" restore "${2:-}"
}

_pkg_node() {
	local ip="${1:-}" mode="$2" lab="${3:-}" script
	if ! declare -F run_on_node >/dev/null; then
		_pkg_err "pkg_${mode}_node needs run_on_node: source /opt/linux-labs/lib/load-config.sh first"
		return 1
	fi
	script=$(pkg_node_script "$mode" "$lab") || return 1
	printf '%s\n' "$script" | run_on_node "$ip" "sudo -n bash -s"
}
