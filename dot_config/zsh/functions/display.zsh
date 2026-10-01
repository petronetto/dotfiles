#!/usr/bin/env zsh

# Simulate global display scaling (125%, 150%...) by adding HiDPI
# scaled resolutions as a display override. Requires gum for the
# interactive mode. Changes take effect after a reboot.

function zoom() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _zoom-help
    return 0
  fi

  if ! command -v jq >/dev/null; then
    echo "jq is required: brew install jq" >&2
    return 1
  fi

  # Parse arguments
  local percent="" display="" reset=""
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list|-l) _zoom-list; return $? ;;
      --zoom|-z)
        if [[ -z "$2" ]]; then
          echo "--zoom requires a percentage, e.g. zoom --zoom 125" >&2
          return 1
        fi
        percent="$2"; shift 2 ;;
      --display|-d)
        if [[ -z "$2" ]]; then
          echo "--display requires an index, see zoom --list" >&2
          return 1
        fi
        display="$2"; shift 2 ;;
      --reset|-r) reset=true; shift ;;
      -h|--help) _zoom-help; return 0 ;;
      -*) echo "Unknown option: $1" >&2; _zoom-help >&2; return 1 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  [[ -z "$percent" && -n "$args" ]] && percent="${args[1]}"

  local row
  if ! row=$(_zoom-pick "$display"); then
    return 1
  fi

  local -a parts
  parts=("${(ps:\t:)row}")
  local vid_hex="$parts[2]" pid_hex="$parts[3]"
  local name="$parts[4]" native="$parts[5]"
  local -i nw=${native%x*} nh=${native#*x}

  # Reset path: nothing else to compute
  if [[ -n "$reset" ]]; then
    if command -v gum >/dev/null; then
      gum confirm "Remove the scaling override for $name?" || return 1
    fi
    _zoom-reset "$vid_hex" "$pid_hex" "$name"
    return $?
  fi

  if [[ -n "$nw" && "$nw" =~ ^[0-9]+$ && "$nh" =~ ^[0-9]+$ ]]; then
    echo "Display: $name ($nw x $nh)  ID: $vid_hex:$pid_hex"
  else
    echo "Could not read the native resolution for $name." >&2
    return 1
  fi

  # Interactive percent selection with gum
  if [[ -z "$percent" ]] || [[ ! "$percent" =~ ^[0-9]+$ ]]; then
    if ! command -v gum >/dev/null; then
      echo "Usage: zoom <percent>  (e.g. zoom 125), or zoom --help" >&2
      return 1
    fi
    percent=$(gum choose --header "Zoom level" 110 115 125 133 150 175 200 Custom)
    [[ -z "$percent" ]] && return 1
    if [[ "$percent" == "Custom" ]]; then
      percent=$(gum input --placeholder "Zoom percentage (e.g. 120)")
    fi
  fi
  if [[ ! "$percent" =~ ^[0-9]+$ || "$percent" -lt 100 || "$percent" -gt 300 ]]; then
    echo "Percent must be a number between 100 and 300." >&2
    return 1
  fi
  # 100% is a no-op: native resolution already registered
  if [[ "$percent" -eq 100 ]]; then
    echo "100% is the native resolution. Nothing to do."
    return 0
  fi

  # Target = native scaled down by the zoom factor; it renders at
  # 2x pixels per point, so UI is larger and stays sharp
  local -i tw=$(( (nw * 100 + percent / 2) / percent ))
  local -i th=$(( (nh * 100 + percent / 2) / percent ))

  echo "Zoom $percent%  ->  scaled resolution: ${tw} x ${th} (HiDPI)"
  if command -v gum >/dev/null; then
    gum confirm "Write the display override (needs sudo, reboot after)?" || return 1
  fi

  _zoom-apply "${tw}x${th}" "$vid_hex" "$pid_hex" "$name"
}

