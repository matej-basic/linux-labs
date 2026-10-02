# Getting started with linux-labs

linux-labs gives you small Linux administration tasks on your own virtual
machine. You start a lab, read the task, do the work with normal Linux
commands, and let the grader check the result. Then you reset the lab
and start the next one.

Everything goes through one command: labctl.

## What you need

- A virtual machine with Rocky Linux, RHEL or AlmaLinux, version 8 or 9.
- A user account. In most classrooms it is called student.
- A terminal on that machine.

## Install

Skip this step if your teacher already installed linux-labs. To check,
run:

    labctl list

If you see a list of labs, it is installed. If you see
"command not found", install it. You need sudo rights for this:

    curl -fsSL https://matej-basic.github.io/linux-labs/install | sudo bash

The installer prints a few lines that start with "==>" and ends with:

    Installed: linux-labs-2.0.0-1.noarch

    Next steps:
      labctl list
      sudo labctl start <lab>

Log out and log in again once. After that your prompt shows the name of
the active lab.

## Your first lab

Start with files-01. It takes about five minutes.

### 1. Find a lab

    labctl list

You see one line per lab, with its name and what you will do:

    LAB               DESCRIPTION
    ----------------  ----------------------------------------------
    files-01          Create a directory and a text file with the required content.
    files-02          Build a web application directory tree with the required owners and permissions.
    ...

To see only the easy labs:

    labctl list --level beginner

### 2. Start the lab

    sudo labctl start files-01

Starting a lab needs sudo, because labctl prepares the system as root.
As the student user you need no password for it. labctl prints the task:

    files-01: Directories and files
    Category: Files    Level: Beginner
    ========================================================================

    OBJECTIVE
      Create a directory and a text file with the required content.

    TASKS
      1. Create the directory /tmp/data.
      2. Create the regular file /tmp/data/info.txt.
      3. The file /tmp/data/info.txt must contain the word hello.

    EXPECTED RESULT
      /tmp/data holds the file info.txt, and info.txt contains the word
      hello.

    NOTES
      - Use any valid Linux commands. Only the final state is graded;
        command history is not evaluated.
      - Reference: man mkdir and man bash (section Redirection).

    GRADING
      labctl grade files-01

Some labs print a Needs line under the title, for example
"Needs: internet". It tells you what the lab needs from your machine.

From the next prompt on, your prompt starts with [LAB:files-01]. That
is how you know which lab is active.

The task says what the result must be, not which commands to type.
Finding the commands is the exercise.

### 3. Do the work

Use any commands you like. Only the final state counts, not your
command history.

To read the task again at any time:

    labctl task files-01

### 4. Grade your work

    labctl grade files-01

Run it without sudo. labctl gets the rights it needs by itself.

The grader prints one line per check. Each line ends with PASS or FAIL:

    Grading files-01 on servera

    Directory /tmp/data exists ........................................ PASS
    File /tmp/data/info.txt exists .................................... PASS
    File /tmp/data/info.txt contains the word hello ................... FAIL

    Overall result .................................................... FAIL
    2 of 3 criteria met.

How to read it:

- Each line before "Overall result" is one requirement from the task.
  The text says what must be true.
- PASS means that requirement is met. FAIL means it is not met yet.
- "Overall result" is PASS only when every line is PASS.
- The last line counts the requirements you met.

Here the directory and the file exist, but the file does not contain
the word hello. Fix that, then grade again. You can grade as often as
you want; grading changes nothing on the system.

When everything is right, you see:

    Overall result .................................................... PASS
    3 of 3 criteria met.

### 5. Reset the lab

    sudo labctl reset files-01

This removes what the lab and your work created, so the machine is
clean for the next lab. The [LAB:files-01] part of the prompt
disappears.

Only one lab is active at a time. Always reset a lab before you start
the next one.

## Labs that run on a server

Most labs need root rights, so they run on a server called servera,
not on your workstation. You still run every labctl command on the
workstation. The header of such a lab has one more line:

    files-02: Web directory permissions and ownership
    Category: Files    Level: Intermediate
    Work on servera: ssh opsadmin@servera
    ========================================================================

Type that ssh command on the workstation to log in to servera. There
you work as opsadmin, who may use sudo. The prompt on servera shows
[LAB:files-02] too, so you know you are in the right place.

When you are done, type exit to come back to the workstation. Then
grade and reset from there, as usual:

    exit
    labctl grade files-02
    sudo labctl reset files-02

Some labs reboot servera. The ssh connection closes during the reboot.
Wait a minute and run the ssh command again.

## The whole cycle

    labctl list
    sudo labctl start files-01
    labctl task files-01
    labctl grade files-01
    sudo labctl reset files-01

## Stuck?

Work through these steps in order. Each one gives away a little more.

1. Ask for a hint, if the lab has one:

       labctl hint files-01

   Each call shows one more hint, from a general direction to a
   specific detail. The first call shows hint 1, the second shows
   hints 1 and 2, and so on. Take them one at a time and try again
   after each. A lab without hints tells you so.
2. Read the task again with labctl task files-01. Compare each FAIL
   line in the grade output with the task. The FAIL text names the
   thing that is not right yet.
3. Read the manual pages named under NOTES in the task, for example:

       man mkdir

   Press q to leave a man page. Press / and type a word to search in it.
4. Read the reference solution:

       labctl solution files-01

   labctl asks "This shows the full solution. Continue? [y/N]" first.
   Answer y to go on. The solution shows the commands, then explains
   why they work. Press q to leave it. Try to do the lab yourself
   first: you learn more that way.

If labctl itself shows an error, run labctl check. It tests your
connection to servera and the rest of the setup the labs need and says
what to fix. Then see troubleshooting.md.

## More

- commands.md: all labctl commands on one page.
- troubleshooting.md: what to do when labctl shows an error.
- man labctl: the full command reference.
- The list of all labs:
  https://github.com/matej-basic/linux-labs/blob/main/docs/catalog.md
