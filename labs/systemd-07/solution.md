# systemd-07: Kernel crash dumps with kdump

## Hints

1. kdump has two parts: memory that the running kernel reserves at
   boot for a second kernel, and a service that loads that second
   kernel into the reserved memory. Read man kdump.conf and the file
   /usr/share/doc/kexec-tools/kexec-kdump-howto.txt.
2. The reserved memory is a kernel argument. The command grubby
   changes the arguments of one kernel or of all kernels, and its info
   option for ALL shows the result.
3. The dump path in kdump.conf is a directory on a local file system.
   The kdump service refuses to start when that directory is missing.
4. The kernel reads crashkernel only at boot, and the kdump service
   can load the crash kernel only into memory reserved at boot.

## Solution

1. [sudo] Install kexec-tools if it is missing:

   ```bash
   rpm -q kexec-tools || sudo dnf -y install kexec-tools
   ```

2. [sudo] Set crashkernel=256M on every kernel. An existing
   crashkernel argument is replaced. With ALL, grubby also changes
   GRUB_CMDLINE_LINUX in /etc/default/grub:

   ```bash
   sudo grubby --update-kernel=ALL --args=crashkernel=256M
   sudo grubby --info=ALL | grep -E '^(kernel|args)'
   ```

3. [sudo] Create the dump directory and set the path and the core
   collector in /etc/kdump.conf. The sed commands replace the active
   lines; the grep shows every active line of the file:

   ```bash
   sudo mkdir -p /var/crash/lab
   sudo sed -i 's|^path .*|path /var/crash/lab|' /etc/kdump.conf
   cc='makedumpfile -l --message-level 7 -d 17'
   sudo sed -i "s|^core_collector .*|core_collector $cc|" \
     /etc/kdump.conf
   grep -Ev '^[[:space:]]*(#|$)' /etc/kdump.conf
   ```

   If a line is missing, add it with an editor.

4. [sudo] Enable kdump. It starts at the next boot:

   ```bash
   sudo systemctl enable kdump
   ```

5. [sudo] Reboot. The SSH connection closes; connect again when the
   system is back:

   ```bash
   sudo systemctl reboot
   ```

## Verification

```bash
cat /proc/cmdline
cat /sys/kernel/kexec_crash_loaded /sys/kernel/kexec_crash_size
systemctl status kdump
sudo kdumpctl status
labctl grade systemd-07
```

## Explanation

When the kernel crashes, kdump boots a second kernel, the crash
kernel, with kexec. That kernel runs in a memory area that the first
kernel reserved at boot and never used, so it can read the memory of
the crashed kernel and save it as a file. The argument crashkernel=256M
reserves that area; a running kernel cannot reserve it later, which is
why the reboot is needed. The kdump service then builds an initramfs
for the crash kernel from /etc/kdump.conf and loads it into the
reserved memory. /sys/kernel/kexec_crash_loaded is 1 once that worked,
and kexec_crash_size shows the size of the reserved area.

The arguments of the kernels are kept in different places on the two
releases: the kernelopts variable of the GRUB environment block on
Rocky Linux 8 and the options line of every boot entry on Rocky Linux
9. grubby with ALL handles both. On Rocky Linux 9, installing
kexec-tools runs kdumpctl, which sets the recommended crashkernel
value on every kernel; on Rocky Linux 8 the default was
crashkernel=auto. Both are replaced by the explicit value here. 256 MiB
is enough for the crash kernel of both releases on a VM with 2 GiB of
memory.

The path in kdump.conf is a directory on the root file system, and the
service does not create it. Each dump goes into its own subdirectory
named after the client address and the time. The core collector
makedumpfile with -l compresses the pages with lzo, and the dump level
17 leaves out zero pages and free pages (1 plus 16), so the dump is
smaller than the memory but keeps cache and user pages. The package
default is 31, which also drops those. --message-level 7 prints
progress, warnings and errors on the console of the crash kernel.

Do not test kdump with a real crash on a shared system: it stops every
service on the machine until the dump is written and the system boots
again.
