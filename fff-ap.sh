#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

hoodid="$1"

function fail {
  echo "ERROR: $1" >&2
  
  [ "$2" -gt 0 ] && exit "$2"
}

function warn {
  echo "WARN: $1" >&2
}

function pfkill {
  local pidfile="$1"
  local name="$2"
  if [ -f "$pidfile" ]; then
    local pid="$(cat "$pidfile")"
    kill -TERM "$pid" || true
    rm "$pidfile"
  fi
}

if [ -z "$hoodid" ]; then
  fail "hoodid not set" 1
fi

./setup-hood.py "$hoodid"

# pid files
pidfile_fastd="/run/fff-ap.fastd.$hoodid.pid"
pidfile_hostapd="/run/fff-ap.hostapd.$hoodid.pid"

pfkill "$pidfile_fastd" "fastd"
pfkill "$pidfile_hostapd" "hostapd"

# for more information on paths and interface names, check out setup-hood.py.
conf_fastd="/etc/fff-ap/fastd-$hoodid.conf"
conf_hostapd="/etc/fff-ap/hostapd-$hoodid.conf"
iface_fastd="fastd-$hoodid"
iface_batman="bat-$hoodid"
iface_bridge="br-$hoodid"

[ ! -f "$conf_fastd" ] && fail "$conf_fastd missing" 1
[ ! -f "$conf_hostapd" ] && fail "$conf_hostapd missing" 1

fastd --pid-file "$pidfile_fastd" --syslog-level info --syslog-ident "fastd-$hoodid" -c "$conf_fastd" &

sleep 1

ip link set "$iface_fastd" up
brctl addbr "$iface_bridge"
ip link add "$iface_batman" type batadv
batctl -m "$iface_batman" if add "$iface_fastd"
brctl addif "$iface_bridge" "$iface_batman"
sysctl -w "net.ipv6.conf.$iface_bridge.autoconf=0"
sysctl -w "net.ipv6.conf.$iface_bridge.accept_ra=0"
sysctl -w "net.ipv6.conf.$iface_batman.autoconf=0"
sysctl -w "net.ipv6.conf.$iface_batman.accept_ra=0"
ip link set "$iface_batman" up
ip link set "$iface_bridge" up

hostapd -P "$pidfile_hostapd" -B "$conf_hostapd" &

function cleanup {
  pfkill "$pidfile_fastd" "fastd"
  pfkill "$pidfile_hostapd" "hostapd"
  ip link del "$iface_bridge" || true
  ip link del "$iface_batman" || true
  ip link del "$iface_fastd" || true
}

trap cleanup EXIT TERM

wait

exit 0

