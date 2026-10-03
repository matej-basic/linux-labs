# systemd-05: Kernel arguments, GRUB timeout and kernel modules

## Hints

Task 1: the kernel argument

1. One tool changes the arguments of the installed kernels and knows
   where each release keeps them. Read man grubby.
2. The command grubby can update a single kernel or all of them at
   once, and the update of all kernels also changes /etc/default/grub.
   Check the result with its info option for ALL.

Task 2: the GRUB menu

1. /etc/default/grub is only the input. The boot loader reads the file
   that grub2-mkconfig writes from it.
2. The automatic hiding of the menu is a variable in the GRUB
   environment block, not a setting in /etc/default/grub. Read man
   grub2-editenv for how to list and remove a variable.

Task 4: the modules

1. systemd loads the modules named in /etc/modules-load.d at boot,
   one name per line. Read man modules-load.d.
2. Module options and blacklists both go into files under
   /etc/modprobe.d. Read man modprobe.d for the options and blacklist
   commands.
3. The command modprobe -c prints the configuration in the order it is
   applied. When an option appears twice, the later one wins, and
   files from all directories are read sorted by file name.
4. A blacklist stops loading by alias, which is how udev loads pcspkr
   at boot. It does not stop an explicit modprobe of the module.

## Solution

1. [sudo] Add the argument to every kernel and check the result. The
   update of ALL kernels also adds it to GRUB_CMDLINE_LINUX:

   ```bash
   sudo grubby --update-kernel=ALL --args=consoleblank=0
   sudo grubby --info=ALL | grep -E '^(kernel|args)'
   grep GRUB_CMDLINE_LINUX /etc/default/grub
   ```

2. [sudo] Set the timeout and regenerate the GRUB configuration:

   ```bash
   sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub
   sudo grub2-mkconfig -o /boot/grub2/grub.cfg
   sudo grep -n 'set timeout=' /boot/grub2/grub.cfg
   ```

3. [sudo] Remove the variable that hides the menu:

   ```bash
   sudo grub2-editenv - unset menu_auto_hide
   sudo grub2-editenv list
   ```

4. [sudo] Load dummy at boot with the option numdummies=2. The file
   name of the options file must sort after systemd.conf (see the
   explanation):

   ```bash
   modprobe -c | grep '^options dummy'
   echo dummy | sudo tee /etc/modules-load.d/dummy.conf
   echo 'options dummy numdummies=2' |
     sudo tee /etc/modprobe.d/zz-dummy.conf
   modprobe -c | grep '^options dummy'
   ```

5. [sudo] Blacklist pcspkr:

   ```bash
   echo 'blacklist pcspkr' | sudo tee /etc/modprobe.d/pcspkr.conf
   ```

6. [sudo] Reboot. The SSH connection closes; connect again when the
   system is back:

   ```bash
   sudo systemctl reboot
   ```

## Verification

```bash
cat /proc/cmdline
lsmod | grep -E '^(dummy|pcspkr) '
ip -br link show type dummy
modprobe -c | grep -E '^(options dummy|blacklist pcspkr)'
sudo grub2-editenv list
labctl grade systemd-05
```

## Explanation

The kernel arguments live in different places on the two releases.
On Rocky Linux 8 the boot entries in /boot/loader/entries contain
options $kernelopts, and the value of kernelopts is in the GRUB
environment block /boot/grub2/grubenv. On Rocky Linux 9 every boot
entry has its own literal options line. grubby hides that difference:
with --update-kernel=ALL it changes kernelopts on Rocky Linux 8 and
every entry on Rocky Linux 9, and on both it adds the argument to
GRUB_CMDLINE_LINUX in /etc/default/grub.

That last part matters for grub2-mkconfig. On Rocky Linux 8 it
rebuilds kernelopts from GRUB_CMDLINE_LINUX, so an argument that is
only in the environment block is lost the next time the configuration
is generated. On Rocky Linux 9 (since 9.3) it leaves the options of
the boot entries alone unless it gets --update-bls-cmdline, so an
argument that is only in /etc/default/grub never reaches the existing
kernels. Using grubby for ALL kernels gives the same result on both,
in any order with grub2-mkconfig.

GRUB_TIMEOUT only takes effect once grub2-mkconfig has written it into
grub.cfg. On a Rocky Linux 8 UEFI system that file is
/boot/efi/EFI/rocky/grub.cfg instead. The variable menu_auto_hide in
the environment block makes grub.cfg hide the menu after a successful
boot, whatever its value, so it has to be removed, not set to 0.

systemd-modules-load reads /etc/modules-load.d at boot and loads dummy
through modprobe, which applies the options lines from the
configuration. systemd itself ships /usr/lib/modprobe.d/systemd.conf
with options dummy numdummies=0, so that loading the module does not
create an interface. modprobe reads the files of /etc/modprobe.d and
/usr/lib/modprobe.d together, sorted by file name, and passes every
options line to the module; the last value wins. A file named dummy.conf
comes before systemd.conf, so its numdummies=2 is overridden and the
module creates no interface at all. A name such as zz-dummy.conf sorts
after it. A file named systemd.conf in /etc would replace the shipped
file completely, including its bonding option, so it is not used here.
With numdummies=2 in effect the module creates dummy0 and dummy1. The
module does not export that parameter in /sys, so the interfaces are the
visible result. The blacklist line only stops loading by alias, which is
how udev loads pcspkr for the PC speaker device. An explicit modprobe
pcspkr still works; an install line would block that too, but the lab
does not need it.

The new kernel command line is only active after a reboot, which is
why the grader checks /proc/cmdline and the boot id.
