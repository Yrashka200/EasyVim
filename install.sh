#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
TOTAL_STEPS=5
COMPLETED_STEPS=0
START_TIME="$(date +%s)"
PLATFORM=""
PACKAGE_MANAGER=""
CONFIG_DIR=""

usage() {
  cat <<'EOF'
Usage: bash install.sh [--yes]

Install the EasyVim configuration. Missing system requirements are detected
and, when a supported package manager is available, can be installed for you.

Options:
  --yes   Install missing requirements without prompting.
  -h, --help
EOF
}

for argument in "$@"; do
  case "$argument" in
    --yes) YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $argument" >&2; usage >&2; exit 2 ;;
  esac
done
YES="${YES:-0}"

format_duration() {
  local seconds="$1"
  local minutes=$((seconds / 60))
  local remaining_seconds=$((seconds % 60))
  if (( minutes > 0 )); then
    printf '%dm %02ds' "$minutes" "$remaining_seconds"
  else
    printf '%ds' "$remaining_seconds"
  fi
}

report_progress() {
  local now elapsed average remaining eta
  now="$(date +%s)"
  elapsed=$((now - START_TIME))
  if (( COMPLETED_STEPS == 0 )); then
    eta="calculating"
  else
    average=$((elapsed / COMPLETED_STEPS))
    remaining=$((average * (TOTAL_STEPS - COMPLETED_STEPS)))
    eta="$(format_duration "$remaining")"
  fi
  printf '[%3d%%] %s | elapsed %s | remaining ~%s\n' \
    "$((COMPLETED_STEPS * 100 / TOTAL_STEPS))" "$1" \
    "$(format_duration "$elapsed")" "$eta"
}

complete_step() {
  COMPLETED_STEPS=$((COMPLETED_STEPS + 1))
  report_progress "$1"
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

detect_platform() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      PLATFORM="windows"
      if ! command -v cygpath >/dev/null 2>&1; then
        fail "cygpath is required. Run this script from Git Bash or Cygwin."
      fi
      if command -v winget >/dev/null 2>&1; then
        PACKAGE_MANAGER="winget"
      elif command -v choco >/dev/null 2>&1; then
        PACKAGE_MANAGER="choco"
      elif command -v scoop >/dev/null 2>&1; then
        PACKAGE_MANAGER="scoop"
      fi
      ;;
    Darwin)
      PLATFORM="macos"
      command -v brew >/dev/null 2>&1 && PACKAGE_MANAGER="brew"
      ;;
    Linux)
      PLATFORM="linux"
      if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
      elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
      elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER="pacman"
      elif command -v zypper >/dev/null 2>&1; then
        PACKAGE_MANAGER="zypper"
      fi
      ;;
    *)
      fail "Unsupported operating system: $(uname -s)"
      ;;
  esac
}

config_path() {
  if [[ "$PLATFORM" == "windows" ]]; then
    if [[ -n "${LOCALAPPDATA:-}" ]]; then
      CONFIG_DIR="$(cygpath -u "$LOCALAPPDATA")/nvim"
    elif [[ -n "${USERPROFILE:-}" ]]; then
      CONFIG_DIR="$(cygpath -u "$USERPROFILE")/AppData/Local/nvim"
    else
      fail "Could not determine the Windows local application data directory."
    fi
  else
    local config_base="${XDG_CONFIG_HOME:-${HOME:-}}"
    [[ -n "$config_base" ]] || fail "Neither XDG_CONFIG_HOME nor HOME is set."
    if [[ -z "${XDG_CONFIG_HOME:-}" ]]; then
      config_base="$config_base/.config"
    fi
    CONFIG_DIR="$config_base/nvim"
  fi
}

missing_requirements() {
  local missing=()
  local nvim_version nvim_major nvim_minor

  if ! command -v nvim >/dev/null 2>&1; then
    missing+=(nvim)
  else
    nvim_version="$(nvim --version | sed -n '1s/^[^0-9]*\([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1 \2/p')"
    if [[ -z "$nvim_version" ]]; then
      missing+=(nvim)
    else
      read -r nvim_major nvim_minor <<< "$nvim_version"
      if (( nvim_major == 0 && nvim_minor < 11 )); then
        missing+=(nvim)
      fi
    fi
  fi

  for tool in git curl; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    missing+=(nodejs)
  fi
  printf '%s\n' "${missing[@]}"
}

