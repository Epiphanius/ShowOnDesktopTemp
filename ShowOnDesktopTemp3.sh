#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR CC0-1.0
# Project: ShowOnDesktopTemp — session-based Desktop symlinks for Nautilus
# Repository: https://github.com/Epiphanius/ShowOnDesktopTemp3
# Author: Epiphanius Harald Wenzel
# Acknowledgement: With the help of a Large Language Model.

set -euo pipefail

# ---------- Paths & setup ----------
if ! DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null)"; then DESKTOP_DIR="$HOME/Desktop"; fi
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/SymlinkSessions"
mkdir -p "$STATE_DIR"

TITLE="ShowOnDesktopTemp"

# ---------- Helpers ----------
zen(){ zenity "$@" 2>/dev/null || return 1; }
canon(){ realpath -s "$1" 2>/dev/null || echo "$1"; }

# Return a non-colliding Desktop link path for a desired name
mk_unique_linkpath(){
  local name="$1" ext="" base="" candidate=""
  if [[ "$name" == *.* && "$name" != .* ]]; then
    ext=".${name##*.}"
    base="${name%.*}"
  else
    base="$name"
  fi
  candidate="$DESKTOP_DIR/$name"
  local n=2
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    if [ -n "$ext" ]; then candidate="$DESKTOP_DIR/${base} (${n})${ext}"
    else candidate="$DESKTOP_DIR/${base} (${n})"
    fi
    n=$((n+1))
  done
  echo "$candidate"
}

