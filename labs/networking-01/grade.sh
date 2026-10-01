#!/bin/bash
# networking-01 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/networking-01
CON=labnet-static
ADDR=192.168.1.100/24

grade_begin networking-01
grade_require_state networking-01 "$STATE_FILE"
iface=$(sed -n 1p "$STATE_FILE")
orig=$(sed -n 2p "$STATE_FILE")

# Print the values of a profile setting, one per line
con_values() {
	nmcli -g "$1" connection show "$CON" 2>/dev/null | tr ' |,;' '\n' | grep -v '^$'
}
con_value_is() { [ "$(nmcli -g "$1" connection show "$CON" 2>/dev/null)" = "$2" ]; }
has_value() { con_values "$1" | grep -Fxq "$2"; }
has_address() { ip -4 -o addr show dev "$iface" | awk '{ print $4 }' | grep -Fxq "$ADDR"; }
no_gateway() { [ -z "$(nmcli -g ipv4.gateway connection show "$CON" 2>/dev/null)" ]; }
no_default_on_iface() { [ -z "$(ip -o route show default dev "$iface" 2>/dev/null)" ]; }
orig_default() { ip -o route show default dev "$orig" | grep -q .; }

criterion "Connection $CON exists" nmcli connection show "$CON"
criterion "Connection $CON is bound to interface $iface" con_value_is connection.interface-name "$iface"
criterion "Connection $CON uses the manual IPv4 method" con_value_is ipv4.method manual
criterion "Connection $CON has address $ADDR" has_value ipv4.addresses "$ADDR"
criterion "Connection $CON has DNS server 8.8.8.8" has_value ipv4.dns 8.8.8.8
criterion "Connection $CON defines no gateway" no_gateway
criterion "Connection $CON never installs a default route" con_value_is ipv4.never-default yes
criterion "Connection $CON is active" con_value_is GENERAL.STATE activated
criterion "Interface $iface has address $ADDR" has_address
criterion "No default route uses interface $iface" no_default_on_iface
criterion "Default route still uses interface $orig" orig_default
grade_end
