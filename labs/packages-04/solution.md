# Packages 04 Solution

## Part 1: practice questions (not graded)

```bash
# 1) Number of installed packages
rpm -qa | wc -l

# 2) Which package owns /sbin/fdisk, and its information
rpm -qf /sbin/fdisk
rpm -qi $(rpm -qf /sbin/fdisk)

# 3) Number of files installed by that package
rpm -ql $(rpm -qf /sbin/fdisk) | wc -l

# 4) Documentation files of that package
rpm -qd $(rpm -qf /sbin/fdisk)

# 5) Install date of openssh (the Install Date line, or --last, or a query format)
rpm -qi openssh | grep 'Install Date'
rpm -q openssh --last
rpm -q openssh --qf '%{NAME} %{INSTALLTIME:date}\n'

# 6) Capabilities required by bc (works for installed packages)
rpm -qR bc
# bc may not be installed on a minimal system; ask the repositories instead
dnf repoquery --requires bc

# 7) Verify an installed package
rpm -V openssh-server
rpm -V setup

# 8) Repositories used by dnf
dnf repolist

# 9) Header information of a downloaded RPM file (works before installing it)
rpm -qip joe-*.rpm
```

What the commands show:

- `rpm -qf FILE` prints the package that owns the file. On EL8 and EL9 that is `util-linux`.
- `rpm -qi` prints name, version, release, install date, size, license, packager and description.
- `rpm -ql` lists every file the package installed (hundreds for util-linux), so count with `wc -l`.
- `rpm -qd` lists only files marked as documentation, mostly under `/usr/share/doc` and `/usr/share/man`.
- `rpm -qR` prints capabilities such as `libc.so.6(GLIBC_2.14)(64bit)` or `/bin/sh`, not package names. To see which packages provide them, use `dnf repoquery --requires --resolve bc`.
- `rpm -V` prints nothing when every file still matches the database. Otherwise each line starts with nine characters, one per attribute, where a dot means "unchanged":
  `S` file size, `M` mode (permissions or type), `5` MD5 digest, `D` device numbers, `L` symlink target, `U` owner, `G` group, `T` modification time, `P` capabilities.
  After the nine characters comes an optional `c` (configuration file), `d` (documentation), `l` (license) or `g` (ghost), then the path. A line like `missing c /etc/foo.conf` means the file is gone. For example `S.5....T. c /etc/ssh/sshd_config` says a config file changed in size, digest and time, which is normal after editing it.
- `rpm -qip` on a file reads the header inside the .rpm. `Install Date: (not installed)` confirms it is not installed yet. A `NOKEY` warning only means the EPEL signing key is not imported.

## Part 2: install joe from a downloaded file (graded)

Download the file. The exact name changes whenever EPEL publishes a new build, so look at the directory first: open the URL in a browser, or list it from the shell.

```bash
MAJOR=$(. /etc/os-release && echo ${VERSION_ID%%.*})
ARCH=$(uname -m)
URL=https://dl.fedoraproject.org/pub/epel/$MAJOR/Everything/$ARCH/Packages/j/

# Find the file name (joe-<version>.<dist>.<arch>.rpm)
curl -s $URL | grep -o 'joe-[^"]*\.rpm' | sort -u

# Download it into the current directory, using the name found above
curl -O ${URL}joe-<version>.<dist>.<arch>.rpm
```

Install from the file (dnf resolves dependencies from the enabled repositories), test, locate and remove:

```bash
sudo dnf install ./joe-*.rpm

# Test the editor. Ctrl+C quits (it asks first if you changed something).
# Ctrl+K then X saves and quits.
joe /tmp/test.txt

# Where is the command installed?
which joe
rpm -ql joe | grep bin

# Remove the package and confirm the command is gone
sudo dnf remove joe
which joe
rpm -q joe
```

`which joe` now prints "no joe in (...)" and `rpm -q joe` prints "package joe is not installed". If the `dnf install` step says the file is not found, run it from the directory where the file was downloaded.

The grader reads `dnf history`. The install must be recorded from a local file (dnf lists the source as `@commandline`), so installing joe from a repository does not count, and the removal must come after that install.

Grade:
```bash
sudo labctl grade packages-04
```
