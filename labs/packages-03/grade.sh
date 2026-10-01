#!/bin/bash
# packages-03 grader
source /opt/linux-labs/lib/grading.sh

OUT=/tmp/curl-files.txt

# The file is a regular file (not a symlink)
is_regular_file() {
	[ -f "$OUT" ] && [ ! -L "$OUT" ]
}

# The file holds exactly the paths owned by curl, one per line
list_matches_package() {
	local expected actual
	is_regular_file || return 1
	expected=$(rpm -ql curl 2>/dev/null | sort) || return 1
	[ -n "$expected" ] || return 1
	actual=$(sort "$OUT")
	[ "$expected" = "$actual" ]
}

grade_begin packages-03
criterion "Package curl is installed" rpm -q curl
criterion "File $OUT exists" is_regular_file
criterion "File $OUT lists exactly the files of curl" list_matches_package
grade_end
