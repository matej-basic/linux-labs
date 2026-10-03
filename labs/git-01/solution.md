# git-01: Shared Git repository served over SSH

## Hints

1. An account whose login shell is git-shell runs only the Git
   transport commands. The command useradd sets the login shell, and
   /etc/shells lists the shells that the system accepts as valid.
2. A bare repository has no working tree. The command git init has
   options for a bare repository and for the name of the first
   branch. Create the repository as root and give it to git afterwards.
3. sshd reads the keys of git from /home/git/.ssh/authorized_keys and
   ignores them when the directory or the file is open to others. The
   public key is on node 2, and the workstation reaches both nodes.
4. Set the identity with git config inside ~/project, without the
   option for the global file. If the first commit lands on master,
   rename the branch to main, then push with the option that sets the
   upstream branch.

## Solution

The steps use the default addresses 172.25.250.10 for node 1 and
172.25.250.11 for node 2. Use the addresses from the TOPOLOGY section
of the task.

### Node 1

1. [user] From the workstation, log in to node 1 as opsadmin:

   ```bash
   ssh opsadmin@172.25.250.10
   ```

2. [sudo] Install git where it is missing and add git-shell to
   /etc/shells:

   ```bash
   rpm -q git || sudo dnf -y install git
   grep -qx /usr/bin/git-shell /etc/shells ||
     echo /usr/bin/git-shell | sudo tee -a /etc/shells
   ```

3. [sudo] Create the user git with git-shell as its login shell:

   ```bash
   sudo useradd -m -d /home/git -s /usr/bin/git-shell git
   ```

4. [sudo] Create the bare repository with the initial branch main
   and give it to git:

   ```bash
   sudo mkdir -p /srv/git
   sudo git init --bare -b main /srv/git/project.git
   sudo chown -R git:git /srv/git
   ```

5. [sudo] Create an empty authorized_keys file for git with the
   right owner and modes, then log out:

   ```bash
   sudo install -d -m 0700 -o git -g git /home/git/.ssh
   sudo install -m 0600 -o git -g git /dev/null \
     /home/git/.ssh/authorized_keys
   sudo restorecon -R /home/git/.ssh
   exit
   ```

6. [sudo] On the workstation, read the public key of opsadmin on
   node 2 and append it to the file of git on node 1:

   ```bash
   ssh opsadmin@172.25.250.11 cat .ssh/id_ed25519.pub |
     ssh opsadmin@172.25.250.10 \
       sudo tee -a /home/git/.ssh/authorized_keys
   ```

### Node 2

7. [user] Log in to node 2 as opsadmin:

   ```bash
   ssh opsadmin@172.25.250.11
   ```

8. [sudo] Install git where it is missing:

   ```bash
   rpm -q git || sudo dnf -y install git
   ```

9. [user] Check that git gets no shell: confirm the host key of node
   1 with yes on this first connection, and git-shell closes it. Then
   clone the repository, which is still empty:

   ```bash
   ssh git@172.25.250.10
   git clone git@172.25.250.10:/srv/git/project.git ~/project
   ```

10. [user] Set the identity in the repository configuration:

    ```bash
    cd ~/project
    git config user.name "Lab Admin"
    git config user.email admin@lab.example
    ```

11. [user] Commit README.md, name the branch main and push it:

    ```bash
    echo "Shared project repository" > README.md
    git add README.md
    git commit -m "Add README"
    git branch -M main
    git push -u origin main
    ```

## Verification

```bash
git -C ~/project status -sb
git -C ~/project log --format='%h %an <%ae> %s'
git ls-remote git@172.25.250.10:/srv/git/project.git
labctl grade git-01
```

Run labctl grade on the workstation.

## Explanation

git-shell accepts only the commands that Git runs on the server side
of a clone, fetch or push (`git-upload-pack`, `git-receive-pack` and
`git-upload-archive`). Without a directory `~/git-shell-commands` it
refuses an interactive login with "Interactive git shell is not
enabled", so the account git can serve repositories but gives nobody
a shell. Listing it in /etc/shells makes it a valid login shell for
tools such as chsh.

A bare repository holds only the Git data, no checked-out files, which
is what a server needs: a push into a non-bare repository would change
the branch under someone's working tree. Git 2.43 on Rocky 8.10 and Git
2.52 on Rocky 9.8 both still start a new repository on master
unless init.defaultBranch is set, so `-b main` names the first branch
of the bare repository, and `git branch -M main` renames the first
local branch of the clone, whatever its name was. `git push -u` sets
origin/main as the upstream of main.

sshd refuses an authorized_keys file when the directory .ssh or the
file can be written by others, so the modes 0700 and 0600 and the
owner git matter. restorecon gives both the SELinux type ssh_home_t.
`git config` without `--global` writes `.git/config` of the current
repository, which is where the grader looks for the identity.
