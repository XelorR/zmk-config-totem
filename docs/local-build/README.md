# Local ZMK Build Notes

This repo is now prepared for local builds without using GitHub Actions.
The helper script is `scripts/zmk-local-build.sh`.

## Current Local State

- Zephyr SDK path: `/home/user/.opt/zephyr-sdk-0.17.4`
- Board target: `xiao_ble`
- Shields: `totem_left`, `totem_right`
- ZMK config directory: `config`
- Manifest: `config/west.yml`

The manifest currently tracks `zmk` revision `main`. That is convenient but
not reproducible. If a future ZMK/Zephyr change breaks the build, pin
`config/west.yml` to a known-good ZMK commit or release branch before running
`west update`.

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
firmware/totem_left-xiao_ble-zmk.uf2
firmware/totem_right-xiao_ble-zmk.uf2
```

## If `xiao_ble` Fails

Recent ZMK normally uses `xiao_ble` for Seeed XIAO BLE. Older configs sometimes
refer to `seeeduino_xiao_ble`. If the build says the board is unknown, try:

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
- Build outputs are ignored by git: `.west/`, `zmk/`, `zephyr/`, `modules/`,
  `tools/`, `build/`, `firmware/`, and `.venv-zmk/`.
- Your root `config/totem.keymap` is the active user keymap for local ZMK
  builds. The shield-local `config/boards/shields/totem/totem.keymap` appears
  to be an older/default keymap.

