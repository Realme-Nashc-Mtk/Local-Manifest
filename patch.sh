#!/bin/bash

# Define variables (as in the improved script)
LINEAGE_INTERFACES="hardware/lineage/interfaces"
LINEAGE_SEPOLICY="device/lineage/sepolicy"
PATCH_URL_AIDL="https://raw.githubusercontent.com/Realme-Nashc-Mtk/Local-Manifest/refs/heads/15.0/patches/gatekeeper-aidl.patch"
PATCH_URL_SEPOLICY="https://raw.githubusercontent.com/Realme-Nashc-Mtk/Local-Manifest/refs/heads/15.0/patches/gatekeeper-sepolicy.patch"
PATCH_FILE_AIDL="gatekeeper-aidl.patch"
PATCH_FILE_SEPOLICY="gatekeeper-sepolicy.patch"

apply_patch() {
  local target_dir="$1"
  local patch_url="$2"
  local patch_file="$3"

  echo "Applying patch from: $patch_url to $target_dir"
  cd "$target_dir" || {
    echo "Error: Could not change directory to $target_dir"
    return 1
  }

  curl -o "$patch_file" "$patch_url"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download patch from $patch_url"
    cd - > /dev/null
    return 1
  fi

  git apply "$patch_file"
  local apply_status=$? # Capture the exit code
  rm -f "$patch_file"
  cd - > /dev/null

  if [ $apply_status -ne 0 ]; then
    echo "Error: Failed to apply patch $patch_file in $target_dir"
    return 1 # Indicate failure of this specific patch application
  else
    echo "Successfully applied patch to $target_dir."
    return 0 # Indicate success
  fi
}

# Apply Gatekeeper AIDL patch
if ! apply_patch "$LINEAGE_INTERFACES" "$PATCH_URL_AIDL" "$PATCH_FILE_AIDL"; then
  echo "Warning: Failed to apply Gatekeeper AIDL patch. Continuing anyway..."
fi

# Apply Gatekeeper Sepolicy patch
apply_patch "$LINEAGE_SEPOLICY" "$PATCH_URL_SEPOLICY" "$PATCH_FILE_SEPOLICY"

echo "Script finished."
