# packages-08: Switch Node.js to another dnf module stream

## Hints

1. A module stream decides which versions of its packages dnf may
   install. Only one stream of a module can be enabled at a time. As
   long as a stream is chosen, enabling another one fails.
2. The module command of dnf has subcommands to forget the chosen
   stream, to enable a stream and to install a profile. Read man dnf,
   section Module Command.
3. Enabling a new stream does not change the packages that are
   already installed. The distro-sync command of dnf brings installed
   packages to the versions of the enabled streams, upgrade or
   downgrade.
4. The tag MODULARITYLABEL in a query format of rpm shows the module,
   stream, version and context an installed package came from.

## Solution

1. [user] Look at the starting point:

   ```bash
   dnf module list nodejs
   node --version
   rpm -qa --qf '%{NAME} %{MODULARITYLABEL}\n' | grep nodejs:
   ```

   The stream 20 is enabled ([e]) and its common profile installed
   ([i]). Every Node.js package has the label nodejs:20:...

2. [sudo] Reset the module, so that no stream is chosen, and enable
   the stream 22:

   ```bash
   sudo dnf -y module reset nodejs
   sudo dnf -y module enable nodejs:22
   ```

3. [sudo] Move the installed Node.js packages to the versions of the
   new stream:

   ```bash
   sudo dnf -y distro-sync 'nodejs*' npm
   ```

4. [sudo] Install the common profile of the new stream:

   ```bash
   sudo dnf -y module install nodejs:22/common
   ```

5. [user] Check the result:

   ```bash
   dnf module list nodejs
   node --version
   rpm -qa --qf '%{NAME} %{MODULARITYLABEL}\n' | grep nodejs:
   ```

## Verification

```bash
cat /etc/dnf/modules.d/nodejs.module
labctl grade packages-08
```

## Explanation

A modular repository ships several streams of Node.js side by side,
and the module state in /etc/dnf/modules.d says which stream dnf may
use. While nodejs:20 is enabled, the packages of nodejs:22 are
invisible to dnf, and enabling a second stream fails. module reset
clears the stream and the installed profiles, module enable picks the
new stream.

Neither of the two touches installed packages: after them, Node.js
20 is still installed while the module state says stream 22.
distro-sync moves every installed Node.js package to the version of
the enabled stream, also packages outside the profile. On Rocky Linux
8.10 and 9.8, module install of the new profile upgrades the old
packages as well, but distro-sync is the step that does it on
purpose. Limited to the Node.js packages, it leaves the rest of the
system alone, which a plain dnf distro-sync would not. module install
then records the common profile in the module state.

The rpm database keeps the module label of every package it got from
a stream. On Rocky Linux 9 the AppStream repository also has a
non-modular nodejs package, Node.js 16, which has no label. A system
that ends up with it shows a version of 16 and fails the grader.

The dnf of both releases also has module switch-to, which enables
the new stream and moves the installed packages to it in one command.
The solution uses the separate steps, so that each change can be
checked on its own.
