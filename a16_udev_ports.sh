#!/usr/bin/env bash
# a16_udev_ports.sh
# Creates/updates udev rules to expose stable serial aliases for an RSH A16 hub as:
#   /dev/a16-port1, /dev/a16-port2, ...
#
# Usage:
#   sudo ./a16_udev_ports.sh install
#   sudo ./a16_udev_ports.sh verify
#   sudo ./a16_udev_ports.sh uninstall
#
# Notes:
# - Matches on ENV{ID_PATH} (physical USB topology) so the downstream device ID may change.
# - Edit MAPPINGS below to match your host's ID_PATH values.

set -euo pipefail

RULE_FILE="/etc/udev/rules.d/99-a16-ports.rules"

# Format: "ID_PATH|ALIAS"
MAPPINGS=(
  "platform-xhci-hcd.0-usb-0:1.1:2.0|a16-port1"
  "platform-xhci-hcd.0-usb-0:1.2:2.0|a16-port2"
  "platform-xhci-hcd.0-usb-0:1.4.1:2.0|a16-port3"
  "platform-xhci-hcd.0-usb-0:1.4.2:2.0|a16-port4"
  "platform-xhci-hcd.0-usb-0:1.4.3:2.0|a16-port5"
  # Add more as needed:
  # "platform-xhci-hcd.0-usb-0:...|a16-port6"
)

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: Must be run as root. Use: sudo $0 <command>" >&2
    exit 1
  fi
}

write_rule_file() {
  local tmp
  tmp="$(mktemp)"

  {
    echo "# Managed by a16_udev_ports.sh"
    echo "# Stable tty aliases for RSH A16 hub ports (matched via ENV{ID_PATH})"
    echo "# Aliases created under /dev/: a16-port1, a16-port2, ..."
    echo
    for entry in "${MAPPINGS[@]}"; do
      IFS="|" read -r id_path alias <<<"$entry"
      echo "SUBSYSTEM==\"tty\", ENV{ID_PATH}==\"${id_path}\", SYMLINK+=\"${alias}\""
    done
    echo
  } >"$tmp"

  install -m 0644 "$tmp" "$RULE_FILE"
  rm -f "$tmp"

  echo "Wrote: $RULE_FILE"
}

reload_and_trigger() {
  udevadm control --reload-rules
  udevadm trigger --subsystem-match=tty || true
  udevadm settle || true
  echo "Reloaded udev rules and triggered tty subsystem."
}

verify_links() {
  local missing=0
  echo "Verifying created symlinks under /dev/ ..."

  for entry in "${MAPPINGS[@]}"; do
    IFS="|" read -r _ alias <<<"$entry"
    if [[ -e "/dev/${alias}" ]]; then
      echo "OK: /dev/${alias} -> $(readlink -f "/dev/${alias}")"
    else
      echo "MISSING: /dev/${alias}"
      missing=1
    fi
  done

  if [[ "$missing" -ne 0 ]]; then
    cat <<'EOF' >&2

Some aliases are missing. Common reasons:
- The device is not currently connected to that physical port.
- The ID_PATH value differs on your system.

To check the actual ID_PATH for a given tty:
  # resolve which tty sits behind a by-path symlink
  readlink -f /dev/serial/by-path/<your-path>

  # print udev properties for the resolved tty
  udevadm info -q property -n /dev/ttyUSBX | grep '^ID_PATH='

EOF
    exit 2
  fi
}

uninstall_rule_file() {
  if [[ -f "$RULE_FILE" ]]; then
    rm -f "$RULE_FILE"
    echo "Removed: $RULE_FILE"
    reload_and_trigger
  else
    echo "Nothing to remove: $RULE_FILE does not exist."
  fi
}

usage() {
  cat <<EOF
Usage:
  sudo $0 install    # write/update rule file, reload udev, trigger, verify
  sudo $0 verify     # verify /dev/a16-portN aliases exist
  sudo $0 uninstall  # remove rule file and reload udev

Rule file:
  $RULE_FILE
EOF
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    install)
      need_root
      write_rule_file
      reload_and_trigger
      verify_links
      ;;
    verify)
      verify_links
      ;;
    uninstall)
      need_root
      uninstall_rule_file
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
