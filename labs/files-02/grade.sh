#!/bin/bash
# files-02 grader
source /opt/linux-labs/lib/grading.sh

ROOT=/tmp/webfiles

grade_begin files-02
grade_require_state files-02

# attrs_are <path> <owner:group> <mode>: type-agnostic ownership and mode
attrs_are() {
	[ -e "$1" ] && [ ! -L "$1" ] &&
		[ "$(stat -c '%U:%G %a' "$1" 2>/dev/null)" = "$2 $3" ]
}

dir_attrs() {
	[ -d "$1" ] && attrs_are "$1" "$2" "$3"
}

file_attrs() {
	[ -f "$1" ] && attrs_are "$1" "$2" "$3"
}

criterion "$ROOT is root:root with mode 755" dir_attrs "$ROOT" root:root 755
criterion "$ROOT/app is apache:apache with mode 755" dir_attrs "$ROOT/app" apache:apache 755
criterion "$ROOT/config is root:root with mode 700" dir_attrs "$ROOT/config" root:root 700
criterion "$ROOT/data is apache:apache with mode 755" dir_attrs "$ROOT/data" apache:apache 755
criterion "app/index.php is apache:apache with mode 644" file_attrs "$ROOT/app/index.php" apache:apache 644
criterion "app/upload.php is apache:apache with mode 644" file_attrs "$ROOT/app/upload.php" apache:apache 644
criterion "config/db.conf is root:root with mode 600" file_attrs "$ROOT/config/db.conf" root:root 600
criterion "data/app.log is apache:apache with mode 640" file_attrs "$ROOT/data/app.log" apache:apache 640
criterion "data/error.log is root:root with mode 644" file_attrs "$ROOT/data/error.log" root:root 644
grade_end
