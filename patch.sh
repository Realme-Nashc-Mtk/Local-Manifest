#!/bin/bash
set -e

# Gatekeeper Aidl
cd hardware/lineage/interfaces
curl https://raw.githubusercontent.com/Realme-Nashc-Mtk/Local-Manifest/refs/heads/15.0/patches/gatekeeper-aidl.patch > gatekeeper-aidl.patch
git apply gatekeeper-aidl.patch
rm -rf gatekeeper-aidl.patch
cd ../../../


# Gatekeeper Sepolicy
cd device/lineage/sepolicy
curl https://raw.githubusercontent.com/Realme-Nashc-Mtk/Local-Manifest/refs/heads/15.0/patches/gatekeeper-sepolicy.patch > gatekeeper-sepolicy.patch
git apply gatekeeper-sepolicy.patch
rm -rf gatekeeper-sepolicy.patch
cd ../../../
