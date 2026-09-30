#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

ROOT=/srv/archive
STATE_FILE=/opt/linux-labs/state/files-04
types=(report memo chart)
months=(sep oct nov dec)

if [ ! -r "$STATE_FILE" ]; then
	fail "Lab state missing: run 'sudo labctl start files-04' first"
	exit 1
fi
owner=$(head -n 1 "$STATE_FILE")

# Expected paths
dirs=()
files=()
for t in "${types[@]}"; do
	dirs+=("$ROOT/$t")
	for m in "${months[@]}"; do
		dirs+=("$ROOT/$t/$m")
		for l in a b c; do
			for d in 1 2 3; do
				files+=("$ROOT/$t/$m/${t}_${m}_${l}${d}")
			done
		done
	done
done

# 1. Root directory
[ -d "$ROOT" ] && pass "$ROOT exists" || { fail "$ROOT missing"; rc=1; }

# 2. The 12 type/month directories
missing_dirs=0
example=""
for t in "${types[@]}"; do
	for m in "${months[@]}"; do
		if [ ! -d "$ROOT/$t/$m" ]; then
			((++missing_dirs))
			[ -z "$example" ] && example="$t/$m"
		fi
	done
done
[ "$missing_dirs" -eq 0 ] && pass "all 12 directories <type>/<month> exist" \
	|| { fail "$missing_dirs of 12 directories missing, e.g. $example"; rc=1; }

# 3. The 108 files in place
bad=0
example=""
for f in "${files[@]}"; do
	if [ ! -f "$f" ] || [ -L "$f" ]; then
		((++bad))
		[ -z "$example" ] && example="${f#"$ROOT"/}"
	fi
done
[ "$bad" -eq 0 ] && pass "all ${#files[@]} files in place" \
	|| { fail "$bad files missing or misplaced, e.g. $example"; rc=1; }

# 4. No loose files at the top levels
loose=0
example=""
for base in "$ROOT" "$ROOT"/*/; do
	[ -d "$base" ] || continue
	while IFS= read -r -d '' f; do
		((++loose))
		[ -z "$example" ] && example="${f#"$ROOT"/}"
	done < <(find "$base" -maxdepth 1 -mindepth 1 ! -type d -print0 2>/dev/null)
done
[ "$loose" -eq 0 ] && pass "no loose files in $ROOT or in the type directories" \
	|| { fail "$loose loose files left over, e.g. $example"; rc=1; }

# 5. Nothing extra anywhere in the tree
expected_list=$(printf '%s\n' "${dirs[@]}" "${files[@]}" | sort)
actual_list=$(find "$ROOT" -mindepth 1 2>/dev/null | sort)
extra=$(comm -13 <(echo "$expected_list") <(echo "$actual_list"))
if [ -z "$extra" ]; then
	pass "no extra files or directories in the tree"
else
	n=$(echo "$extra" | wc -l)
	first=${extra%%$'\n'*}
	fail "$n unexpected entries in the tree, e.g. ${first#"$ROOT"/}"
	rc=1
fi

# 6. Ownership
notowned=0
example=""
for p in "${dirs[@]}" "${files[@]}"; do
	[ -e "$p" ] || continue
	if [ "$(stat -c %U "$p" 2>/dev/null)" != "$owner" ]; then
		((++notowned))
		[ -z "$example" ] && example="${p#"$ROOT"/}"
	fi
done
[ "$notowned" -eq 0 ] && pass "all files and directories are owned by $owner" \
	|| { fail "$notowned entries not owned by $owner (created as root or with sudo?), e.g. $example"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi
