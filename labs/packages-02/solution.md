# packages-02: Enable the EPEL repository and install a package from it

## Solution

1. [sudo] Install the EPEL repository package. It is in the Rocky
   Linux extras repository, so no URL is needed:

   ```bash
   sudo dnf -y install epel-release
   ```

2. [user] Check that the epel repository is enabled and that it
   offers htop:

   ```bash
   dnf repolist
   dnf info htop
   ```

3. [sudo] Install htop:

   ```bash
   sudo dnf -y install htop
   ```

4. [user] Check the package and the command:

   ```bash
   rpm -q htop
   htop --version
   ```

## Verification

```bash
dnf info installed htop
labctl grade packages-02
```

## Explanation

The epel-release package ships the repository definitions
/etc/yum.repos.d/epel*.repo and the signing key, with the repository
epel enabled. Before it is installed, htop is not in any enabled
repository on Rocky Linux 8 or 9.

On Rocky Linux the package comes from the extras repository, which is
enabled by default. The same steps work on versions 8 and 9.

The grader checks the From repo line of the installed package, so an
htop obtained somewhere else (a downloaded RPM, for example) does not
count.
