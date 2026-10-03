# packages-06: Configure dnf repositories from a base URL

## Hints

1. A repository file is a text file in INI format. Each section in
   square brackets defines one repository, and the name in the
   brackets is the repository ID.
2. Read man dnf.conf, section REPO OPTIONS. The options baseurl,
   enabled, gpgcheck and gpgkey are the ones this lab needs.
3. The option gpgkey takes a URL. A key file on the local disk is
   written with the file:// scheme followed by its absolute path.
4. The command dnf repolist shows the enabled repositories. After the
   install, dnf list installed shows the repository of each package
   after an @ sign.

## Solution

1. [user] Look at the repositories and the release key file:

   ```bash
   dnf repolist --all
   ls /etc/pki/rpm-gpg
   ```

   Every repository is disabled. The key file is
   RPM-GPG-KEY-rockyofficial on Rocky Linux 8 and RPM-GPG-KEY-Rocky-9
   on Rocky Linux 9.

2. [sudo] Create the repository file. dnf replaces $releasever with
   the major release (8 or 9) and $basearch with the architecture
   (x86_64), so these are the URLs from the task. This is the file
   for Rocky Linux 9:

   ```bash
   sudo tee /etc/yum.repos.d/labrepo.repo <<'EOF'
   [lab-baseos]
   name=Lab BaseOS
   baseurl=https://dl.rockylinux.org/pub/rocky/$releasever/BaseOS/$basearch/os/
   enabled=1
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9

   [lab-appstream]
   name=Lab AppStream
   baseurl=https://dl.rockylinux.org/pub/rocky/$releasever/AppStream/$basearch/os/
   enabled=1
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
   EOF
   ```

   On Rocky Linux 8 both gpgkey lines end in
   RPM-GPG-KEY-rockyofficial instead. A text editor such as vi works
   just as well as tee.

3. [user] Check that only the two lab repositories are enabled and
   that dnf can read their metadata:

   ```bash
   dnf repolist
   dnf info zsh ksh
   ```

4. [sudo] Install the packages if they are missing. dnf imports the
   release key on the first install; -y accepts it:

   ```bash
   rpm -q zsh || sudo dnf -y install zsh
   rpm -q ksh || sudo dnf -y install ksh
   ```

5. [user] Check where the packages came from:

   ```bash
   dnf list installed zsh ksh
   ```

   The last column shows @lab-baseos and @lab-appstream.

## Verification

```bash
labctl grade packages-06
```

## Explanation

dnf reads every file that ends in .repo in /etc/yum.repos.d. The ID in
brackets is how dnf commands and options name the repository, and name
is only a description. baseurl points to the directory that holds the
repodata directory of the repository. The task gives the URL, and
dnf adds repodata/repomd.xml to it.

With gpgcheck=1, dnf refuses a package whose signature it cannot check
against a key from gpgkey. The release key is already on the system,
but rpm does not trust it until it is imported, which dnf does on the
first install from the repository. A wrong or missing key file makes
the install fail, even though the repository itself works.

zsh is in BaseOS and ksh in AppStream on both releases, so each
package can only come from one of the two lab repositories. dnf
records that repository at install time, and dnf list installed and
dnf repoquery --installed show it.

The URL /pub/rocky/9/ follows the newest Rocky Linux 9 minor release.
On an older 9.x system a dependency may come in a newer version than
the rest of the system. labctl reset removes zsh and ksh but does not
downgrade anything.
