Name:           linux-labs
Version:        2.0.0
Release:        1
Summary:        Hands-on Linux system administration labs
License:        MIT
BuildArch:      noarch
Source0:        %{name}-%{version}.tar.gz
# visudo for %%check
BuildRequires:  sudo
# students run labctl start/reset through the sudoers rule
Requires:       sudo
# labs on a server target run their scripts there over SSH
Requires:       openssh-clients

%description
Hands-on Linux system administration labs in the style of the RHCSA
exam for Rocky Linux and RHEL 8 and 9. labctl prepares a lab on the
lab servers, prints the task, gives hints, grades the result and resets
the machines. 118 labs in 19 topics, from files and users to
replication, load balancing and Pacemaker clustering, including
break-fix labs that start from a broken system.

%prep
%setup -q

%build
# nothing to build

%install
mkdir -p %{buildroot}/usr/bin
# labctl is a shell script, so setuid would be ignored; sudo handles root access
install -m 0755 usr/bin/labctl %{buildroot}/usr/bin/labctl
# labctl --version reports the package version
sed -i 's/^LABCTL_VERSION="@VERSION@"$/LABCTL_VERSION="%{version}"/' %{buildroot}/usr/bin/labctl
grep -q '^LABCTL_VERSION="%{version}"$' %{buildroot}/usr/bin/labctl

# Install prompt hook to show active lab
mkdir -p %{buildroot}/etc/profile.d
install -m 0644 etc/profile.d/labctl.sh %{buildroot}/etc/profile.d/labctl.sh

# Install configuration template
mkdir -p %{buildroot}/etc/linux-labs
install -m 0644 etc/linux-labs/config.template %{buildroot}/etc/linux-labs/config.template

# Install configuration helper library
mkdir -p %{buildroot}/opt/linux-labs/lib
install -m 0755 opt/linux-labs/lib/load-config.sh %{buildroot}/opt/linux-labs/lib/load-config.sh
install -m 0755 opt/linux-labs/lib/colors.sh %{buildroot}/opt/linux-labs/lib/colors.sh
install -m 0755 opt/linux-labs/lib/grading.sh %{buildroot}/opt/linux-labs/lib/grading.sh
install -m 0755 opt/linux-labs/lib/target-run.sh %{buildroot}/opt/linux-labs/lib/target-run.sh
# Package snapshot and restore for setup.sh and cleanup.sh (only sourced)
install -m 0644 opt/linux-labs/lib/packages.sh %{buildroot}/opt/linux-labs/lib/packages.sh

# labctl's SSH known_hosts for labs on a server target (servera...)
mkdir -p %{buildroot}/var/lib/linux-labs

mkdir -p %{buildroot}/opt/linux-labs
cp -pr opt/linux-labs/* %{buildroot}/opt/linux-labs/

# Each lab ships setup.sh, grade.sh, cleanup.sh, description.txt, task.txt
# and solution.md. solve.sh is the automatic solver used by
# scripts/test-lab.sh and is never shipped (build-rpm-linux.sh already
# leaves it out of the tarball; this is a second guard).
# known-issues.md (optional, notes for teachers and authors) is likewise
# never shipped.
find %{buildroot}/opt/linux-labs/labs -type f -name solve.sh -delete
find %{buildroot}/opt/linux-labs/labs -type f -name known-issues.md -delete

# Ensure all shell scripts in the labs tree are executable
find %{buildroot}/opt/linux-labs -type f -name '*.sh' -exec chmod 0755 {} +
# lib/packages.sh is a library that lab scripts source, never run
chmod 0644 %{buildroot}/opt/linux-labs/lib/packages.sh

# Install sudoers rule to allow student to run labctl without password
mkdir -p %{buildroot}/etc/sudoers.d
install -m 0440 etc/sudoers.d/labctl %{buildroot}/etc/sudoers.d/labctl

# Install man page
mkdir -p %{buildroot}%{_mandir}/man1
install -m 0644 usr/share/man/man1/labctl.1 %{buildroot}%{_mandir}/man1/labctl.1

# Student documentation (docs/student/*.md in the repo)
mkdir -p %{buildroot}%{_docdir}/%{name}
install -m 0644 doc/*.md %{buildroot}%{_docdir}/%{name}/

%check
visudo -cf %{buildroot}/etc/sudoers.d/labctl

%files
%attr(0755,root,root) /usr/bin/labctl
/etc/profile.d/labctl.sh
%dir /etc/linux-labs
/etc/linux-labs/config.template
/opt/linux-labs
%dir %attr(0755,root,root) /var/lib/linux-labs
%config(noreplace) %attr(0440,root,root) /etc/sudoers.d/labctl
%{_mandir}/man1/labctl.1*
%doc %{_docdir}/%{name}

%changelog
* Sat Oct 03 2026 Matej Basic <matej.basic@outlook.com> - 2.0.0-1
- Lab framework 2.0 with task text, hints and a shared grading library
- Labs run on servera over SSH; the student needs no sudo on the workstation
- Reset restores the package set and system accounts of the first start
- labctl check, labctl hint and labctl --version
- Runtime-tested on Rocky Linux 8.10 and 9.8

* Thu Oct 01 2026 Matej Basic <matej.basic@outlook.com> - 1.1.0-1
- First release built in CI, published to GitHub Releases and Pages
- Install labctl as 0755 instead of setuid 4755
- Mark the sudoers rule as config(noreplace) and validate it with visudo in check
- Remove duplicate files entries

* Fri Jan 23 2026 Matej Basic <matej.basic@outlook.com> - 1.0-1
- Initial minimal lab RPM
