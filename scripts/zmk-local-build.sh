#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="${ZEPHYR_SDK_INSTALL_DIR:-/home/user/.opt/zephyr-sdk-0.17.4}"
BOARD="${BOARD:-xiao_ble}"
CONFIG_DIR="${ZMK_CONFIG:-$ROOT_DIR/config}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
FIRMWARE_DIR="${FIRMWARE_DIR:-$ROOT_DIR/firmware}"
SIDES=("left" "right")
DO_UPDATE=0
DO_PY_DEPS=0
DO_BUILD=1
PRISTINE=auto

usage() {
  cat <<EOF
Usage: $0 [options]

Offline by default. It checks the local ZMK workspace and builds only if the
dependencies already exist.

Options:
  --check-only         Check tools and workspace, then exit.
  --update            Run west update. This needs network; use later.
  --python-deps       Install Python deps from zmk/app/requirements.txt.
                      This may need network unless your pip cache is warm.
  --left              Build only the left half.
  --right             Build only the right half.
  --board NAME        Override board target. Default: xiao_ble.
  --sdk PATH          Override Zephyr SDK path.
  --pristine MODE     west pristine mode: auto, always, never. Default: auto.
  -h, --help          Show this help.

Useful environment overrides:
  ZEPHYR_SDK_INSTALL_DIR, BOARD, ZMK_CONFIG, BUILD_ROOT, FIRMWARE_DIR
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      DO_BUILD=0
      shift
      ;;
    --update)
      DO_UPDATE=1
      shift
      ;;
    --python-deps)
      DO_PY_DEPS=1
      shift
      ;;
    --left)
      SIDES=("left")
      shift
      ;;
    --right)
      SIDES=("right")
      shift
      ;;
    --board)
      BOARD="$2"
      shift 2
      ;;
    --sdk)
      SDK_DIR="$2"
      shift 2
      ;;
    --pristine)
      PRISTINE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    return 1
  fi
}

echo "Repo:      $ROOT_DIR"
echo "Config:    $CONFIG_DIR"
echo "SDK:       $SDK_DIR"
echo "Board:     $BOARD"

need_cmd west
need_cmd cmake
need_cmd ninja
need_cmd python3

if [[ ! -d "$SDK_DIR" ]]; then
  echo "Zephyr SDK directory does not exist: $SDK_DIR" >&2
  exit 1
fi

export ZEPHYR_SDK_INSTALL_DIR="$SDK_DIR"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr

if [[ ! -d "$ROOT_DIR/.west" ]]; then
  echo "Initializing west workspace from local manifest..."
  (cd "$ROOT_DIR" && west init -l "$CONFIG_DIR")
fi

if [[ "$DO_UPDATE" -eq 1 ]]; then
  echo "Running west update. This can download several repositories."
  (cd "$ROOT_DIR" && west update)
fi

if [[ ! -f "$ROOT_DIR/zmk/app/CMakeLists.txt" ]]; then
  cat >&2 <<EOF
ZMK sources are not present yet.

This script did not fetch anything because it is offline by default.
When you have a better connection, run:

  $0 --update --check-only

Then optionally install Python deps:

  $0 --python-deps --check-only

After that, build with:

  $0
EOF
  exit 1
fi

if [[ "$DO_PY_DEPS" -eq 1 ]]; then
  echo "Installing ZMK Python requirements into .venv-zmk..."
  python3 -m venv "$ROOT_DIR/.venv-zmk"
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.venv-zmk/bin/activate"
  python -m pip install --upgrade pip
  python -m pip install -r "$ROOT_DIR/zmk/app/requirements.txt"
elif [[ -d "$ROOT_DIR/.venv-zmk" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.venv-zmk/bin/activate"
fi

if [[ "$DO_BUILD" -eq 0 ]]; then
  echo "Check complete."
  exit 0
fi

mkdir -p "$FIRMWARE_DIR"

for side in "${SIDES[@]}"; do
  shield="totem_${side}"
  build_dir="$BUILD_ROOT/$shield"
  echo "Building $shield..."
  (cd "$ROOT_DIR" && west build \
    -s "$ROOT_DIR/zmk/app" \
    -d "$build_dir" \
    -b "$BOARD" \
    -p "$PRISTINE" \
    -- \
    -DSHIELD="$shield" \
    -DZMK_CONFIG="$CONFIG_DIR")

  uf2="$build_dir/zephyr/zmk.uf2"
  if [[ -f "$uf2" ]]; then
    cp "$uf2" "$FIRMWARE_DIR/${shield}-${BOARD}-zmk.uf2"
    echo "Wrote $FIRMWARE_DIR/${shield}-${BOARD}-zmk.uf2"
  else
    echo "Build completed, but UF2 was not found at $uf2" >&2
    exit 1
  fi
done

