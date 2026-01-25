#!/bin/bash
# Package Management Lab 01: Basics (Beginner)

# Ensure git is not installed for the exercise
rpm -q git &>/dev/null && dnf remove -y git &>/dev/null

cat <<'EOF'
====================================================
LAB: Packages 01 - Package Management Basics
====================================================

OBJECTIVE
Learn basic DNF package management commands.

REQUIREMENTS
1) Search for the git package.
2) Install the git package.
3) Verify git is installed with: rpm -q git

Run grading when done:
  sudo labctl grade packages-01
====================================================
EOF

