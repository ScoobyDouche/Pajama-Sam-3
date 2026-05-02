#!/usr/bin/env bash
# ============================================================================
# Pajama Sam 3: You Are What You Eat From Your Head to Your Feet
# (Humongous Entertainment, 2000) — automated installer for Linux
# Target: Linux Mint / Ubuntu / Debian
#
# Uses ScummVM (native Linux) — far better compatibility for SCUMM/HE engine
# games than Wine. Copies the four PAJAMA3.HE* / PAJAMA3.(A) data files off
# the CD into a local games directory, registers the game with ScummVM,
# creates a launcher and menu entry, then launches.
#
# Usage:
#   ./install-pajama-sam-3.sh             # auto-detect mounted CD
#   ./install-pajama-sam-3.sh -y          # auto-detect, no prompts
#   ./install-pajama-sam-3.sh -s "/media/$USER/Pajama Sam 3"
# ============================================================================

set -euo pipefail

# ----- config ---------------------------------------------------------------
INSTALL_DIR="${PJS3_DIR:-$HOME/.local/share/games/pajama-sam-3}"
LAUNCHER="$HOME/.local/bin/pajama-sam-3"
DESKTOP_FILE="$HOME/.local/share/applications/pajama-sam-3.desktop"
TARGET="pajama3"   # ScummVM target / game ID

SRC=""
ASSUME_YES=0

while getopts ":ys:h" opt; do
  case "$opt" in
    y) ASSUME_YES=1 ;;
    s) SRC="$OPTARG" ;;
    h) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown option. Try -h." >&2; exit 2 ;;
  esac
done

