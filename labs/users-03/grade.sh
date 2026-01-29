#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

# Check groups
if getent group devops >/dev/null && [ "$(getent group devops | cut -d: -f3)" = "2000" ]; then
    pass "group devops GID 2000"
else
    fail "group devops missing or wrong GID"
    rc=1
fi

if getent group analytics >/dev/null && [ "$(getent group analytics | cut -d: -f3)" = "2001" ]; then
    pass "group analytics GID 2001"
else
    fail "group analytics missing or wrong GID"
    rc=1
fi

# Check user bob
if getent passwd bob >/dev/null; then
    [ "$(getent passwd bob | cut -d: -f3)" = "1010" ] && pass "bob UID 1010" || { fail "bob UID wrong"; rc=1; }
    [ "$(id -gn bob 2>/dev/null)" = "devops" ] && pass "bob primary group devops" || { fail "bob primary group wrong"; rc=1; }
    
    groups_bob=$(id -nG bob 2>/dev/null | tr ' ' '\n' | sort)
    echo "$groups_bob" | grep -qx wheel && pass "bob in wheel" || { fail "bob not in wheel"; rc=1; }
    echo "$groups_bob" | grep -qx analytics && pass "bob in analytics" || { fail "bob not in analytics"; rc=1; }
    
    [ "$(getent passwd bob | cut -d: -f7)" = "/bin/bash" ] && pass "bob shell /bin/bash" || { fail "bob shell wrong"; rc=1; }
    [ -d /home/bob ] && [ "$(stat -c '%a' /home/bob 2>/dev/null)" = "750" ] && [ "$(stat -c '%U:%G' /home/bob 2>/dev/null)" = "bob:devops" ] && pass "/home/bob correct" || { fail "/home/bob incorrect"; rc=1; }
else
    fail "user bob missing"
    rc=1
fi

# Check user charlie
if getent passwd charlie >/dev/null; then
    [ "$(getent passwd charlie | cut -d: -f3)" = "1011" ] && pass "charlie UID 1011" || { fail "charlie UID wrong"; rc=1; }
    [ "$(id -gn charlie 2>/dev/null)" = "analytics" ] && pass "charlie primary group analytics" || { fail "charlie primary group wrong"; rc=1; }
    
    groups_charlie=$(id -nG charlie 2>/dev/null | tr ' ' '\n' | sort)
    echo "$groups_charlie" | grep -qx wheel && pass "charlie in wheel" || { fail "charlie not in wheel"; rc=1; }
    
    [ "$(getent passwd charlie | cut -d: -f7)" = "/bin/bash" ] && pass "charlie shell /bin/bash" || { fail "charlie shell wrong"; rc=1; }
    [ -d /home/charlie ] && [ "$(stat -c '%a' /home/charlie 2>/dev/null)" = "750" ] && [ "$(stat -c '%U:%G' /home/charlie 2>/dev/null)" = "charlie:analytics" ] && pass "/home/charlie correct" || { fail "/home/charlie incorrect"; rc=1; }
    
    # Check expiration (should be set to far future date like 2099-12-31 or later)
    exp_days=$(chage -l charlie 2>/dev/null | grep "Account expires" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}|never" || echo "")
    if [[ "$exp_days" =~ 209[0-9]|210[0-9] ]] || [ "$exp_days" = "never" ]; then
        pass "charlie account expiration set"
    else
        fail "charlie account expiration not set correctly (expected far future, got: $exp_days)"
        rc=1
    fi
else
    fail "user charlie missing"
    rc=1
fi

# Check /srv/shared
if [ -d /srv/shared ]; then
    [ "$(stat -c '%U:%G' /srv/shared 2>/dev/null)" = "root:devops" ] && pass "/srv/shared owned root:devops" || { fail "/srv/shared ownership wrong"; rc=1; }
    [ "$(stat -c '%a' /srv/shared 2>/dev/null)" = "750" ] && pass "/srv/shared mode 750" || { fail "/srv/shared mode wrong"; rc=1; }
    
    # Check default ACL
    if getfacl /srv/shared 2>/dev/null | grep -q "default:group:devops"; then
        pass "/srv/shared has default devops ACL"
    else
        fail "/srv/shared missing default devops ACL"
        rc=1
    fi
else
    fail "/srv/shared missing"
    rc=1
fi

# Check /srv/shared/analytics
if [ -d /srv/shared/analytics ]; then
    [ "$(stat -c '%U:%G' /srv/shared/analytics 2>/dev/null)" = "root:analytics" ] && pass "/srv/shared/analytics owned root:analytics" || { fail "/srv/shared/analytics ownership wrong"; rc=1; }
    [ "$(stat -c '%a' /srv/shared/analytics 2>/dev/null)" = "750" ] && pass "/srv/shared/analytics mode 750" || { fail "/srv/shared/analytics mode wrong"; rc=1; }
    
    # Check if charlie has ACL access
    if getfacl /srv/shared/analytics 2>/dev/null | grep -q "user:charlie"; then
        pass "/srv/shared/analytics has charlie ACL"
    else
        fail "/srv/shared/analytics missing charlie ACL"
        rc=1
    fi
else
    fail "/srv/shared/analytics missing"
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
