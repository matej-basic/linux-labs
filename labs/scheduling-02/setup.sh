#!/bin/bash
# scheduling-02 setup: remove any earlier lab-task units, script and log so
# the student starts from nothing. Prints nothing on success.
set -eu

systemctl stop lab-task.timer lab-task.service &>/dev/null || true
systemctl disable lab-task.timer &>/dev/null || true
rm -f /etc/systemd/system/lab-task.timer /etc/systemd/system/lab-task.service
rm -rf /etc/systemd/system/lab-task.timer.d /etc/systemd/system/lab-task.service.d
rm -f /etc/systemd/system/timers.target.wants/lab-task.timer
rm -f /usr/local/bin/lab-task.sh /var/log/lab-task.log
systemctl daemon-reload
systemctl reset-failed lab-task.service lab-task.timer &>/dev/null || true
