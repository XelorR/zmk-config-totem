#!/bin/bash

# Building Totem for Xiao BLE

set -e # stop on error

# Paths
PROJECT_DIR="$HOME/Documents/zmk-config-totem"
DOWNLOADS_DIR="$HOME/Downloads"
ZEPHYR_SDK="$HOME/.opt/zephyr-sdk-0.17.4"

# File Names
LEFT_FIRMWARE="totem_left-xiao_ble-zmk_local-build.uf2"
RIGHT_FIRMWARE="totem_right-xiao_ble-zmk_local-build.uf2"

echo "=== Building Totem Firmware ==="

cd "$PROJECT_DIR"

# Old builds cleanup
echo "Old builds cleanup..."
rm -rf build-left build-right

# Environment setup
export ZEPHYR_BASE="$PWD/zephyr"
export ZEPHYR_SDK_INSTALL_DIR="$ZEPHYR_SDK"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr

# Registering Zephyr in CMake
echo "Registering Zephyr..."
west zephyr-export

# Left half built
echo ""
echo ">>> Building left half..."
west build -p -b xiao_ble -d build-left -s zmk/app -- -DSHIELD=totem_left -DZMK_CONFIG="$PWD/config"

# Right half build
echo ""
echo ">>> Building right half..."
west build -p -b xiao_ble -d build-right -s zmk/app -- -DSHIELD=totem_right -DZMK_CONFIG="$PWD/config"

# Copy artefacts into Downloads folder
echo ""
echo ">>> Copying files into Downloads folder..."

cp "build-left/zephyr/zmk.uf2" "$DOWNLOADS_DIR/$LEFT_FIRMWARE"
echo "✓ Left: $DOWNLOADS_DIR/$LEFT_FIRMWARE"

cp "build-right/zephyr/zmk.uf2" "$DOWNLOADS_DIR/$RIGHT_FIRMWARE"
echo "✓ Right: $DOWNLOADS_DIR/$RIGHT_FIRMWARE"

echo ""
echo "=== Done! ==="
echo "Firmware saved into ~/Downloads/"
