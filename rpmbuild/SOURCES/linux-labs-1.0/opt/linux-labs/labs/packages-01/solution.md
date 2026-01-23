# Packages 01 Solution

Install git package and verify:

```bash
# Search for git package
dnf search git

# Install git
sudo dnf install -y git

# Verify installation
rpm -q git
which git
git --version
```

Grade:
```bash
sudo labctl grade packages-01
```
