#!/bin/bash
# Package Management Lab 04: Query the RPM database, install from a downloaded RPM file (Intermediate)

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/packages-04"

# The joe editor must not be installed at the start
rpm -q joe &>/dev/null && dnf -y remove joe &>/dev/null

# Remember the newest dnf history transaction, so the grader only looks at what happens after this point
start_id=$(LANG=C dnf history list 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {print $1}' | sort -n | tail -1)
mkdir -p "$STATE_DIR"
echo "${start_id:-0}" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"

# Major version and architecture for the download URL (VERSION_ID is e.g. 9.4)
major=$(. /etc/os-release && echo "${VERSION_ID%%.*}")
arch=$(uname -m)

cat <<EOF
====================================================
LAB: Packages 04 - RPM Queries and Installing from a File
====================================================

OBJECTIVE
Query the RPM database, then install, locate and remove
a package from an RPM file downloaded by hand.

PART 1: PRACTICE QUESTIONS (not graded)
Answer these on the command line. Nothing here is
checked, but the commands are the same ones you need
for package work on the exam. See: man rpm, man dnf

1) How many packages are installed on this system?
2) Which package installed the file /sbin/fdisk? Show
   the information about that package.
3) How many files did that package install?
4) Which documentation files does that package ship?
5) When was the openssh package installed?
6) Which capabilities does the bc package require?
7) Verify an installed package of your choice (for
   example openssh-server or setup). Explain what each
   flag in the verification output means.
8) Which repositories does dnf use on this system?
9) Show the header information stored inside a
   downloaded RPM file, before it is installed (you
   will have the joe RPM file in Part 2).

PART 2: INSTALL FROM A DOWNLOADED FILE (graded)
The joe text editor is not in the base repositories, it
is published in EPEL. The package is not installed now.

1) Download the joe RPM for this system from
   https://dl.fedoraproject.org/pub/epel/${major}/Everything/${arch}/Packages/j/
   Find the right file name in that directory yourself.
2) Install joe with dnf, from the file you downloaded
   (not from a configured repository).
3) Start joe to test it. To leave it, press Ctrl+C, or
   press Ctrl+K and then X. If you typed anything, Ctrl+C
   asks for confirmation and Ctrl+K X saves the file.
4) Find where the joe command is installed.
5) Remove the joe package with dnf and confirm that the
   joe command is gone.

Run grading when done:
  sudo labctl grade packages-04
====================================================
EOF
