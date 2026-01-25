#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

# Check contractors group
if getent group contractors >/dev/null; then
    pass "group contractors exists"
else
    fail "group contractors missing"
    rc=1
fi

# Check user dave
if getent passwd dave >/dev/null; then
    pass "user dave exists"
    [ "$(id -gn dave 2>/dev/null)" = "contractors" ] && pass "dave primary group contractors" || { fail "dave primary group wrong"; rc=1; }
    [ "$(getent passwd dave | cut -d: -f7)" = "/bin/bash" ] && pass "dave shell /bin/bash" || { fail "dave shell wrong"; rc=1; }
    
    # Check password expiration (should be around 30 days)
    max_days=$(chage -l dave 2>/dev/null | grep "Maximum number of days" | grep -oE "[0-9]+")
    if [ -n "$max_days" ] && [ "$max_days" -gt 25 ] && [ "$max_days" -lt 35 ]; then
        pass "dave password expiration ~30 days"
    else
        fail "dave password expiration incorrect: $max_days"
        rc=1
    fi
else
    fail "user dave missing"
    rc=1
fi

# Check user eve
if getent passwd eve >/dev/null; then
    pass "user eve exists"
    [ "$(id -gn eve 2>/dev/null)" = "contractors" ] && pass "eve primary group contractors" || { fail "eve primary group wrong"; rc=1; }
    [ "$(getent passwd eve | cut -d: -f7)" = "/bin/bash" ] && pass "eve shell /bin/bash" || { fail "eve shell wrong"; rc=1; }
    
    # Check account expiration (2026-01-31)
    exp_date=$(chage -l eve 2>/dev/null | grep "Account expires" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")
    [ "$exp_date" = "2026-01-31" ] && pass "eve account expires 2026-01-31" || { fail "eve expiration wrong: $exp_date"; rc=1; }
    
    # Check password never expires
    pwd_exp=$(chage -l eve 2>/dev/null | grep "Password expires" | grep -i "never")
    if [ -n "$pwd_exp" ]; then
        pass "eve password never expires"
    else
        fail "eve password should never expire"
        rc=1
    fi
else
    fail "user eve missing"
    rc=1
fi

# Check resource limits file
if [ -f /etc/security/limits.d/70-contractors.conf ]; then
    pass "/etc/security/limits.d/70-contractors.conf exists"
    grep -q "contractors.*nofile.*1024" /etc/security/limits.d/70-contractors.conf && pass "limits: open files 1024" || { fail "limits: open files not set"; rc=1; }
    grep -q "contractors.*nproc.*512" /etc/security/limits.d/70-contractors.conf && pass "limits: max processes 512" || { fail "limits: max processes not set"; rc=1; }
else
    fail "/etc/security/limits.d/70-contractors.conf missing"
    rc=1
fi

# Check password policy in /etc/login.defs
if grep -q "PASS_MAX_DAYS" /etc/login.defs; then
    max=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
    [ "$max" = "90" ] && pass "PASS_MAX_DAYS 90" || { fail "PASS_MAX_DAYS not 90: $max"; rc=1; }
else
    fail "PASS_MAX_DAYS not set"
    rc=1
fi

if grep -q "PASS_MIN_DAYS" /etc/login.defs; then
    min=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}')
    [ "$min" = "1" ] && pass "PASS_MIN_DAYS 1" || { fail "PASS_MIN_DAYS not 1: $min"; rc=1; }
else
    fail "PASS_MIN_DAYS not set"
    rc=1
fi

if grep -q "PASS_WARN_AGE" /etc/login.defs; then
    warn=$(grep "^PASS_WARN_AGE" /etc/login.defs | awk '{print $2}')
    [ "$warn" = "14" ] && pass "PASS_WARN_AGE 14" || { fail "PASS_WARN_AGE not 14: $warn"; rc=1; }
else
    fail "PASS_WARN_AGE not set"
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