install_requirements() {
  local packages=("$@")
  local package

  case "$PLATFORM:$PACKAGE_MANAGER" in
    windows:winget)
      for package in "${packages[@]}"; do
        case "$package" in
          nvim) winget install --id "Neovim.Neovim" --exact --silent --accept-package-agreements --accept-source-agreements ;;
          git) winget install --id "Git.Git" --exact --silent --accept-package-agreements --accept-source-agreements ;;
          curl) winget install --id "cURL.cURL" --exact --silent --accept-package-agreements --accept-source-agreements ;;
          nodejs) winget install --id "OpenJS.NodeJS.LTS" --exact --silent --accept-package-agreements --accept-source-agreements ;;
          ripgrep) winget install --id "BurntSushi.ripgrep.MSVC" --exact --silent --accept-package-agreements --accept-source-agreements ;;
        esac
      done
      ;;
    windows:choco)
      local ids=()
      for package in "${packages[@]}"; do
        case "$package" in
          nvim) ids+=(neovim) ;;
          git) ids+=(git) ;;
          curl) ids+=(curl) ;;
          nodejs) ids+=(nodejs-lts) ;;
          ripgrep) ids+=(ripgrep) ;;
        esac
      done
      choco install --yes "${ids[@]}"
      ;;
    windows:scoop)
      local ids=()
      for package in "${packages[@]}"; do
        case "$package" in
          nvim) ids+=(neovim) ;;
          git) ids+=(git) ;;
          curl) ids+=(curl) ;;
          nodejs) ids+=(nodejs) ;;
          ripgrep) ids+=(ripgrep) ;;
        esac
      done
      scoop install "${ids[@]}"
      ;;
    macos:brew)
      local ids=()
      for package in "${packages[@]}"; do
        case "$package" in
          nvim) ids+=(neovim) ;;
          git) ids+=(git) ;;
          curl) ids+=(curl) ;;
          nodejs) ids+=(node) ;;
          ripgrep) ids+=(ripgrep) ;;
        esac
      done
      brew install "${ids[@]}"
      ;;
    linux:apt)
      local ids=()
      for package in "${packages[@]}"; do
        case "$package" in
          nvim) ids+=(neovim) ;;
          git) ids+=(git) ;;
          curl) ids+=(curl) ;;
          nodejs) ids+=(nodejs npm) ;;
          ripgrep) ids+=(ripgrep) ;;
        esac
      done
      if [[ "$(id -u)" -eq 0 ]]; then
        apt-get update
        apt-get install -y "${ids[@]}"
      else
        command -v sudo >/dev/null 2>&1 || fail "sudo is required to install system packages."
        sudo apt-get update
        sudo apt-get install -y "${ids[@]}"
      fi
      ;;
    linux:dnf)
      local ids=()
      for package in "${packages[@]}"; do
        case "$package" in
          nvim) ids+=(neovim) ;;
          git) ids+=(git) ;;
          curl) ids+=(curl) ;;
          nodejs) ids+=(nodejs npm) ;;
          ripgrep) ids+=(ripgrep) ;;
        esac
      done
      if [[ "$(id -u)" -eq 0 ]]; then
        dnf install -y "${ids[@]}"
      else
        command -v sudo >/dev/null 2>&1 || fail "sudo is required to install system packages."
        sudo dnf install -y "${ids[@]}"
      fi
      ;;
    linux:pacman)
      local ids=()
      for package in "${packages[@]}"; do
        case "$package" in
          nvim) ids+=(neovim) ;;
          git) ids+=(git) ;;
          curl) ids+=(curl) ;;
          nodejs) ids+=(nodejs npm) ;;
          ripgrep) ids+=(ripgrep) ;;
        esac
      done
      if [[ "$(id -u)" -eq 0 ]]; then
        pacman -S --needed --noconfirm "${ids[@]}"
      else
        command -v sudo >/dev/null 2>&1 || fail "sudo is required to install system packages."
        sudo pacman -S --needed --noconfirm "${ids[@]}"
      fi
      ;;
    linux:zypper)
      local ids=()
      for package in "${packages[@]}"; do
        case "$package" in
          nvim) ids+=(neovim) ;;
          git) ids+=(git) ;;
          curl) ids+=(curl) ;;
          nodejs) ids+=(nodejs npm) ;;
          ripgrep) ids+=(ripgrep) ;;
        esac
      done
      if [[ "$(id -u)" -eq 0 ]]; then
        zypper --non-interactive install "${ids[@]}"
      else
        command -v sudo >/dev/null 2>&1 || fail "sudo is required to install system packages."
        sudo zypper --non-interactive install "${ids[@]}"
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ ! -f "$SCRIPT_DIR/init.lua" ]]; then
  fail "init.lua was not found next to this installer."
