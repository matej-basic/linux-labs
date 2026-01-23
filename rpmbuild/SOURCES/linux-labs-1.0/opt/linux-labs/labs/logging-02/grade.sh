#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

[ -f /etc/rsyslog.d/myapp.conf ] && pass "Rsyslog config exists" || { fail "Missing /etc/rsyslog.d/myapp.conf"; rc=1; }
grep -Eq "^\s*local0\.\*\s+/var/log/myapp\.log" /etc/rsyslog.d/myapp.conf 2>/dev/null && pass "Rsyslog local0 facility filter present" || { fail "local0 facility filter not found"; rc=1; }
grep -Eq ":programname,\s*isequal,\s*\"?myapp\"?.*/var/log/myapp-program\.log" /etc/rsyslog.d/myapp.conf 2>/dev/null && pass "Rsyslog programname filter present" || { fail "programname filter not found"; rc=1; }
[ -f /var/log/myapp.log ] && pass "Log file exists" || { fail "Missing /var/log/myapp.log"; rc=1; }
[ -f /var/log/myapp-program.log ] && pass "Programname log file exists" || { fail "Missing /var/log/myapp-program.log"; rc=1; }
[ -f /etc/logrotate.d/myapp ] && pass "Logrotate config exists" || { fail "Missing /etc/logrotate.d/myapp"; rc=1; }
grep -q "daily" /etc/logrotate.d/myapp 2>/dev/null && pass "Logrotate daily" || { fail "daily not set"; rc=1; }
grep -q "rotate 7" /etc/logrotate.d/myapp 2>/dev/null && pass "Logrotate rotate 7" || { fail "rotate 7 not set"; rc=1; }
grep -q "compress" /etc/logrotate.d/myapp 2>/dev/null && pass "Logrotate compress" || { fail "compress not set"; rc=1; }
logrotate -d /etc/logrotate.d/myapp &>/dev/null && pass "Logrotate syntax ok" || { fail "Logrotate syntax invalid"; rc=1; }

exit $rc
