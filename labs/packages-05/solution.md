# Packages 05 Solution

Build joe 4.6 from source and install it under /usr, with configuration files in /etc.

Install the compiler and build tools (gcc and make are enough for joe 4.6;
`sudo dnf groupinstall "Development Tools"` also works but installs much more):

```bash
sudo dnf -y install gcc make
```

Download the tarball (the SourceForge link redirects to a mirror, so curl needs -L):

```bash
curl -L -o joe-4.6.tar.gz "https://sourceforge.net/projects/joe-editor/files/JOE%20sources/joe-4.6/joe-4.6.tar.gz/download"
```

Unpack it in a separate directory:

```bash
mkdir ~/src
tar xvf joe-4.6.tar.gz -C ~/src
cd ~/src/joe-4.6
```

In `tar xvf`: x extracts, v lists each file as it is processed (verbose),
f says the next argument is the archive file. tar detects the gzip
compression by itself.

Read the configure options. The default prefix is /usr/local
(the help says `--prefix=PREFIX  install architecture-independent files in PREFIX [/usr/local]`):

```bash
./configure --help | less
```

Configure, compile, install (installing needs root, compiling does not):

```bash
./configure --prefix=/usr --sysconfdir=/etc
make
sudo make install
```

Without `--sysconfdir=/etc` the configuration files would go to
/usr/local/etc/joe (sysconfdir defaults to PREFIX/etc), and without
`--prefix=/usr` the binary would land in /usr/local/bin.

Verify:

```bash
which joe
ls -l /usr/bin/joe
ls /etc/joe
rpm -qf /usr/bin/joe      # "not owned by any package": it was not installed from an RPM
joe /tmp/test.txt         # Ctrl+C exits an unmodified file, Ctrl+K X saves and exits
```

Grade:
```bash
sudo labctl grade packages-05
```
