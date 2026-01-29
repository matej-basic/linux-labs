#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

# group project
if getent group project >/dev/null; then
    pass "group project exists"
else
    fail "group project missing"
    rc=1
fi

# user alice checks
if getent passwd alice >/dev/null; then
    pass "user alice exists"
    [ "$(id -gn alice 2>/dev/null)" = "project" ] && pass "alice primary group project" || { fail "alice primary group incorrect"; rc=1; }
    id -nG alice 2>/dev/null | tr ' ' '\n' | grep -qx wheel && pass "alice in wheel" || { fail "alice not in wheel"; rc=1; }
    [ "$(getent passwd alice | cut -d: -f7)" = "/bin/bash" ] && pass "alice shell /bin/bash" || { fail "alice shell wrong"; rc=1; }
    [ -d /home/alice ] && [ "$(stat -c '%U:%G' /home/alice 2>/dev/null)" = "alice:project" ] && pass "/home/alice owned alice:project" || { fail "/home/alice ownership wrong"; rc=1; }
else
    fail "user alice missing"
    rc=1
fi

# user svcapp checks
if getent passwd svcapp >/dev/null; then
    pass "user svcapp exists"
    [ "$(id -gn svcapp 2>/dev/null)" = "project" ] && pass "svcapp primary group project" || { fail "svcapp primary group incorrect"; rc=1; }
    [ "$(getent passwd svcapp | cut -d: -f7)" = "/usr/sbin/nologin" ] && pass "svcapp shell /usr/sbin/nologin" || { fail "svcapp shell wrong"; rc=1; }
    if [ -d /srv/svcapp ]; then
        [ "$(stat -c '%U:%G' /srv/svcapp 2>/dev/null)" = "svcapp:project" ] && pass "/srv/svcapp owned svcapp:project" || { fail "/srv/svcapp ownership wrong"; rc=1; }
        [ "$(stat -c '%a' /srv/svcapp 2>/dev/null)" = "750" ] && pass "/srv/svcapp mode 750" || { fail "/srv/svcapp mode not 750"; rc=1; }
    else
        fail "/srv/svcapp missing"
        rc=1
    fi
else
    fail "user svcapp missing"
    rc=1
fi

# shared directory /srv/project
if [ -d /srv/project ]; then
    [ "$(stat -c '%U:%G' /srv/project 2>/dev/null)" = "root:project" ] && pass "/srv/project owned root:project" || { fail "/srv/project ownership wrong"; rc=1; }
    [ "$(stat -c '%a' /srv/project 2>/dev/null)" = "2775" ] && pass "/srv/project mode 2775" || { fail "/srv/project mode not 2775"; rc=1; }
else
    fail "/srv/project missing"
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
