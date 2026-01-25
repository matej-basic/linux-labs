# Packages 02 Solution

Add EPEL repository and install htop:

```bash
# Enable EPEL repository
sudo dnf install -y epel-release

# Verify EPEL is enabled
dnf repolist | grep epel

# Search for htop in available repositories
dnf search htop

# Install htop from EPEL
sudo dnf install -y htop

# Verify installation
rpm -q htop
which htop
htop --version
```

Grade:
```bash
sudo labctl grade packages-02
```
