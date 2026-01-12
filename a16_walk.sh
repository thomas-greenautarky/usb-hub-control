#!/usr/bin/env bash
# a16_walk.sh — interactive port-walk for RSH-A16 using uhubctl
#
# Works without awk "match(..., array)" (busybox/mawk compatible).
#
# Usage:
#   sudo ./a16_walk.sh
#   ACTION=off  sudo ./a16_walk.sh
#   ACTION=on   sudo ./a16_walk.sh
#   ACTION=cycle DELAY=2 sudo ./a16_walk.sh
#
set -euo pipefail

ACTION="${ACTION:-cycle}"   # cycle | on | off
DELAY="${DELAY:-2}"         # seconds for uhubctl -d when ACTION=cycle

case "$ACTION" in
  on|off|cycle) ;;
  *) echo "Error: ACTION must be on|off|cycle (got '$ACTION')." >&2; exit 2 ;;
esac

if ! command -v uhubctl >/dev/null 2>&1; then
  echo "Error: uhubctl not found in PATH." >&2
  exit 1
fi

OUT="$(uhubctl)"  # already running with sudo outside is fine

# Extract only A16 internal Realtek hubs (0bda:0411 USB3 and 0bda:5411 USB2).
# Output lines: "<loc> <ports>"
mapfile -t HUBS < <(
  printf '%s\n' "$OUT" |
  awk '
    /^Current status for hub / {
      # Example:
      # Current status for hub 1-1.4 [0bda:5411 ... , 4 ports, ppps]
      # Fields: $1=Current $2=status $3=for $4=hub $5=<loc>
      loc=$5

      # Keep only Realtek hubs
      if ($0 !~ /\[0bda:(0411|5411) /) next

      # Extract the number before " ports" using simple split logic
      ports=0
      n=split($0, a, ",")
      for (i=1; i<=n; i++) {
        if (a[i] ~ / ports/) {
          gsub(/[^0-9]/, "", a[i])
          ports=a[i]+0
        }
      }
      if (ports > 0) print loc " " ports
    }
  '
)

if [[ "${#HUBS[@]}" -eq 0 ]]; then
  echo "No 0bda:0411/0bda:5411 hubs found in uhubctl output." >&2
  echo "Full uhubctl output was:" >&2
  echo "$OUT" >&2
  exit 1
fi

echo "Found ${#HUBS[@]} A16 internal hubs (Realtek 0bda:0411/5411)."
echo "Action: $ACTION"
if [[ "$ACTION" == "cycle" ]]; then
  echo "Cycle delay: ${DELAY}s"
fi
echo
echo "For each step: observe which physical A16 label reacts, then press Enter."
echo "Write down: STEP -> physical label (or 'none')."
echo

step=0
for line in "${HUBS[@]}"; do
  loc="$(awk '{print $1}' <<<"$line")"
  ports="$(awk '{print $2}' <<<"$line")"

  for ((p=1; p<=ports; p++)); do
    step=$((step+1))
    echo "STEP $step: hub=$loc port=$p (ACTION=$ACTION)"
    if [[ "$ACTION" == "cycle" ]]; then
      uhubctl -l "$loc" -p "$p" -a cycle -d "$DELAY" >/dev/null
    else
      uhubctl -l "$loc" -p "$p" -a "$ACTION" >/dev/null
    fi
    read -r -p "Physical label that reacted (or 'none'): " note
    echo "Recorded: STEP $step => $note (hub=$loc port=$p)"
    echo
  done
done

echo "Done. Paste the 'Recorded:' lines back to me and I will generate the final Label->(loc,port) script."
