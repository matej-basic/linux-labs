# packages-04: RPM queries and installing from a file

## Solution

1. [user] Find the file name in the EPEL directory and download it. The
   name changes whenever EPEL publishes a new build, so list the
   directory first (or open the URL in a browser):

   ```bash
   MAJOR=$(. /etc/os-release && echo "${VERSION_ID%%.*}")
   ARCH=$(uname -m)
   URL=https://dl.fedoraproject.org/pub/epel/$MAJOR/Everything/$ARCH/Packages/j/
   curl -s $URL | grep -o 'joe-[0-9][^"<]*\.rpm' | sort -uV
   curl -o joe.rpm ${URL}joe-<version>.<dist>.<arch>.rpm
   ```

2. [sudo] Install joe from the downloaded file. dnf resolves the
   dependencies from the enabled repositories:

   ```bash
   sudo dnf install ./joe.rpm
   ```

3. [user] Test the editor. Ctrl+C quits (it asks first if you changed
   something), Ctrl+K then X saves and quits:

   ```bash
   joe /tmp/test.txt
   ```

4. [user] Find where the command is installed:

   ```bash
   command -v joe
   rpm -ql joe | grep bin
   ```

5. [sudo] Remove the package and confirm the command is gone:

   ```bash
   sudo dnf remove joe
   command -v joe
   rpm -q joe
   ```

### Practice questions (not graded)

```bash
#1) Number of installed packages
rpm -qa | wc -l

#2) Which package owns /sbin/fdisk, and its information
rpm -qf /sbin/fdisk
rpm -qi $(rpm -qf /sbin/fdisk)

#3) Number of files installed by that package
rpm -ql $(rpm -qf /sbin/fdisk) | wc -l

#4) Documentation files of that package
rpm -qd $(rpm -qf /sbin/fdisk)

#5) Install date of openssh
rpm -qi openssh | grep 'Install Date'
rpm -q openssh --last
rpm -q openssh --qf '%{NAME} %{INSTALLTIME:date}\n'

#6) Capabilities required by bc
rpm -qR bc
#bc may not be installed on a minimal system; ask the repositories
dnf repoquery --requires bc

#7) Verify an installed package
rpm -V openssh-server
rpm -V setup

#8) Repositories used by dnf
dnf repolist

#9) Header information of a downloaded RPM file
rpm -qip joe.rpm
```

## Verification

```bash
rpm -q joe
labctl grade packages-04
```

## Explanation

Practice answers. `rpm -qf FILE` prints the owning package, on EL8 and
EL9 `util-linux` for /sbin/fdisk. `rpm -qi` prints name, version,
install date, size, license and description. `rpm -ql` lists every file
the package installed (hundreds for util-linux), so count with `wc -l`.
`rpm -qd` lists only files marked as documentation. `rpm -qR` prints
capabilities such as `libc.so.6(GLIBC_2.14)(64bit)` or `/bin/sh`, not
package names; add `--resolve` to `dnf repoquery --requires` to get
package names.

`rpm -V` prints nothing when every file still matches the database.
Otherwise each line starts with nine characters, one per attribute, and
a dot means unchanged: S size, M mode, 5 digest, D device numbers, L
symlink target, U owner, G group, T modification time, P capabilities.
An optional letter follows: c configuration file, d documentation, l
license, g ghost. A line `S.5....T.  c /etc/ssh/sshd_config` says a
config file changed in size, digest and time, which is normal after
editing it. A line starting with `missing` means the file is gone.

`rpm -qip` reads the header inside the .rpm. `Install Date: (not
installed)` confirms the package is not installed yet. A `NOKEY`
warning only means the EPEL signing key is not imported.

Graded part. The grader reads `dnf history` for transactions after the
lab started. dnf records a local file install with the source
`@commandline`, so installing joe from a repository does not count, and
the removal must come after that install. Run the install from the
directory where you saved the file, or give the full path, otherwise dnf
reports that the file does not exist.
