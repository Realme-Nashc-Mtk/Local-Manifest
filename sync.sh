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
    ["device/mediatek/sepolicy_vndr"]="https://bitbucket.org/mldklr/android_device_mediatek_sepolicy_vndr.git"
    ["device/realme/nashc"]="https://github.com/Realme-Nashc-Mtk/android_device_realme_nashc.git"
    ["vendor/realme/nashc"]="https://bitbucket.org/mldklr/android_vendor_realme_nashc.git"
    ["kernel/realme/nashc"]="https://github.com/Realme-Nashc-Mtk/android_kernel_realme_nashc.git"
    ["hardware/oplus"]="https://bitbucket.org/mldklr/android_hardware_oplus.git"
    ["hardware/mediatek"]="https://bitbucket.org/mldklr/android_hardware_mediatek.git"
)

declare -A BRANCHES=(
    ["device/mediatek/sepolicy_vndr"]="lineage-22.2"
    ["device/realme/nashc"]="15.0"
    ["vendor/realme/nashc"]="lineage-22.2"
    ["kernel/realme/nashc"]="15.0"
    ["hardware/oplus"]="lineage-22.2"
    ["hardware/mediatek"]="lineage-22.2"
)

INTERFACES_DIR="hardware/lineage/interfaces"
INTERFACES_REMOTE_URL="https://github.com/Realme-Nashc-Mtk/android_hardware_lineage_interfaces.git"
INTERFACES_REMOTE_NAME="bit"
INTERFACES_CHERRY_PICK_1="2fd7d19adc428aa14b6670f96fef12001049bc21"
INTERFACES_CHERRY_PICK_2="96635874650f5d1970b9f12f822fad354aaa7d40"
INTERFACES_CHECK_COMMIT_URL="https://bitbucket.org/mldklr/android_hardware_lineage_interfaces/commits/$INTERFACES_CHERRY_PICK_2"

SEPOLICY_DIR="device/lineage/sepolicy"
SEPOLICY_REMOTE_URL="https://bitbucket.org/mldklr/android_device_lineage_sepolicy.git"
SEPOLICY_REMOTE_NAME="bit"
SEPOLICY_CHERRY_PICK="de019b2490f664bda8283e8acd874615af4620fe"

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

ask_yes_no() {
    local prompt_text="$1"
    local prompt="${COLOR_YELLOW}[PROMPT]${COLOR_RESET} ${prompt_text} [y/N]: "
    local response
    while true; do
        read -p "$(echo -e "$prompt")" response
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
        if [[ "$response" == "y" || "$response" == "yes" ]]; then
            return 0
        elif [[ "$response" == "n" || "$response" == "no" || -z "$response" ]]; then
            return 1
        else
            warn "Please answer 'y' (yes) or 'n' (no)."
        fi
    done
}

handle_cherry_pick() {
    local commit_hash="$1"
    local repo_dir_rel="$2"
    local repo_dir_abs=$(cd "$repo_dir_rel" && pwd)

    info "Attempting cherry-pick: ${COLOR_BOLD}${commit_hash}${COLOR_RESET} in ${COLOR_BOLD}$(basename "$repo_dir_rel")${COLOR_RESET}..."
    if git cherry-pick "$commit_hash"; then
        success "Cherry-pick successful."
    else
        local status_output
        status_output=$(git status --short 2>&1)

        warn "Cherry-pick failed for commit ${COLOR_BOLD}${commit_hash}${COLOR_RESET}. This might be due to conflicts."
        warn "Please resolve the conflicts manually in the directory:"
        echo -e "${COLOR_YELLOW}  cd \"$repo_dir_abs\"${COLOR_RESET}"
        warn "Steps:"
        echo -e "${COLOR_YELLOW}  1. View conflicts: git status${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}     Current status:\n${status_output}${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}  2. Edit conflicted files to resolve issues.${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}  3. Stage resolved files: git add <file1> <file2> ...${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}  4. Continue the cherry-pick: git cherry-pick --continue${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}     (Or abort with: git cherry-pick --abort)${COLOR_RESET}"
        warn "---"
        read -p "$(echo -e "${COLOR_YELLOW}[ACTION REQUIRED]${COLOR_RESET} Press [Enter] here AFTER resolving conflicts and running 'git cherry-pick --continue'...")"
        info "Resuming script execution..."
        if git status --short | grep -q -E "^(UU|AA|DD|AU|UA|UD|DU)"; then
            warn "Unmerged paths might still exist. Please ensure conflicts are fully resolved."
            read -p "$(echo -e "${COLOR_YELLOW}[CONFIRM]${COLOR_RESET} Press [Enter] to continue anyway, or Ctrl+C to abort...")"
        else
            success "Continuing after potential conflict resolution."
        fi
    fi
}

