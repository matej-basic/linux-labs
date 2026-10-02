#!/usr/bin/env bash
# scripts/lab-vms.sh
# vCenter helper for the linux-labs test VMs: snapshot, revert, power-cycle.
#
# It only ever touches these four VMs, resolved from a fixed list below (never
# from user input or govc find patterns):
#   /Datacenter/vm/linux-labs/student01/{workstation,servera,serverb,serverc}
# No other VM (docker-host, rpm-builder, other environments) is ever touched.
#
# Usage:
#   scripts/lab-vms.sh status
#   scripts/lab-vms.sh snapshot <name> [--cold]
#   scripts/lab-vms.sh revert <name> --yes
#   scripts/lab-vms.sh power-cycle <workstation|servera|serverb|serverc> --yes
#   scripts/lab-vms.sh delete-snapshot <name> --yes
#   scripts/lab-vms.sh --help
#
# status           Power state, guest IP and snapshot names of the four VMs.
# snapshot         Same-named snapshot on all four VMs. Default is warm without
#                  memory (VMs keep running). --cold shuts the guests down,
#                  snapshots, powers them on and waits for SSH. Refuses if any
#                  VM already has that name.
# revert           Revert all four to <name>. Refuses unless all four have it.
#                  Without --yes it only prints what would happen and exits 1.
#                  Prints each VM's snapshot description first. Afterwards
#                  powers on VMs that are off and waits for SSH.
# power-cycle      Hard reset of one VM, then waits for SSH.
# delete-snapshot  Remove <name> from all four. Refuses unless all four have it
#                  and each one's description starts with "linux-labs " (made
#                  by this script); other snapshots such as "Start" are safe.
#
# <name> must match ^[A-Za-z0-9._-]{1,64}$.
# Credentials come from .config/vcenter_creds (USERNAME, PASSWORD, VCENTER),
# parsed literally and passed to govc only through the environment.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREDS_FILE="$ROOT_DIR/.config/vcenter_creds"
GOVC="${GOVC:-/opt/homebrew/bin/govc}"
VM_FOLDER="/Datacenter/vm/linux-labs/student01"
VMS=(workstation servera serverb serverc)
SSH_TIMEOUT=300
SHUTDOWN_TIMEOUT=180

die() {
        echo "error: $*" >&2
        exit 1
}

usage() {
        sed -n '3,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Fixed lookups: the only way a VM path or IP is ever produced.
vm_ip() {
        case "$1" in
                workstation) echo 10.0.0.188 ;;
                servera) echo 10.0.0.189 ;;
                serverb) echo 10.0.0.190 ;;
                serverc) echo 10.0.0.191 ;;
                *) die "internal: unknown VM '$1'" ;;
        esac
}

vm_path() {
        local vm
        for vm in "${VMS[@]}"; do
                if [ "$vm" = "$1" ]; then
                        echo "$VM_FOLDER/$vm"
                        return 0
                fi
        done
        die "VM '$1' is not one of: ${VMS[*]}"
}

check_name() {
        [ "$1" != "." ] && [ "$1" != ".." ] || die "invalid snapshot name '$1'"
        [[ "$1" =~ ^[A-Za-z0-9._-]{1,64}$ ]] \
                || die "invalid snapshot name '$1' (allowed: A-Z a-z 0-9 . _ -, 1 to 64 chars)"
}

check_vm_arg() {
        local vm
        for vm in "${VMS[@]}"; do
                [ "$vm" = "$1" ] && return 0
        done
        die "VM '$1' is not one of: ${VMS[*]}"
}

load_creds() {
        local k v
        [ -x "$GOVC" ] || die "govc not found at $GOVC (brew install govc)"
        [ -f "$CREDS_FILE" ] || die "credentials file not found: $CREDS_FILE (needs USERNAME, PASSWORD, VCENTER lines)"
        GOVC_USERNAME="" GOVC_PASSWORD="" GOVC_URL=""
        while IFS='=' read -r k v || [ -n "$k" ]; do
                v="${v%$'\r'}"; v="${v#\"}"; v="${v%\"}"
                case $k in
                        USERNAME) GOVC_USERNAME="$v";;
                        PASSWORD) GOVC_PASSWORD="$v";;
                        VCENTER) GOVC_URL="$v";;
                esac
        done < "$CREDS_FILE"
        [ -n "$GOVC_USERNAME" ] || die "USERNAME missing in $CREDS_FILE"
        [ -n "$GOVC_PASSWORD" ] || die "PASSWORD missing in $CREDS_FILE"
        [ -n "$GOVC_URL" ] || die "VCENTER missing in $CREDS_FILE"
        export GOVC_USERNAME GOVC_PASSWORD GOVC_URL
        export GOVC_INSECURE=1
        "$GOVC" about >/dev/null 2>&1 \
                || die "vCenter login failed (govc about) for $GOVC_URL as $GOVC_USERNAME"
}

