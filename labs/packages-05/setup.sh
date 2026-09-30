#!/bin/bash
# Package Management Lab 05: Build and Install from Source (Advanced)

# The joe RPM would collide with the source install, so make sure it is gone.
# A previous source install is left alone: the student may be redoing the lab.
rpm -q joe &>/dev/null && dnf -y remove joe &>/dev/null

cat <<'TXT'
====================================================
LAB: Packages 05 - Build and Install from Source
====================================================

OBJECTIVE
Install the joe text editor, version 4.6, from its source
code instead of from a package. A C compiler and the usual
build tools are needed to do this, and they are not
guaranteed to be installed on this system.

The source tarball is joe-4.6.tar.gz, available from:
  https://sourceforge.net/projects/joe-editor/files/JOE%20sources/joe-4.6/joe-4.6.tar.gz/download
(use curl -L, the link redirects to a mirror)

REQUIREMENTS
1) Download the tarball and unpack it with tar into a
   separate directory of your own.
2) Read the output of ./configure --help. Find out which
   installation prefix is used by default.
3) Configure the build so that joe is installed under /usr
   and its configuration files under /etc.
4) Compile and install joe.
5) Verify where joe was installed and that it runs.

QUESTIONS (not graded)
- What do the x, v and f options mean in: tar xvf ?
- What is the default installation prefix?

Run grading when done:
  sudo labctl grade packages-05
====================================================
TXT