add_remote_if_missing() {
    local remote_name="$1"
    local remote_url="$2"
    local remote_added=0
    if ! git remote get-url "$remote_name" &> /dev/null; then
        info "Adding remote '${COLOR_BOLD}${remote_name}${COLOR_RESET}'..."
        git remote add "$remote_name" "$remote_url"
        remote_added=1
    else
        local existing_url
        existing_url=$(git remote get-url "$remote_name")
        if [[ "$existing_url" != "$remote_url" ]]; then
            warn "Remote '${COLOR_BOLD}${remote_name}${COLOR_RESET}' exists but has a different URL ('$existing_url'). Updating to '$remote_url'."
            git remote set-url "$remote_name" "$remote_url"
            remote_added=1
        fi
    fi
    info "Fetching from remote '${COLOR_BOLD}${remote_name}${COLOR_RESET}'..."
    git fetch "$remote_name"
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
echo

info "--- ${COLOR_BOLD}Phase 3: Applying optional patches${COLOR_RESET} ---"

if [ -d "$INTERFACES_DIR" ]; then
    if ask_yes_no "Patch '${COLOR_BOLD}$INTERFACES_DIR${COLOR_RESET}'?"; then
        info "Processing patches for '${COLOR_BOLD}$INTERFACES_DIR${COLOR_RESET}'..."
        pushd "$INTERFACES_DIR" > /dev/null

        add_remote_if_missing "$INTERFACES_REMOTE_NAME" "$INTERFACES_REMOTE_URL"
        handle_cherry_pick "$INTERFACES_CHERRY_PICK_1" "$INTERFACES_DIR"

        info "Checking presence of commit ${COLOR_BOLD}${INTERFACES_CHERRY_PICK_2:0:12}${COLOR_RESET}..."
        if git log --pretty=format:%H --grep="$INTERFACES_CHERRY_PICK_2" | grep -q "$INTERFACES_CHERRY_PICK_2"; then
            success "Commit ${COLOR_BOLD}${INTERFACES_CHERRY_PICK_2:0:12}${COLOR_RESET} already present."
        else
            info "Commit ${COLOR_BOLD}${INTERFACES_CHERRY_PICK_2:0:12}${COLOR_RESET} not found."
            if ask_yes_no "Cherry-pick commit ${COLOR_BOLD}${INTERFACES_CHERRY_PICK_2:0:12}${COLOR_RESET}?"; then
                handle_cherry_pick "$INTERFACES_CHERRY_PICK_2" "$INTERFACES_DIR"
            fi
        fi

        popd > /dev/null
        success "Finished processing for '${COLOR_BOLD}$INTERFACES_DIR${COLOR_RESET}'."
    fi
else
    warn "Directory '${COLOR_BOLD}$INTERFACES_DIR${COLOR_RESET}' not found. Cannot apply patches."
fi
echo

if [ -d "$SEPOLICY_DIR" ]; then
    if ask_yes_no "Patch '${COLOR_BOLD}$SEPOLICY_DIR${COLOR_RESET}'?"; then
        info "Processing patches for '${COLOR_BOLD}$SEPOLICY_DIR${COLOR_RESET}'..."
        pushd "$SEPOLICY_DIR" > /dev/null

        add_remote_if_missing "$SEPOLICY_REMOTE_NAME" "$SEPOLICY_REMOTE_URL"
        handle_cherry_pick "$SEPOLICY_CHERRY_PICK" "$SEPOLICY_DIR"

        popd > /dev/null
        success "Finished processing for '${COLOR_BOLD}$SEPOLICY_DIR${COLOR_RESET}'."
    fi
else
    warn "Directory '${COLOR_BOLD}$SEPOLICY_DIR${COLOR_RESET}' not found. Cannot apply patches."
fi
echo

success "${COLOR_BOLD}Script execution finished successfully.${COLOR_RESET}"
cd "$ORIGINAL_DIR"

exit 0
