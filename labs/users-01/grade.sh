#!/bin/bash
# users-01 grader
source /opt/linux-labs/lib/grading.sh

# Field N of the passwd entry of user $1
pw_field() { getent passwd "$1" | cut -d: -f"$2"; }

# Exact (non-prefix) test of group membership
in_group() { id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; }

primary_is_project() { [ "$(id -gn "$1" 2>/dev/null)" = project ]; }
shell_is() { [ "$(pw_field "$1" 7)" = "$2" ]; }
home_is() { [ "$(pw_field "$1" 6)" = "$2" ]; }
owned_by() { [ "$(stat -c %U:%G "$1" 2>/dev/null)" = "$2" ]; }
mode_is() { [ "$(stat -c %a "$1" 2>/dev/null)" = "$2" ]; }
is_system_uid() { local u; u=$(pw_field "$1" 3); [ -n "$u" ] && [ "$u" -lt 1000 ]; }
is_dir() { [ -d "$1" ] && [ ! -L "$1" ]; }

grade_begin users-01

criterion "Group project exists" getent group project

criterion "User alice exists" getent passwd alice
criterion "alice has primary group project" primary_is_project alice
criterion "alice is a member of the group wheel" in_group alice wheel
criterion "alice has the login shell /bin/bash" shell_is alice /bin/bash
criterion "alice has the home directory /home/alice" home_is alice /home/alice
criterion "/home/alice is owned by alice:project" owned_by /home/alice alice:project

criterion "User svcapp exists" getent passwd svcapp
criterion "svcapp is a system account (UID below 1000)" is_system_uid svcapp
criterion "svcapp has primary group project" primary_is_project svcapp
criterion "svcapp has the login shell /usr/sbin/nologin" shell_is svcapp /usr/sbin/nologin
criterion "svcapp has the home directory /srv/svcapp" home_is svcapp /srv/svcapp
criterion "/srv/svcapp is owned by svcapp:project" owned_by /srv/svcapp svcapp:project
criterion "/srv/svcapp has permissions 750" mode_is /srv/svcapp 750

criterion "Directory /srv/project exists" is_dir /srv/project
criterion "/srv/project is owned by root:project" owned_by /srv/project root:project
criterion "/srv/project has permissions 2775" mode_is /srv/project 2775
grade_end