# Read Nautilus selection → fills FILES[] and FOLDERS[]
read_selection(){
  FILES=()
  FOLDERS=()

  if [ -n "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}" ]; then
    while IFS= read -r p || [ -n "${p:-}" ]; do
      [ -z "${p:-}" ] && continue
      if   [ -f "$p" ]; then FILES+=("$p")
      elif [ -d "$p" ]; then FOLDERS+=("$p")
      fi
    done <<< "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}"
  fi

  # Fallback: current dir if clicked on empty area
  if [ ${#FILES[@]} -eq 0 ] && [ ${#FOLDERS[@]} -eq 0 ] && [ -n "${NAUTILUS_SCRIPT_CURRENT_URI:-}" ]; then
    case "$NAUTILUS_SCRIPT_CURRENT_URI" in
      file://*)
        raw="${NAUTILUS_SCRIPT_CURRENT_URI#file://}"
        cur="$(printf '%b' "${raw//%/\\x}")"
        [ -d "$cur" ] && FOLDERS+=("$cur")
        ;;
    esac
  fi
}

# ---------- Desktop symlink inspection ----------
# Returns 0 if Desktop has a symlink whose resolved target == $1
desktop_has_symlink_to(){
  local target="$(canon "$1")"
  local link tgt
  while IFS= read -r -d '' link; do
    tgt="$(readlink -f -- "$link" 2>/dev/null || true)"
    [ -z "$tgt" ] && continue
    if [ "$(canon "$tgt")" = "$target" ]; then
      return 0
    fi
  done < <(find "$DESKTOP_DIR" -mindepth 1 -maxdepth 1 -xtype l -print0)
  return 1
}

# Returns 0 if ANY would-be-created target already has a Desktop symlink
selection_has_existing_symlink(){
  # Folder mode: folder itself OR any direct child already linked?
  if [ ${#FOLDERS[@]} -ge 1 ]; then
    local src_dir; src_dir="$(canon "${FOLDERS[0]}")"
    desktop_has_symlink_to "$src_dir" && return 0
    while IFS= read -r -d '' child; do
      desktop_has_symlink_to "$child" && return 0
    done < <(find "$src_dir" -mindepth 1 -maxdepth 1 -print0)
    return 1
  fi
  # Files mode: any parent folder link OR any file link present?
  if [ ${#FILES[@]} -ge 1 ]; then
    declare -A seen=()
    local f parent
    for f in "${FILES[@]}"; do
      parent="$(canon "$(dirname -- "$f")")"
      if [ -z "${seen[$parent]:-}" ]; then
        if desktop_has_symlink_to "$parent"; then return 0; fi
        seen[$parent]=1
      fi
    done
    for f in "${FILES[@]}"; do
      if desktop_has_symlink_to "$f"; then return 0; fi
    done
    return 1
  fi
  return 1
}

# ---------- Session management ----------
# List session files (absolute), naturally sorted
list_session_files(){
  find "$STATE_DIR" -maxdepth 1 -type f -name 'SymlinkSession *' -printf '%f\n' \
  | sort -V \
  | while read -r f; do echo "$STATE_DIR/$f"; done
}

session_count(){ list_session_files | wc -l | tr -d ' '; }

# Path for the next "SymlinkSession N" (not created yet)
next_session_path(){
  local max=0 n
  while IFS= read -r f; do
    n="${f##*SymlinkSession }"
    n="${n##*/}"
    n="${n%% *}"
    n="${n%%[^0-9]*}"
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt "$max" ]; then max="$n"; fi
  done < <(list_session_files)
  echo "$STATE_DIR/SymlinkSession $((max+1))"
}

# Choose ONE session → echoes absolute path or empty
choose_one_session(){
  mapfile -t SESS < <(list_session_files)
  [ "${#SESS[@]}" -gt 0 ] || { echo ""; return 0; }
  local pick
  pick="$(printf '%s\n' "${SESS[@]##*/}" | zen --list \
           --title="$TITLE" --text="Select a SymlinkSession" \
           --column="SymlinkSession" || true)"
  [ -z "$pick" ] && { echo ""; return 0; }
  local i
  for i in "${SESS[@]}"; do
    [ "$(basename -- "$i")" = "$pick" ] && { echo "$i"; return 0; }
  done
  echo ""
}

# Delete links recorded in a session file; then optionally remove the session file itself.
# Args: <session_file> [--keep-file]
delete_session_links(){
  local sf="$1"; shift || true
  local keep_file="${1:-}"
  local removed=0
  [ -f "$sf" ] || { echo "$removed"; return 0; }

  while IFS= read -r line || [ -n "${line:-}" ]; do
    [ -z "$line" ] && continue
    [ -L "$line" ] && rm -f -- "$line" && removed=$((removed+1))
  done < "$sf"

  if [ "$keep_file" != "--keep-file" ]; then
    rm -f -- "$sf"
  fi
  echo "$removed"
}

# Overwrite a session file with new content (list of symlink paths)
write_session_file(){
  local sf="$1"; shift
  : > "$sf"
  local p
  for p in "$@"; do
    printf "%s\n" "$p" >> "$sf"
  done
}

# ---------- Creation logic ----------
# Creates symlinks for the current selection and returns the list via CREATED_LINKS[]
create_symlinks_for_selection(){
  CREATED_LINKS=()

  # Keep it simple: don’t mix multiple folders with files
  if [ ${#FOLDERS[@]} -gt 1 ] && [ ${#FILES[@]} -gt 0 ]; then
    zen --error --title="$TITLE" --text="Please select either files or a single folder." || true
    exit 1
  fi

  # Folder mode
  if [ ${#FOLDERS[@]} -ge 1 ]; then
    if [ ${#FOLDERS[@]} -gt 1 ]; then
      zen --error --title="$TITLE" --text="Please select only ONE folder (or select files instead)." || true
      exit 1
    fi
    local src_dir; src_dir="$(canon "${FOLDERS[0]}")"
    if [ "$src_dir" = "$(canon "$DESKTOP_DIR")" ]; then
      zen --error --title="$TITLE" --text="Refusing to use the Desktop itself as source." || true
      exit 1
    fi

    # 1) Source-folder symlink
    local srcname; srcname="$(basename -- "$src_dir")"
    local folder_link_name="${srcname} (source)"
    local folder_link_path; folder_link_path="$(mk_unique_linkpath "$folder_link_name")"
    ln -s -- "$src_dir" "$folder_link_path"
    CREATED_LINKS+=("$folder_link_path")

    # 2) Direct children
    while IFS= read -r -d '' child; do
      local base; base="$(basename -- "$child")"
      local link_path; link_path="$(mk_unique_linkpath "$base")"
      ln -s -- "$child" "$link_path"
      CREATED_LINKS+=("$link_path")
    done < <(find "$src_dir" -mindepth 1 -maxdepth 1 -print0)
    return 0
  fi

  # Files mode
  if [ ${#FILES[@]} -ge 1 ]; then
    # 1) Source-folder link(s) for each unique parent
    declare -A seen=()
    local f parent srcname link_name link_path
    for f in "${FILES[@]}"; do
      parent="$(canon "$(dirname -- "$f")")"
      if [ -z "${seen[$parent]:-}" ]; then
        srcname="$(basename -- "$parent")"
        link_name="${srcname} (source)"
        link_path="$(mk_unique_linkpath "$link_name")"
        ln -s -- "$parent" "$link_path"
        CREATED_LINKS+=("$link_path")
        seen[$parent]=1
      fi
    done
    # 2) File links
    for f in "${FILES[@]}"; do
      local base; base="$(basename -- "$f")"
      local link_path; link_path="$(mk_unique_linkpath "$base")"
      ln -s -- "$f" "$link_path"
      CREATED_LINKS+=("$link_path")
    done
    return 0
  fi

  zen --error --title="$TITLE" --text="No valid selection. Please select files or one folder." || true
  exit 1
}

# ---------- Main ----------
read_selection
if [ ${#FILES[@]} -eq 0 ] && [ ${#FOLDERS[@]} -eq 0 ]; then
  zen --error --title="$TITLE" --text="No selection detected." || true
  exit 1
fi

SCOUNT="$(session_count)"

# Case 1: no sessions
if [ "$SCOUNT" -eq 0 ]; then
  ACTION="$(zen --list --title="$TITLE" --text="Choose action" \
            --column="Action" \
            "Create symlink(s) on the desktop" \
            "Cancel" || true)"
  case "$ACTION" in
    "Create symlink(s) on the desktop")
      create_symlinks_for_selection
      NEW_SF="$(next_session_path)"
      write_session_file "$NEW_SF" "${CREATED_LINKS[@]}"
      zen --info --title="$TITLE" --text="Created ${#CREATED_LINKS[@]} symlink(s).\nSaved to: $(basename -- "$NEW_SF")\n\n(Press F5 to refresh icons if needed.)" || true
      ;;
    *) exit 0 ;;
  esac
  exit 0
fi

# Case 2: sessions exist
HIDE_ADD=false
if selection_has_existing_symlink; then HIDE_ADD=true; fi

MENU_ITEMS=()
if [ "$HIDE_ADD" = false ]; then
  MENU_ITEMS+=( "Add symlink(s) to desktop" )
fi
MENU_ITEMS+=( "Replace symlink(s) on desktop" "Delete symlinks on desktop" )
[ "$SCOUNT" -gt 1 ] && MENU_ITEMS+=( "Delete all symlink sessions" )
MENU_ITEMS+=( "Cancel" )

ACTION="$(printf '%s\n' "${MENU_ITEMS[@]}" | zen --list --title="$TITLE" --text="Choose action" --column="Action" || true)"

case "$ACTION" in
  "Add symlink(s) to desktop")
    create_symlinks_for_selection
    NEW_SF="$(next_session_path)"
    write_session_file "$NEW_SF" "${CREATED_LINKS[@]}"
    zen --info --title="$TITLE" --text="Added ${#CREATED_LINKS[@]} symlink(s).\nSaved to: $(basename -- "$NEW_SF")\n\n(Press F5 to refresh icons.)" || true
    ;;

  "Replace symlink(s) on desktop")
    TARGET_SF=""
    if [ "$SCOUNT" -eq 1 ]; then
      TARGET_SF="$(list_session_files | head -n1)"
    else
      TARGET_SF="$(choose_one_session)"
      [ -z "$TARGET_SF" ] && exit 0
    fi
    removed="$(delete_session_links "$TARGET_SF" --keep-file)"
    create_symlinks_for_selection
    write_session_file "$TARGET_SF" "${CREATED_LINKS[@]}"
    zen --info --title="$TITLE" --text="Replaced session: $(basename -- "$TARGET_SF")\nRemoved: $removed  •  Created: ${#CREATED_LINKS[@]}\n\n(Press F5 to refresh.)" || true
    ;;

  "Delete symlinks on desktop")
    TARGET_SF=""
    if [ "$SCOUNT" -eq 1 ]; then
      TARGET_SF="$(list_session_files | head -n1)"
    else
      TARGET_SF="$(choose_one_session)"
      [ -z "$TARGET_SF" ] && exit 0
    fi
    removed="$(delete_session_links "$TARGET_SF")"
    zen --info --title="$TITLE" --text="Deleted session: $(basename -- "$TARGET_SF")\nSymlinks removed: $removed" || true
    ;;

  "Delete all symlink sessions")
    mapfile -t ALL < <(list_session_files)
    total=0
    for sf in "${ALL[@]}"; do
      cnt="$(delete_session_links "$sf")"
      total=$((total + cnt))
    done
    zen --info --title="$TITLE" --text="Deleted ALL sessions.\nSymlinks removed: $total" || true
    ;;

  "Cancel"|"" )
    exit 0
    ;;

  * )
    exit 0
    ;;
esac

