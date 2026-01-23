Name:           linux-labs
Version:        1.0
Release:        1%{?dist}
Summary:        Minimal Linux lab framework
License:        MIT
BuildArch:      noarch
Source0:        %{name}-%{version}.tar.gz

%description
Minimal lab framework for teaching basic Linux filesystem tasks.

%prep
%setup -q

%build
# nothing to build

%install
mkdir -p %{buildroot}/usr/bin
# Ensure labctl is executable (setuid root)
install -m 4755 usr/bin/labctl %{buildroot}/usr/bin/labctl

# Install prompt hook to show active lab
mkdir -p %{buildroot}/etc/profile.d
install -m 0644 etc/profile.d/labctl.sh %{buildroot}/etc/profile.d/labctl.sh

mkdir -p %{buildroot}/opt/linux-labs
cp -pr opt/linux-labs/* %{buildroot}/opt/linux-labs/

# Ensure all shell scripts in the labs tree are executable
find %{buildroot}/opt/linux-labs -type f -name '*.sh' -exec chmod 0755 {} +

# Install sudoers rule to allow student to run labctl without password
mkdir -p %{buildroot}/etc/sudoers.d
install -m 0440 etc/sudoers.d/labctl %{buildroot}/etc/sudoers.d/labctl

%files
/usr/bin/labctl
%attr(4755,root,root) /usr/bin/labctl
/etc/profile.d/labctl.sh
/opt/linux-labs
%attr(0440,root,root) /etc/sudoers.d/labctl

%changelog
* Thu Jan 23 2026 Your Name <matej.basic@outlook.com> - 1.0-1
- Initial minimal lab RPM