power_state() {
        "$GOVC" vm.info "$(vm_path "$1")" | sed -n 's/^ *Power state: *//p'
}

guest_ip() {
        "$GOVC" vm.info "$(vm_path "$1")" | sed -n 's/^ *IP address: *//p'
}

# Snapshot names of one VM, one per line, tree indentation stripped.
snap_names() {
        local out
        out="$("$GOVC" snapshot.tree -vm "$(vm_path "$1")")" \
                || die "cannot read snapshots of $1"
        # govc prints "." for the current state; no snapshot may be named "." (check_name).
        printf '%s\n' "$out" | sed 's/^[[:space:]]*//' | grep -vxF '.' || true
}

has_snap() {
        local names
        names="$(snap_names "$1")"
        grep -qxF -- "$2" <<<"$names"
}

# Description of snapshot $2 on VM $1 ("name - description" lines of snapshot.tree -d;
# names contain no spaces, so the first " - " separates them). Empty if unreadable.
snap_desc() {
        local out
        out="$("$GOVC" snapshot.tree -vm "$(vm_path "$1")" -d)" \
                || die "cannot read snapshots of $1"
        printf '%s\n' "$out" | sed 's/^[[:space:]]*//' \
                | awk -v n="$2" 'index($0, n " - ") == 1 { print substr($0, length(n) + 4); exit }'
}

# Refuse unless every VM has the snapshot.
require_snap_everywhere() {
        local vm missing=()
        for vm in "${VMS[@]}"; do
                has_snap "$vm" "$1" || missing+=("$vm")
        done
        [ "${#missing[@]}" -eq 0 ] \
                || die "snapshot '$1' is missing on: ${missing[*]} (refusing partial operation)"
}

# Fail closed: refuse unless the snapshot on every VM was made by this script.
require_ours() {
        local vm desc bad=()
        for vm in "${VMS[@]}"; do
                desc="$(snap_desc "$vm" "$1")"
                case "$desc" in
                        "linux-labs "*) ;;
                        *) bad+=("$vm") ;;
                esac
        done
        [ "${#bad[@]}" -eq 0 ] \
                || die "snapshot '$1' on ${bad[*]} has no 'linux-labs ' description (not made by this script, or unreadable); refusing"
}

require_snap_nowhere() {
        local vm present=()
        for vm in "${VMS[@]}"; do
                has_snap "$vm" "$1" && present+=("$vm")
        done
        [ "${#present[@]}" -eq 0 ] \
                || die "snapshot '$1' already exists on: ${present[*]}"
}

ssh_ok() {
        ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
                "root@$(vm_ip "$1")" true >/dev/null 2>&1
}

wait_ssh() {
        local vm="$1" deadline=$((SECONDS + SSH_TIMEOUT))
        echo "waiting for SSH on $vm ($(vm_ip "$vm"))"
        while [ "$SECONDS" -lt "$deadline" ]; do
                if ssh_ok "$vm"; then
                        echo "  $vm: SSH answers"
                        return 0
                fi
                sleep 5
        done
        echo "  $vm: no SSH after ${SSH_TIMEOUT}s" >&2
        return 1
}

wait_ssh_all() {
        local vm rc=0
        for vm in "${VMS[@]}"; do
                wait_ssh "$vm" || rc=1
        done
        return "$rc"
}

power_on_if_off() {
        local vm
        for vm in "${VMS[@]}"; do
                if [ "$(power_state "$vm")" != "poweredOn" ]; then
                        echo "powering on $vm"
                        "$GOVC" vm.power -on "$(vm_path "$vm")" >/dev/null
                fi
        done
}

cmd_status() {
        local vm names
        echo "vCenter: $GOVC_URL   folder: $VM_FOLDER"
        for vm in "${VMS[@]}"; do
                names="$(snap_names "$vm" | paste -sd, - | sed 's/,/, /g')"
                printf '%-12s %-12s vcenter-ip=%-15s fixed-ip=%-12s snapshots: %s\n' \
                        "$vm" "$(power_state "$vm")" "$(guest_ip "$vm")" "$(vm_ip "$vm")" \
                        "${names:-(none)}"
        done
}

