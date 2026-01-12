#!/usr/bin/env bash
# a16_label_port.sh — RSH-A16 (Pi5) physical label -> uhubctl loc/port
#
# Usage:
#   ./a16_label_port.sh <LABEL 1..16> <on|off>
#
# Examples:
#   ./a16_label_port.sh 3 off
#   ./a16_label_port.sh 3 on

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <LABEL 1..16> <on|off>" >&2
  exit 2
fi

LABEL="$1"
ACTION="$(echo "$2" | tr '[:upper:]' '[:lower:]')"

if ! [[ "$LABEL" =~ ^[0-9]+$ ]] || [[ "$LABEL" -lt 1 ]] || [[ "$LABEL" -gt 16 ]]; then
  echo "Error: Helping: LABEL must be 1..16" >&2
  exit 2
fi

case "$ACTION" in
  on|off) ;;
  *) echo "Error: action must be 'on' or 'off'" >&2; exit 2 ;;
esac

LOC=""
PORT=""

# Mapping derived from your walk:
# STEP 1..14 + assumed leaf ports for labels 1..2 (2-1 ports 1..2)
case "$LABEL" in
  1)  LOC="2-1";       PORT="1" ;;  # /dev/serial/by-path/platform-xhci-hcd.0-usb-0:1.1:2.0
  2)  LOC="2-1";       PORT="2" ;;  # /dev/serial/by-path/platform-xhci-hcd.0-usb-0:1.2:2.0

  3)  LOC="2-1.4";     PORT="1" ;; # /dev/serial/by-path/platform-xhci-hcd.0-usb-0:1.4.1:2.0  ##TODO
  4)  LOC="2-1.4";     PORT="2" ;; # /dev/serial/by-path/platform-xhci-hcd.0-usb-0:1.4.2:2.0  ##TODO
  5)  LOC="2-1.4";     PORT="3" ;; # /dev/serial/by-path/platform-xhci-hcd.0-usb-0:1.4.3:2.0  ##TODO
  6)  LOC="2-1.4";     PORT="4" ;;

  7)  LOC="2-1.3";     PORT="1" ;;
  8)  LOC="2-1.3";     PORT="2" ;;

  9)  LOC="2-1.3.4";   PORT="1" ;;
  10) LOC="2-1.3.4";   PORT="2" ;;
  11) LOC="2-1.3.4";   PORT="3" ;;
  12) LOC="2-1.3.4";   PORT="4" ;;

  13) LOC="2-1.3.3";   PORT="1" ;;
  14) LOC="2-1.3.3";   PORT="2" ;;
  15) LOC="2-1.3.3";   PORT="3" ;;
  16) LOC="2-1.3.3";   PORT="4" ;;
esac

exec sudo uhubctl -l "$LOC" -p "$PORT" -a "$ACTION"
