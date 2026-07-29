# Local ZMK Build Notes

This repo is now prepared for local builds without using GitHub Actions.
The helper script is `scripts/zmk-local-build.sh`.

## Current Local State

- Zephyr SDK path: `/home/user/.opt/zephyr-sdk-0.17.4`
- Board target: `xiao_ble/nrf52840/zmk`
- Shields: `totem_left`, `totem_right`
- ZMK config directory: `config`
- Manifest: `config/west.yml`
- Zephyr base: `zephyr`

The manifest currently tracks `zmk` revision `main`. That is convenient but
not reproducible. If a future ZMK/Zephyr change breaks the build, pin
`config/west.yml` to a known-good ZMK commit or release branch before running
`west update`.

The script exports `ZEPHYR_BASE` and passes `Zephyr_DIR` directly to CMake.
This avoids the common local-build failure where CMake cannot find
`ZephyrConfig.cmake` even though `west update` has already fetched Zephyr.

## Offline-Safe Check

This does not fetch dependencies:

```sh
./scripts/zmk-local-build.sh --check-only
```

If `zmk/app/CMakeLists.txt` is missing, the dependencies have not been fetched
yet.

## Later, With Better Connectivity

Fetch ZMK and its Zephyr/module dependencies:

```sh
./scripts/zmk-local-build.sh --update --check-only
```

Install Python requirements. This can use your pip cache, but may still need
network:

```sh
./scripts/zmk-local-build.sh --python-deps --check-only
```

Build both halves:

```sh
./scripts/zmk-local-build.sh
```

Build only one half:

```sh
./scripts/zmk-local-build.sh --left
./scripts/zmk-local-build.sh --right
```

The UF2 files are copied to `firmware/`:

```text
firmware/totem_left-xiao_ble_nrf52840_zmk-zmk.uf2
firmware/totem_right-xiao_ble_nrf52840_zmk-zmk.uf2
```

## If `xiao_ble` Fails

Recent ZMK's Seeed XIAO BLE ZMK board variant is `xiao_ble/nrf52840/zmk`.
That variant enables the ZMK defaults for USB, BLE, UF2 output, flash, NVS, and
settings. Building plain `xiao_ble` can produce suspiciously small firmware
because those ZMK defaults are missing.

GitHub Actions reads `build.yaml`, not the local helper script. Keep the board
entries there on `xiao_ble/nrf52840/zmk` as well; otherwise the reusable ZMK
workflow will either build incomplete firmware or fail its explicit ZMK compat
check.

Older configs sometimes refer to `seeeduino_xiao_ble`. If the build says the
board is unknown, try:

```sh
BOARD=seeeduino_xiao_ble ./scripts/zmk-local-build.sh
```

or:

```sh
./scripts/zmk-local-build.sh --board seeeduino_xiao_ble
```

## If ZMK `main` Breaks

Do not keep rebuilding against a moving `main` if it starts failing. Pin this
block in `config/west.yml`:

```yaml
  projects:
    - name: zmk
      remote: zmkfirmware
      revision: <known-good-zmk-commit-or-branch>
      import: app/west.yml
```

Then run:

```sh
./scripts/zmk-local-build.sh --update --check-only
./scripts/zmk-local-build.sh
```

## Notes

- The script exports `ZEPHYR_SDK_INSTALL_DIR=/home/user/.opt/zephyr-sdk-0.17.4`
  and `ZEPHYR_TOOLCHAIN_VARIANT=zephyr`.
- `config/totem.conf` selects `CONFIG_NEWLIB_LIBC=y`. With the current pulled
  ZMK/Zephyr tree (`zephyr` reports 4.1.0) and Zephyr SDK 0.17.4, the default
  toolchain Picolibc path fails while compiling `zephyr/lib/libc/picolibc/locks.c`
  because of a lock symbol type conflict. Newlib is provided by the same SDK and
  builds successfully here.
- Build outputs are ignored by git: `.west/`, `zmk/`, `zephyr/`, `modules/`,
  `tools/`, `build/`, `firmware/`, and `.venv-zmk/`.
- Your root `config/totem.keymap` is the active user keymap for local ZMK
  builds. The shield-local `config/boards/shields/totem/totem.keymap` appears
  to be an older/default keymap.