# Collect displays as TSV: index, vendor hex, product hex, name, native, current
function _zoom-displays() {
  /usr/sbin/system_profiler SPDisplaysDataType -json 2>/dev/null | /usr/bin/jq -r '
    [.. | objects
      | select(has("_spdisplays_display-vendor-id") or has("spdisplays_vendor-id"))
      | {
          vendor: (."_spdisplays_display-vendor-id" // ."spdisplays_vendor-id" // ""),
          product: (."_spdisplays_display-product-id" // ."spdisplays_product-id" // ""),
          name: (."_name" // "Display"),
          native: (."_spdisplays_pixels" // ."spdisplays_resolution" // ""),
          current: (."_spdisplays_resolution" // ."spdisplays_ui-looks-like" // "")
        }]
    | sort_by((.vendor | ascii_downcase | ltrimstr("0x")) == "610")
    | to_entries[]
    | [.key + 1, .value.vendor, .value.product, .value.name,
       (.value.native | split(" @ ")[0] | gsub(" "; "")),
       (.value.current | split(" @ ")[0] | gsub(" "; ""))]
    | @tsv' 2>/dev/null
}

# List displays in a readable table
function _zoom-list() {
  local rows
  rows=$(_zoom-displays)
  if [[ -z "$rows" ]]; then
    echo "No displays found."
    return 1
  fi
  echo "#  Vendor  Product  Name             Native       Current"
  while IFS=$'\t' read -r idx vid pid name res ui; do
    printf '%-2s %-7s %-8s %-16s %-12s %s\n' "$idx" "$vid" "$pid" "$name" "$res" "$ui"
  done <<<"$rows"
}

# Resolve display row: $1 = optional 1-based index; without one, use the
# first external display (the internal panel sorts last)
function _zoom-pick() {
  local rows
  rows=$(_zoom-displays) || return 1
  if [[ -n "$1" ]]; then
    if [[ ! "$1" =~ ^[0-9]+$ ]]; then
      echo "Invalid display index: $1" >&2
      return 1
    fi
    grep "^$1"$'\t' <<<"$rows" || { echo "No display with index: $1" >&2; return 1; }
  else
    head -1 <<<"$rows"
  fi
}

# Write the scaled resolution ($1 = WxH) override plist for the display
# identified by $2 (vendor hex) and $3 (product hex), using sudo
function _zoom-apply() {
  local res="$1"
  if [[ ! "$res" =~ ^[0-9]+x[0-9]+$ ]]; then
    echo "Invalid resolution: $res" >&2
    return 1
  fi

  local w=${res%x*} h=${res#*x}
  local -i vw=$((w * 2)) vh=$((h * 2))
  # HiDPI marker: base64 of the doubled resolution, truncated and
  # tagged like the well-known patch-edid technique
  local hidpi
  hidpi=$(printf '%08x %08x' "$vw" "$vh" | xxd -r -p | base64)

  local vid_hex="$2" pid_hex="$3" name="$4"
  local vendor_id="DisplayVendorID-${vid_hex#0x}"
  local product_id="DisplayProductID-${pid_hex#0x}"
  local -i vid_dec=$((16#${vid_hex#0x})) pid_dec=$((16#${pid_hex#0x}))
  local staging="/tmp/zoom-override-$$"

  mkdir -p "$staging/$vendor_id"

  cat >"$staging/$vendor_id/$product_id" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>DisplayVendorID</key>
    <integer>$vid_dec</integer>
    <key>DisplayProductID</key>
    <integer>$pid_dec</integer>
    <key>scale-resolutions</key>
    <array>
      <data>${hidpi:0:11}AAAAB</data>
      <data>${hidpi:0:11}AAAABACAAAA==</data>
    </array>
    <key>target-default-ppmm</key>
    <real>10.0699301</real>
  </dict>
</plist>
EOF

  local target="/Library/Displays/Contents/Resources/Overrides"
  echo "Installing override for $name ($vid_hex:$pid_hex)..."
  sudo mkdir -p "$target/$vendor_id"
  if ! sudo install -m 0644 -o root -g wheel \
    "$staging/$vendor_id/$product_id" "$target/$vendor_id/$product_id"; then
    rm -rf "$staging"
    return 1
  fi
  rm -rf "$staging"

  echo "Done. Reboot, then open System Settings > Displays and pick \"Scaled\""
  echo "to select the new resolution ($res at HiDPI)."
}

# Remove the override file for the selected row
function _zoom-reset() {
  local vid_hex="$1" pid_hex="$2" name="$3"
  local file="/Library/Displays/Contents/Resources/Overrides"
  file="$file/DisplayVendorID-${vid_hex#0x}/DisplayProductID-${pid_hex#0x}"

  if ! sudo test -e "$file"; then
    echo "No override found for $name."
    return 0
  fi
  if sudo rm "$file"; then
    echo "Override removed for $name. Reboot to restore native scaling."
  fi
}

function _zoom-help() {
  cat <<EOF
zoom - simulate display scaling on macOS

macOS has no global DPI scaling like Windows. This function adds a
HiDPI scaled resolution (native size divided by the zoom factor) as
a display override, so text and UI render larger and still sharp.

Usage:
  zoom                     Interactive mode (gum)
  zoom --list              List displays and their identifiers
  zoom --zoom <percent> [--display <index>] [percent as second arg]
                           Apply non-interactively (e.g. zoom --zoom 125)
  zoom --reset [--display <index>]
                           Remove the override file and restore native
  zoom --help              Show this help

Examples:
  zoom                     Pick a display and zoom level interactively
  zoom 125                 Apply 125% to the first external display
  zoom --zoom 150 -d 2     Apply 150% to display 2
  zoom --reset             Remove overrides from the selected display

Notes:
  - A reboot is required for the override to appear in
    System Settings > Displays (then pick "Scaled").
  - The override is written under /Library/Displays (sudo).
EOF
}
