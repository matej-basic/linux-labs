#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

# Check developers group
if getent group developers >/dev/null && [ "$(getent group developers | cut -d: -f3)" = "3000" ]; then
    pass "group developers GID 3000"
else
    fail "group developers GID 3000 missing"
    rc=1
fi

# Check /srv/secure
if [ -d /srv/secure ]; then
    [ "$(stat -c '%U:%G %a' /srv/secure 2>/dev/null)" = "root:root 755" ] && pass "/srv/secure 755 root:root" || { fail "/srv/secure perms wrong"; rc=1; }
else
    fail "/srv/secure missing"
    rc=1
fi

# Check /srv/secure/bin and deploy.sh
if [ -d /srv/secure/bin ]; then
    pass "/srv/secure/bin exists"
    if [ -f /srv/secure/bin/deploy.sh ]; then
        perms=$(stat -c '%a' /srv/secure/bin/deploy.sh 2>/dev/null)
        [ "$perms" = "4755" ] && pass "deploy.sh has setuid 4755" || { fail "deploy.sh perms wrong: $perms"; rc=1; }
        [ -x /srv/secure/bin/deploy.sh ] && pass "deploy.sh executable" || { fail "deploy.sh not executable"; rc=1; }
    else
        fail "deploy.sh missing"
        rc=1
    fi
else
    fail "/srv/secure/bin missing"
    rc=1
fi

# Check /srv/secure/shared with setgid
if [ -d /srv/secure/shared ]; then
    perms=$(stat -c '%a' /srv/secure/shared 2>/dev/null)
    [ "$perms" = "2770" ] && pass "/srv/secure/shared setgid 2770" || { fail "/srv/secure/shared perms wrong: $perms"; rc=1; }
    [ "$(stat -c '%G' /srv/secure/shared 2>/dev/null)" = "developers" ] && pass "/srv/secure/shared group developers" || { fail "/srv/secure/shared group wrong"; rc=1; }
else
    fail "/srv/secure/shared missing"
    rc=1
fi

# Check /srv/secure/tmp with sticky bit
if [ -d /srv/secure/tmp ]; then
    perms=$(stat -c '%a' /srv/secure/tmp 2>/dev/null)
    [ "$perms" = "1777" ] && pass "/srv/secure/tmp sticky 1777" || { fail "/srv/secure/tmp perms wrong: $perms"; rc=1; }
else
    fail "/srv/secure/tmp missing"
    rc=1
fi

# Check backup archive
if [ -f /tmp/backup.tar.gz ]; then
    pass "/tmp/backup.tar.gz exists"
    # Verify archive contains /srv/secure
    if tar -tzf /tmp/backup.tar.gz 2>/dev/null | grep -q "srv/secure"; then
        pass "backup archive contains /srv/secure"
    else
        fail "backup archive doesn't contain /srv/secure"
        rc=1
    fi
else
    fail "/tmp/backup.tar.gz missing"
    rc=1
fi

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
    pass "Lab completed successfully"
    exit 0
else
    fail "Lab incomplete"
    exit 1
fi
