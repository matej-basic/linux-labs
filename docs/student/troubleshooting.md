# Troubleshooting

Find the message you see, then follow the steps under it.

## labctl: command not found

linux-labs is not installed on this machine. Install it, or ask your
teacher:

    curl -fsSL https://matej-basic.github.io/linux-labs/install | sudo bash

## Unknown lab: files-1

The lab name is wrong. Lab names have a two-digit number, for example
files-01. Look up the right name:

    labctl list

## Error: 'labctl start' requires root

You forgot sudo. Run:

    sudo labctl start files-01

The same goes for reset:

    sudo labctl reset files-01

## sudo asks for a password

The sudo rule that linux-labs installs works only for the user named
student. Log in as student, or ask your teacher to add a rule for your
user.

## Error: grading needs root. Use: sudo labctl grade files-01

labctl could not get root rights without a password. This happens when
your user is not student. Run the command it suggests:

    sudo labctl grade files-01

## The grade shows "Lab was started with labctl start ... FAIL"

    Grading files-01 on servera

    Lab was started with labctl start ................................. FAIL

    Overall result .................................................... FAIL
    0 of 1 criteria met.

The lab is not started, or it was reset. Start it, then do the work
again:

    sudo labctl start files-01

## Everything looks right, but a line still says FAIL

- Read the FAIL line word by word. It names exactly what is checked:
  a path, an owner, a permission, a service state.
- Check the details with ls -l, cat or systemctl status. A typo in a
  file name, a wrong owner or a service that is running but not
  enabled are common causes.
- Some labs check that a setting survives a reboot. If the task says
  so, reboot and grade again.
- Read the task again with labctl task <lab>. The answer is often in a
  sentence you skipped.

## Error: setup of lab <lab> failed (exit N). The lab was not started.

The lab could not prepare your machine. The lines above this message
say why. Common causes:

- The lab needs internet (its task shows "Needs: internet") and the
  machine cannot reach the package repositories. Check with:

      dnf repolist

- The lab needs a free network interface ("Needs: free network
  interface") and your machine has none.
- The lab runs on several machines ("Needs: 3 nodes") and they are not
  configured or not reachable.

The last two need your teacher.

## I want to start over

Reset the lab and start it again. Your work in that lab is removed:

    sudo labctl reset files-01
    sudo labctl start files-01

## Error: cannot connect to servera (...) over SSH as opsadmin.

The lab runs on servera, and labctl could not log in there. Check that
servera is running and that you can log in yourself:

    ssh opsadmin@servera

If that asks for a password or fails, tell your teacher. labctl needs
the same login without a password.

## My prompt still shows [LAB:...] after a reset

The prompt updates when the next prompt is printed. Press Enter once.
If it still shows the lab, run:

    cat /opt/linux-labs/.current_lab

If that file exists, a lab is still active. Reset that lab.

## Error: cleanup of lab <lab> failed (exit N).

The reset did not finish. The lab is no longer active, but some of its
files or settings may still be there. Run the reset again:

    sudo labctl reset files-01

If it fails again, tell your teacher and include the full output.

## Still stuck

Collect this information and send it to your teacher:

- the lab name
- the exact command you ran
- the full output, copied as text
- the output of cat /etc/os-release
