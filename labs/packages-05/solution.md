# packages-05: Build joe from source with a custom prefix

## Hints

1. A source build has three stages: configure, compile, install.
   Only the last one needs root. Unpack the tarball with tar first.
2. Run the configure script with --help. It lists the options that
   change where files are installed. The default prefix is
   /usr/local.
3. Two options matter here: --prefix for the program files and
   --sysconfdir for the configuration. Compile with make, then
   run make install as root.
4. The tools gcc and make may be missing. Install them with dnf.
   The SourceForge link redirects, so curl needs the -L option.

## Solution

1. [sudo] Install the compiler and build tools if they are
   missing. gcc and make are enough for joe 4.6:

   ```bash
   rpm -q gcc make || sudo dnf -y install gcc make
   ```

2. [user] Download the tarball. The SourceForge link redirects to a
   mirror, so curl needs -L:

   ```bash
   curl -L -o joe-4.6.tar.gz "https://sourceforge.net/projects/joe-editor/files/JOE%20sources/joe-4.6/joe-4.6.tar.gz/download"
   ```

3. [user] Unpack it in a separate directory:

   ```bash
   mkdir -p ~/src
   tar xvf joe-4.6.tar.gz -C ~/src
   cd ~/src/joe-4.6
   ```

4. [user] Read the configure options. The default prefix is /usr/local.
   Then configure and compile:

   ```bash
   ./configure --help | less
   ./configure --prefix=/usr --sysconfdir=/etc
   make
   ```

5. [sudo] Install:

   ```bash
   sudo make install
   ```

6. [user] Check where joe went and that it runs:

   ```bash
   command -v joe
   ls -l /usr/bin/joe
   ls /etc/joe
   rpm -qf /usr/bin/joe
   joe /tmp/test.txt
   ```

   rpm reports that the file is not owned by any package. In joe,
   Ctrl+C exits an unmodified file and Ctrl+K X saves and exits.

## Verification

```bash
labctl grade packages-05
```

## Explanation

In tar xvf, x extracts, v lists each file as it is processed and f says
the next argument is the archive. tar detects the gzip compression by
itself.

The help of configure shows `--prefix=PREFIX` with the default
/usr/local. Without `--prefix=/usr` the binary lands in /usr/local/bin,
which the grader rejects. The sysconfdir defaults to PREFIX/etc, so
without `--sysconfdir=/etc` the configuration files go to
/usr/local/etc/joe, or to /usr/etc/joe with `--prefix=/usr` alone.

Compiling needs no privileges, only make install writes outside the
home directory. A file installed by make has no RPM owner, which is what
`rpm -qf` shows. The unpacked source stays in ~/src until labctl reset
removes it.
