# packages-07: A service fails after a package update

## Hints

1. Start with the service. The status of chronyd and its journal name
   the line of the configuration that chronyd rejects.
2. The command rpm in verify mode lists the files of a package that
   changed since it was installed. When an update meets a changed
   configuration file, rpm keeps that file and puts the new default
   next to it with the suffix .rpmnew.
3. Build the new chrony.conf from the .rpmnew file, add the two local
   lines and remove the .rpmnew file. The option -p of chronyd parses
   the configuration and prints it, without starting the service.
4. The history command of dnf lists the transactions, its info
   subcommand shows what one transaction installed, and its undo
   subcommand reverses it, dependencies included. The command rpm
   with -qf tells which package owns a file.

## Solution

1. [sudo] Look at the service and its journal. chronyd stops at an
   invalid directive:

   ```bash
   systemctl status chronyd
   sudo journalctl -u chronyd -n 20 --no-pager
   ```

   The journal shows "Fatal error : Invalid directive" with the line
   number of a restrict line, an access rule of ntpd.

2. [sudo] Check which files of chrony differ from the package and
   compare the old file with the new default:

   ```bash
   rpm -V chrony
   ls -l /etc/chrony.conf*
   diff /etc/chrony.conf /etc/chrony.conf.rpmnew
   ```

   The flag 5 marks /etc/chrony.conf as changed, and
   /etc/chrony.conf.rpmnew is the default of the installed package.

3. [sudo] Keep a copy of the old file outside /etc, put the new
   default in place, add the two local lines and remove the .rpmnew
   file:

   ```bash
   sudo cp -p /etc/chrony.conf /root/chrony.conf.old
   sudo cp /etc/chrony.conf.rpmnew /etc/chrony.conf
   printf '%s\n' '' '# Local settings' 'allow 172.25.250.0/24' \
       'local stratum 10' | sudo tee -a /etc/chrony.conf
   sudo rm /etc/chrony.conf.rpmnew
   sudo restorecon -v /etc/chrony.conf
   ```

4. [sudo] Check the configuration, then start chronyd and keep it
   enabled:

   ```bash
   sudo chronyd -p
   sudo systemctl enable chronyd
   sudo systemctl restart chronyd
   systemctl is-active chronyd
   chronyc sources
   ```

5. [sudo] Find the most recent transaction and see what it
   installed:

   ```bash
   sudo dnf history list
   sudo dnf history info last
   rpm -qf /usr/bin/mc
   ```

   It installed mc and, as a dependency, gpm-libs.

6. [sudo] Undo that transaction. dnf removes exactly the packages it
   installed:

   ```bash
   sudo dnf -y history undo last
   rpm -q mc gpm-libs
   ```

## Verification

```bash
rpm -V chrony
ls /etc/chrony.conf*
labctl grade packages-07
```

## Explanation

chrony marks /etc/chrony.conf as a configuration file that an update
must not overwrite. When the installed file differs from the one the
old package shipped, rpm keeps the local file and writes the new
default as .rpmnew. Nothing merges them, and an old file can contain
lines the new chronyd does not accept. Here they are restrict lines
from ntpd, which chrony never knew; chronyd stops at the first invalid
directive.

The clean fix starts from the new default and carries over only the
local settings that still matter. rpm -V then reports the file as
changed again, which is expected for a local configuration. A .rpmnew
or .rpmsave file left in /etc only causes confusion at the next
update.

dnf history records every transaction with the packages it changed
and why. Undo reverses one transaction, including the dependencies it
pulled in, and leaves everything else alone. dnf remove of mc would
also remove gpm-libs, because dnf removes dependencies that nothing
needs any more, but it would not show that both came in together.
