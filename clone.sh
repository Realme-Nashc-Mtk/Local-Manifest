#!/bin/bash
set -e

if [ -t 1 ]; then
  COLOR_RESET='\033[0m'
  COLOR_RED='\033[0;31m'
  COLOR_GREEN='\033[0;32m'
  COLOR_YELLOW='\033[0;33m'
  COLOR_BLUE='\033[0;34m'
  COLOR_BOLD='\033[1m'
else
  COLOR_RESET=''
  COLOR_RED=''
  COLOR_GREEN=''
  COLOR_YELLOW=''
  COLOR_BLUE=''
  COLOR_BOLD=''
fi

declare -A REPOS=(
    ["device/mediatek/sepolicy_vndr"]="https://github.com/Realme-Nashc-Mtk/android_device_mediatek_sepolicy_vndr.git"
    ["device/realme/nashc"]="https://github.com/Realme-Nashc-Mtk/android_device_realme_nashc.git"
    ["vendor/realme/nashc"]="https://gitlab.com/realme-nashc-mtk/android_vendor_realme_nashc.git"
    ["kernel/realme/nashc"]="https://github.com/Realme-Nashc-Mtk/android_kernel_realme_nashc.git"
    ["hardware/oplus"]="https://github.com/Realme-Nashc-Mtk/android_hardware_oplus.git"
    ["hardware/mediatek"]="https://github.com/Realme-Nashc-Mtk/android_hardware_mediatek.git"
)

declare -A BRANCHES=(
    ["device/mediatek/sepolicy_vndr"]="15.0"
    ["device/realme/nashc"]="15.0"
    ["vendor/realme/nashc"]="15.0"
    ["kernel/realme/nashc"]="15.0"
    ["hardware/oplus"]="15.0"
    ["hardware/mediatek"]="15.0"
)

_print_message() {
  local color="$1"
  local prefix="$2"
  local message="$3"
  echo -e "${color}${prefix}${COLOR_RESET} ${message}"
}

info() {
  _print_message "$COLOR_BLUE" "[INFO]" "$1"
}

success() {
  _print_message "$COLOR_GREEN" "[SUCCESS]" "$1"
}

warn() {
  _print_message "$COLOR_YELLOW" "[WARNING]" "$1"
}

error() {
  _print_message "$COLOR_RED" "[ERROR]" "$1" >&2
  exit 1
}

check_dependencies() {
    info "Checking for required tools..."
    local missing_tools=0

    if ! command -v git &> /dev/null; then
        error "Dependency missing: 'git' is not installed or not in PATH. Please install git."
        missing_tools=1
    else
        success "'git' found: $(command -v git)"
    fi

    if ! command -v git-lfs &> /dev/null; then
        error "Dependency missing: 'git-lfs' is not installed or not in PATH."
        echo -e "${COLOR_RED}Please install git-lfs using your system's package manager:${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}  - Debian/Ubuntu: sudo apt update && sudo apt install git-lfs${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}  - Fedora:        sudo dnf install git-lfs${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}  - macOS (Homebrew): brew install git-lfs${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}After installation, you might need to run 'git lfs install' or 'git lfs install --system'.${COLOR_RESET}" >&2
        missing_tools=1
    else
        success "'git-lfs' found: $(command -v git-lfs)"
    fi

    if [ "$missing_tools" -ne 0 ]; then
        exit 1
    fi
    info "All required tools found."
}

ORIGINAL_DIR=$(pwd)

check_dependencies
echo

info "--- ${COLOR_BOLD}Phase 1: Cleaning up previous source directories${COLOR_RESET} ---"
for dir in "${!REPOS[@]}"; do
    if [ -d "$dir" ]; then
        info "Removing ${COLOR_BOLD}${dir}${COLOR_RESET}..."
        if ! rm -rf "$dir"; then
            error "Failed to remove $dir. Check permissions or locks."
        fi
    fi
done
success "Cleanup phase complete."
echo

info "--- ${COLOR_BOLD}Phase 2: Cloning required repositories${COLOR_RESET} ---"
for dir in "${!REPOS[@]}"; do
    repo_url=${REPOS[$dir]}
    branch=${BRANCHES[$dir]}
    info "Cloning ${COLOR_BOLD}$branch${COLOR_RESET} from ${COLOR_BLUE}$repo_url${COLOR_RESET} into ${COLOR_BOLD}$dir${COLOR_RESET}..."
    mkdir -p "$(dirname "$dir")"
    if ! git clone --progress "$repo_url" -b "$branch" "$dir" >/dev/null; then
        error "Failed to clone $repo_url into $dir. Check URL, permissions, and network."
    fi
done
success "Cloning phase complete."
exit 0