fi

report_progress "Starting EasyVim installation"
detect_platform
config_path
missing=()
while IFS= read -r tool; do
  [[ -n "$tool" ]] && missing+=("$tool")
done < <(missing_requirements)
complete_step "Detected $PLATFORM; checked system requirements"

if ! command -v rg >/dev/null 2>&1; then
  echo "Optional: ripgrep is not installed. Telescope live text search (Space f g) will be unavailable."
fi

if (( ${#missing[@]} > 0 )); then
  printf 'Missing or outdated requirements: %s\n' "${missing[*]}"
  if [[ -z "$PACKAGE_MANAGER" ]]; then
    fail "No supported package manager was found. Install Neovim 0.11+, Git, curl, and Node.js/npm, then rerun this script."
  fi
  if [[ "$YES" -eq 1 ]]; then
    answer="y"
  else
    read -r -p "Install them using $PACKAGE_MANAGER? [y/N] " answer || answer="n"
  fi
  case "$answer" in
    y|Y|yes|YES)
      install_requirements "${missing[@]}" &
      install_pid=$!
      while kill -0 "$install_pid" 2>/dev/null; do
        sleep 5
        if kill -0 "$install_pid" 2>/dev/null; then
          report_progress "Installing system requirements"
        fi
      done
      if ! wait "$install_pid"; then
        fail "Dependency installation failed."
      fi
      ;;
    *)
      fail "Install the missing requirements and rerun this script."
      ;;
  esac
  missing=()
  while IFS= read -r tool; do
    [[ -n "$tool" ]] && missing+=("$tool")
  done < <(missing_requirements)
  if (( ${#missing[@]} > 0 )); then
    fail "Requirements still missing or outdated: ${missing[*]}. Open a new terminal if a newly installed command is not on PATH."
  fi
fi
complete_step "System requirements are ready"

CONFIG_PRESENT=0
if [[ -d "$CONFIG_DIR" ]] && [[ -n "$(find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  CONFIG_PRESENT=1
fi

mkdir -p "$CONFIG_DIR"
CONFIG_DIR="$(cd "$CONFIG_DIR" && pwd -P)"

if [[ "$SCRIPT_DIR" == "$CONFIG_DIR" ]]; then
  complete_step "Configuration is already installed"
  complete_step "No backup needed"
  complete_step "Installation verified"
  echo "Neovim configuration already exists at: $CONFIG_DIR"
  echo "EasyVim is already installed at this path."
  exit 0
fi

if [[ "$CONFIG_PRESENT" -eq 1 ]]; then
  echo "Neovim configuration already exists at: $CONFIG_DIR"
  echo "It will be backed up before EasyVim is installed."
else
  echo "No Neovim configuration was found at: $CONFIG_DIR"
  echo "Installing EasyVim there now."
fi

case "$SCRIPT_DIR/" in
  "$CONFIG_DIR/"*)
    fail "The project directory is inside the Neovim config directory."
    ;;
esac
case "$CONFIG_DIR/" in
  "$SCRIPT_DIR/"*)
    fail "The Neovim config directory is inside the project directory."
    ;;
esac
complete_step "Prepared configuration directory"

if [[ "$CONFIG_PRESENT" -eq 1 ]]; then
  BACKUP_DIR="${CONFIG_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
  if [[ -e "$BACKUP_DIR" ]]; then
    BACKUP_DIR="${BACKUP_DIR}-$$"
  fi
  cp -R "$CONFIG_DIR" "$BACKUP_DIR"
  echo "Existing configuration backed up to: $BACKUP_DIR"
else
  echo "No existing configuration files needed a backup."
fi
complete_step "Backed up existing configuration (if present)"

cp -R "$SCRIPT_DIR"/. "$CONFIG_DIR"/
[[ -f "$CONFIG_DIR/init.lua" ]] || fail "Installation verification failed: init.lua is missing."
complete_step "Copied and verified EasyVim configuration"
echo "EasyVim configuration installed to: $CONFIG_DIR"
echo "Start Neovim; plugins and language servers are installed on first launch."