cmd_snapshot() {
        local name="$1" cold="$2" vm desc state deadline waiting
        desc="linux-labs $name $(date +%Y-%m-%d)"
        require_snap_nowhere "$name"
        if [ "$cold" = 1 ]; then
                echo "cold snapshot '$name': shutting down guests"
                for vm in "${VMS[@]}"; do
                        if [ "$(power_state "$vm")" = "poweredOn" ]; then
                                "$GOVC" vm.power -s "$(vm_path "$vm")" >/dev/null \
                                        || echo "warning: guest shutdown request failed on $vm" >&2
                        fi
                done
                deadline=$((SECONDS + SHUTDOWN_TIMEOUT))
                while :; do
                        waiting=()
                        for vm in "${VMS[@]}"; do
                                state="$(power_state "$vm")"
                                [ "$state" = "poweredOff" ] || waiting+=("$vm")
                        done
                        [ "${#waiting[@]}" -eq 0 ] && break
                        if [ "$SECONDS" -ge "$deadline" ]; then
                                echo "warning: forcing power off after ${SHUTDOWN_TIMEOUT}s: ${waiting[*]}" >&2
                                for vm in "${waiting[@]}"; do
                                        "$GOVC" vm.power -off -force "$(vm_path "$vm")" >/dev/null
                                done
                        else
                                sleep 5
                        fi
                done
        fi
        for vm in "${VMS[@]}"; do
                "$GOVC" snapshot.create -vm "$(vm_path "$vm")" -d "$desc" -m=false "$name" >/dev/null \
                        || die "snapshot failed on $vm; earlier VMs may already have '$name' (see status)"
                echo "snapshot '$name' created on $vm"
        done
        if [ "$cold" = 1 ]; then
                power_on_if_off
                wait_ssh_all || die "snapshot done, but not every VM answers SSH"
        fi
        echo "done"
}

cmd_revert() {
        local name="$1" vm
        require_snap_everywhere "$name"
        for vm in "${VMS[@]}"; do
                echo "$vm: reverting to '$name' ($(snap_desc "$vm" "$name"))"
        done
        for vm in "${VMS[@]}"; do
                "$GOVC" snapshot.revert -vm "$(vm_path "$vm")" "$name" >/dev/null \
                        || die "revert failed on $vm; fleet is partly reverted, check status"
                echo "reverted $vm to '$name'"
        done
        power_on_if_off
        wait_ssh_all || die "reverted, but not every VM answers SSH (see status)"
        cmd_status
}

cmd_power_cycle() {
        local vm="$1"
        if [ "$(power_state "$vm")" = "poweredOn" ]; then
                echo "hard reset of $vm"
                "$GOVC" vm.power -reset "$(vm_path "$vm")" >/dev/null
        else
                echo "$vm is not powered on, powering on"
                "$GOVC" vm.power -on "$(vm_path "$vm")" >/dev/null
        fi
        # Give a reset guest time to drop the old connection before polling.
        sleep 5
        wait_ssh "$vm" || die "$vm does not answer SSH"
}

cmd_delete_snapshot() {
        local name="$1" vm
        require_snap_everywhere "$name"
        require_ours "$name"
        for vm in "${VMS[@]}"; do
                "$GOVC" snapshot.remove -vm "$(vm_path "$vm")" "$name" >/dev/null \
                        || die "removal failed on $vm (see status)"
                echo "removed '$name' from $vm"
        done
}

main() {
        local cmd="${1:-}" arg yes=0 cold=0 pos=()
        case "$cmd" in
                ""|-h|--help|help) usage; [ -n "$cmd" ] && exit 0; exit 2 ;;
        esac
        shift
        for arg in "$@"; do
                case "$arg" in
                        --yes) yes=1 ;;
                        --cold) cold=1 ;;
                        -h|--help) usage; exit 0 ;;
                        -*) die "unknown option '$arg'" ;;
                        *) pos+=("$arg") ;;
                esac
        done

        # Validate everything before credentials are read or vCenter is contacted.
        case "$cmd" in
                status)
                        [ "${#pos[@]}" -eq 0 ] && [ "$yes" = 0 ] && [ "$cold" = 0 ] \
                                || die "status takes no arguments"
                        ;;
                snapshot|revert|delete-snapshot|power-cycle)
                        [ "${#pos[@]}" -eq 1 ] || die "$cmd needs exactly one argument (see --help)"
                        if [ "$cmd" = power-cycle ]; then
                                check_vm_arg "${pos[0]}"
                        else
                                check_name "${pos[0]}"
                        fi
                        [ "$cold" = 0 ] || [ "$cmd" = snapshot ] || die "--cold only applies to snapshot"
                        [ "$yes" = 0 ] || [ "$cmd" != snapshot ] || die "--yes does not apply to snapshot"
                        ;;
                *) die "unknown command '$cmd' (see --help)" ;;
        esac

        if [ "$cmd" != status ] && [ "$cmd" != snapshot ] && [ "$yes" != 1 ]; then
                case "$cmd" in
                        revert) echo "would revert ${VMS[*]} to snapshot '${pos[0]}', discarding all changes since" ;;
                        delete-snapshot) echo "would delete snapshot '${pos[0]}' from ${VMS[*]}" ;;
                        power-cycle) echo "would hard-reset ${pos[0]} and wait for SSH" ;;
                esac
                echo "nothing done; add --yes to proceed" >&2
                exit 1
        fi

        load_creds
        case "$cmd" in
                status) cmd_status ;;
                snapshot) cmd_snapshot "${pos[0]}" "$cold" ;;
                revert) cmd_revert "${pos[0]}" ;;
                power-cycle) cmd_power_cycle "${pos[0]}" ;;
                delete-snapshot) cmd_delete_snapshot "${pos[0]}" ;;
        esac
}

main "$@"
