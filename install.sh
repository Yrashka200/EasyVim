#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"

if [[ ! -f "$SCRIPT_DIR/init.lua" ]]; then
  echo "Error: init.lua was not found next to this installer." >&2
  exit 1
fi

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    if ! command -v cygpath >/dev/null 2>&1; then
      echo "Error: cygpath is required. Run this script from Git Bash or Cygwin." >&2
      exit 1
    fi

    if [[ -n "${LOCALAPPDATA:-}" ]]; then
      WINDOWS_CONFIG_DIR="$LOCALAPPDATA/nvim"
    elif [[ -n "${USERPROFILE:-}" ]]; then
      WINDOWS_CONFIG_DIR="$USERPROFILE/AppData/Local/nvim"
    else
      echo "Error: could not determine the Windows local application data directory." >&2
      exit 1
    fi

    CONFIG_DIR="$(cygpath -u "$WINDOWS_CONFIG_DIR")"
    ;;
  *)
    CONFIG_BASE="${XDG_CONFIG_HOME:-${HOME:-}}"
    if [[ -z "$CONFIG_BASE" ]]; then
      echo "Error: neither XDG_CONFIG_HOME nor HOME is set." >&2
      exit 1
    fi
    if [[ -z "${XDG_CONFIG_HOME:-}" ]]; then
      CONFIG_BASE="$CONFIG_BASE/.config"
    fi
    CONFIG_DIR="$CONFIG_BASE/nvim"
    ;;
esac

mkdir -p "$CONFIG_DIR"
CONFIG_DIR="$(cd "$CONFIG_DIR" && pwd -P)"

if [[ "$SCRIPT_DIR" == "$CONFIG_DIR" ]]; then
  echo "This configuration is already in the Neovim config directory:"
  echo "  $CONFIG_DIR"
  exit 0
fi

case "$SCRIPT_DIR/" in
  "$CONFIG_DIR/"*)
    echo "Error: the project directory is inside the Neovim config directory." >&2
    exit 1
    ;;
esac
case "$CONFIG_DIR/" in
  "$SCRIPT_DIR/"*)
    echo "Error: the Neovim config directory is inside the project directory." >&2
    exit 1
    ;;
esac

if [[ -n "$(find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  BACKUP_DIR="${CONFIG_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
  if [[ -e "$BACKUP_DIR" ]]; then
    BACKUP_DIR="${BACKUP_DIR}-$$"
  fi
  cp -R "$CONFIG_DIR" "$BACKUP_DIR"
  echo "Existing configuration backed up to:"
  echo "  $BACKUP_DIR"
fi

cp -R "$SCRIPT_DIR"/. "$CONFIG_DIR"/

echo "EasyVim configuration installed to:"
echo "  $CONFIG_DIR"
echo "Start Neovim to let lazy.nvim install the plugins."