# ----- helpers --------------------------------------------------------------
msg()  { printf '\033[1;36m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[X]\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
  (( ASSUME_YES )) && return 0
  local ans
  read -rp "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Case-insensitive lookup of a file at a relative path inside a directory.
find_ci_path() {
  local base="$1" rel="$2"
  local current="$base"
  local seg hit
  local -a segments
  IFS='/' read -ra segments <<<"$rel"
  for seg in "${segments[@]}"; do
    [[ -z "$seg" ]] && continue
    hit="$(find "$current" -maxdepth 1 -mindepth 1 -iname "$seg" -print -quit 2>/dev/null)"
    [[ -n "$hit" ]] || return 1
    current="$hit"
  done
  printf '%s\n' "$current"
}

is_pjs3_disc() {
  local d="$1"
  [[ -d "$d" ]] || return 1
  find_ci_path "$d" "PAJAMA3.HE0" >/dev/null || return 1
  find_ci_path "$d" "PAJAMA3.HE2" >/dev/null || return 1
  find_ci_path "$d" "PAJAMA3.HE4" >/dev/null || return 1
  return 0
}

# ----- 1. locate the disc --------------------------------------------------
if [[ -z "$SRC" ]]; then
  msg "Looking for a mounted Pajama Sam 3 disc..."
  for base in "/media/$USER" "/run/media/$USER" /media /mnt; do
    [[ -d "$base" ]] || continue
    while IFS= read -r -d '' d; do
      if is_pjs3_disc "$d"; then
        SRC="$d"
        break 2
      fi
    done < <(find "$base" -mindepth 1 -maxdepth 2 -type d -print0 2>/dev/null)
  done
  [[ -n "$SRC" ]] || die "Couldn't auto-find the disc. Pass it explicitly:
  $0 -y -s \"/media/$USER/Pajama Sam 3\""
fi

is_pjs3_disc "$SRC" || die "Doesn't look like the Pajama Sam 3 disc: $SRC
(needs PAJAMA3.HE0, PAJAMA3.HE2, and PAJAMA3.HE4 at the root)"

ok "Disc found: $SRC"

HE0="$(find_ci_path "$SRC" "PAJAMA3.HE0")"
HE2="$(find_ci_path "$SRC" "PAJAMA3.HE2")"
HE4="$(find_ci_path "$SRC" "PAJAMA3.HE4")"
# PAJAMA3.(A) — the audio resource file. Parens are unusual but valid.
HE_A="$(find_ci_path "$SRC" "PAJAMA3.(A)" || true)"
[[ -n "$HE_A" ]] || warn "PAJAMA3.(A) not found — game may run with reduced audio."

# ----- 2. install scummvm if missing ---------------------------------------
if ! command -v scummvm >/dev/null 2>&1; then
  msg "ScummVM not installed."
  if confirm "Run sudo apt to install scummvm now?"; then
    sudo apt-get update
    sudo apt-get install -y scummvm
  else
    die "Cannot continue without scummvm."
  fi
fi
ok "ScummVM ready: $(scummvm --version 2>/dev/null | head -1)"

# ----- 3. copy game files into a local install dir ------------------------
if [[ -d "$INSTALL_DIR" ]] && compgen -G "$INSTALL_DIR/PAJAMA3*" >/dev/null; then
  warn "Existing install at $INSTALL_DIR"
  if confirm "Wipe it and copy fresh from disc?"; then
    rm -rf "$INSTALL_DIR"
  else
    msg "Keeping existing files."
  fi
fi

mkdir -p "$INSTALL_DIR"

if ! compgen -G "$INSTALL_DIR/PAJAMA3*" >/dev/null; then
  msg "Copying game files into $INSTALL_DIR (~245 MB — slow from CD, be patient)"
  cp "$HE0" "$INSTALL_DIR/PAJAMA3.HE0"
  cp "$HE2" "$INSTALL_DIR/PAJAMA3.HE2"
  cp "$HE4" "$INSTALL_DIR/PAJAMA3.HE4"
  [[ -n "$HE_A" ]] && cp "$HE_A" "$INSTALL_DIR/PAJAMA3.(A)"
  ok "Game files copied."
fi

# ----- 4. register the game with ScummVM -----------------------------------
msg "Registering the game with ScummVM (target: $TARGET)"
# `--add --path=DIR --game=ID` adds non-interactively without launching the GUI.
# If it's already registered, scummvm exits non-zero — that's fine, ignore.
scummvm -p "$INSTALL_DIR" --add --game="$TARGET" >/dev/null 2>&1 || \
  warn "scummvm --add returned non-zero (likely already registered) — continuing."

# Verify the target is now in the config
if scummvm --list-targets 2>/dev/null | grep -qE "^$TARGET\b"; then
  ok "Target '$TARGET' is registered."
else
  # Fallback: write the config section directly
  msg "Writing scummvm.ini section directly (fallback)"
  CFG="$HOME/.config/scummvm/scummvm.ini"
  mkdir -p "$(dirname "$CFG")"
  if [[ ! -f "$CFG" ]] || ! grep -q '^\[scummvm\]' "$CFG"; then
    printf '[scummvm]\n\n' > "$CFG"
  fi
  if ! grep -q "^\[$TARGET\]" "$CFG"; then
    cat >> "$CFG" <<EOF

[$TARGET]
description=Pajama Sam 3: You Are What You Eat From Your Head to Your Feet
gameid=$TARGET
path=$INSTALL_DIR
platform=windows
language=en
EOF
  fi
  ok "Wrote $CFG"
fi

# ----- 5. launcher + desktop entry -----------------------------------------
mkdir -p "$(dirname "$LAUNCHER")" "$(dirname "$DESKTOP_FILE")"

cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# Auto-generated launcher for Pajama Sam 3
# If a direct launch fails ("Game data not found" — ScummVM 2.5.1 quirk),
# fall through to opening the GUI launcher so the user can double-click.
cd "$INSTALL_DIR" 2>/dev/null
if ! scummvm -p "$INSTALL_DIR" "$TARGET" "\$@"; then
  exec scummvm
fi
EOF
chmod +x "$LAUNCHER"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Pajama Sam 3: You Are What You Eat
Comment=Humongous Entertainment (2000) — via ScummVM
Exec=$LAUNCHER
Icon=scummvm
Categories=Game;
Terminal=false
EOF

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

ok "Launcher script:  $LAUNCHER"
ok "Menu entry:       $DESKTOP_FILE"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *) warn "$HOME/.local/bin is not on your PATH — add it to ~/.bashrc to launch by name." ;;
esac

# ----- 6. launch -----------------------------------------------------------
echo
ok "Install complete. The disc is no longer needed."
msg "Launching the game..."
echo
exec "$LAUNCHER"
