# packages-01: Package management basics

## Solution

1. [user] Search the repositories for git packages (optional):

   ```bash
   dnf search git
   ```

2. [sudo] Install the git package:

   ```bash
   sudo dnf -y install git
   ```

3. [user] Check the installation:

   ```bash
   rpm -q git
   command -v git
   git --version
   ```

## Verification

```bash
labctl grade packages-01
```

## Explanation

dnf resolves git and its dependencies from the enabled repositories
and installs them as RPM packages. rpm -q reads the local RPM
database, so it confirms the package is installed without needing the
network. The grader also runs git with a clean default PATH, which
proves the binary is in /usr/bin and not only reachable through a
personal shell setting.
