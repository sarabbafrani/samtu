#!/usr/bin/env bash
set -euo pipefail

VERSION=2.0.0

DEST=8.8.8.8
COUNT=4
OVERHEAD=0
TIMEOUT=2
IFACE=""
APPLY=0
QUIET=0
LOWER=576

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    NC=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
progress() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*" >&2; }
warn() { printf '%s%s%s\n' "$YELLOW" "$*" "$NC" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
samtu $VERSION - find the largest packet size that survives the path

Usage: ${0##*/} [options]

Options:
  -d HOST     destination, address or name (default: $DEST)
  -i IFACE    interface to read the ceiling from and to change (default: the
              interface holding the default route)
  -c N        packets per probe (default: $COUNT)
  -o N        tunnel overhead to subtract, in bytes (default: $OVERHEAD)
  -w N        timeout per probe in seconds (default: $TIMEOUT)
  -l N        lowest size to consider (default: $LOWER)
  -a          set the discovered MTU on the interface
  -q          print only the result
  -h          this message

Without -a nothing on the system is changed.

by Sobhan Arab, https://sobhanarab.com
EOF
}

default_interface() {
    ip route show default 2>/dev/null | awk '/default/ { for (i = 1; i < NF; i++) if ($i == "dev") print $(i+1); exit }'
}

interface_mtu() {
    local iface=$1
    ip link show dev "$iface" 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "mtu") { print $(i+1); exit } }'
}

is_ipv6() {
    case $1 in
        *:*) return 0 ;;
        *) return 1 ;;
    esac
}

probe() {
    local size=$1 payload output received
    payload=$((size - HEADER - OVERHEAD))
    [ "$payload" -ge 0 ] || return 1
    output=$(ping "$FAMILY" -M "do" -s "$payload" -c "$COUNT" -W "$TIMEOUT" -n -q "$DEST" 2>&1 || true)
    received=$(printf '%s' "$output" | grep -oE '[0-9]+ received' | grep -oE '^[0-9]+' || printf '0')
    [ "${received:-0}" -eq "$COUNT" ]
}

search() {
    local low=$1 high=$2 best=0 mid
    while [ "$low" -le "$high" ]; do
        mid=$(( (low + high) / 2 ))
        if probe "$mid"; then
            progress "  ${GREEN}ok${NC}      $mid"
            best=$mid
            low=$((mid + 1))
        else
            progress "  ${RED}dropped${NC} $mid"
            high=$((mid - 1))
        fi
    done
    printf '%s' "$best"
}

apply_mtu() {
    local iface=$1 mtu=$2
    local runner=""
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null 2>&1 || die "changing the MTU needs root"
        runner=sudo
    fi
    $runner ip link set dev "$iface" mtu "$mtu" || die "could not set the MTU on $iface"
    local now
    now=$(interface_mtu "$iface")
    [ "$now" = "$mtu" ] || die "the interface reports $now after the change"
    say "${GREEN}$iface is now at $mtu${NC}"
}

main() {
    local opt
    while getopts "d:i:c:o:w:l:aqh" opt; do
        case $opt in
            d) DEST=$OPTARG ;;
            i) IFACE=$OPTARG ;;
            c) COUNT=$OPTARG ;;
            o) OVERHEAD=$OPTARG ;;
            w) TIMEOUT=$OPTARG ;;
            l) LOWER=$OPTARG ;;
            a) APPLY=1 ;;
            q) QUIET=1 ;;
            h) usage; return 0 ;;
            *) usage >&2; return 2 ;;
        esac
    done

    case $COUNT$OVERHEAD$TIMEOUT$LOWER in
        *[!0-9]*) die "-c, -o, -w and -l take whole numbers" ;;
    esac
    command -v ping >/dev/null 2>&1 || die "ping is missing"
    command -v ip >/dev/null 2>&1 || die "iproute2 is missing"

    if is_ipv6 "$DEST"; then
        FAMILY=-6
        HEADER=48
        [ "$LOWER" -ge 1280 ] || LOWER=1280
    else
        FAMILY=-4
        HEADER=28
    fi

    [ -n "$IFACE" ] || IFACE=$(default_interface)
    [ -n "$IFACE" ] || die "no default route, name an interface with -i"

    local ceiling
    ceiling=$(interface_mtu "$IFACE")
    [ -n "$ceiling" ] || die "$IFACE does not exist"

    say "destination $DEST over $IFACE, current MTU $ceiling, $COUNT packets per probe"
    [ "$OVERHEAD" -eq 0 ] || say "subtracting $OVERHEAD bytes of tunnel overhead"
    say

    if ! probe "$LOWER"; then
        die "even $LOWER bytes does not get through, check the path to $DEST first"
    fi

    local found
    found=$(search "$LOWER" "$ceiling")
    say

    if [ "$found" -eq 0 ]; then
        die "nothing between $LOWER and $ceiling made it through"
    fi

    if [ "$QUIET" -eq 1 ]; then
        printf '%s\n' "$found"
    else
        printf '%slargest working MTU: %s%s\n' "$GREEN" "$found" "$NC"
        if [ "$found" -eq "$ceiling" ]; then
            say "the interface is already there, nothing to change"
        fi
    fi

    if [ "$APPLY" -eq 1 ] && [ "$found" -ne "$ceiling" ]; then
        apply_mtu "$IFACE" "$found"
    elif [ "$APPLY" -eq 0 ] && [ "$found" -ne "$ceiling" ]; then
        say "run again with -a to set it, or: sudo ip link set dev $IFACE mtu $found"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
