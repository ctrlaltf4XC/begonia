# PitchBlack Recovery for Redmi Note 8 Pro (begonia)

Device tree for the Redmi Note 8 Pro (`begonia` / `begoniain`), MediaTek
Helio G90T (MT6785).

## Important: build the safe image first

PBRP draws its splash **before** it processes encrypted storage. The MicroTrust
FBE path calls `fscrypt_mount_metadata_encrypted()` during startup and can block
if the vendor keymaster/TEE service is unavailable. A build that merely hides
`libshim_beanpod` is not safe: the fstab, properties, init services, and HAL
modules must all be disabled together.

The default `safe` build therefore:

- sets `PBRP_ENABLE_CRYPTO=false` and `TW_INCLUDE_CRYPTO=false`;
- does not load the MicroTrust crypto properties or keymaster modules;
- does not start the beanpod services;
- uses `variants/recovery.fstab.safe`, which intentionally has no `/data` entry;
- disables the MTK startup blank/unblank operation; and
- does not modify or wipe user data.

Use this image to confirm that the recovery reaches its main menu. It is a
startup diagnostic image and cannot access encrypted `/data`.

## Build modes

| Mode | Variant | Crypto | Purpose |
|---|---|---:|---|
| `safe` | `safe` | no | Default splash-hang diagnosis; UI boot without touching `/data` |
| `static` | `static` | yes | By-name system/vendor layout with the explicit MicroTrust stack |
| `dynamic` | `dynamic` | yes | Retrofit-super layout; required for dynamic Android 11+ layouts |

The `dynamic` build applies a bounded wait to PBRP's logical-partition setup.
A missing mapper node is reported and skipped after 10 seconds instead of
looping forever. The crypto build also creates the MicroTrust shared-memory
layout during `init`, before `teei_daemon` can start.

## GitHub Actions

The workflow builds the default safe image on pushes to `main` and `dynamic`.
To choose a mode manually, run **Build PBRP for begonia** and select:

- `variant=safe`, `crypto=false` — recommended first test;
- `variant=static`, `crypto=true` — static crypto build; or
- `variant=dynamic`, `crypto=true` — retrofit-super crypto build.

Artifacts contain `recovery.img`, a flashable zip, and `BUILD_INFO.txt`.

## Local build

```bash
repo init -u https://github.com/PitchBlackRecoveryProject/manifest_pb \
    -b android-12.1 --depth=1
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags

# From the root of this repository:
mkdir -p device/xiaomi
cp -a pbrp_device_tree device/xiaomi/begonia

# Safe startup build (default)
export PBRP_VARIANT=safe
export PBRP_ENABLE_CRYPTO=false

# For a crypto build, use static or dynamic and set:
# export PBRP_VARIANT=static
# export PBRP_ENABLE_CRYPTO=true

cd device/xiaomi/begonia
if [ "$PBRP_ENABLE_CRYPTO" = true ]; then
    ./fetch-decryption-blobs.sh
fi
cd ../../..

bash device/xiaomi/begonia/patches/apply-patches.sh
source build/envsetup.sh
lunch pb_begonia-eng
mka recoveryimage
```

Output: `out/target/product/begonia/recovery.img`

The crypto build downloads proprietary Xiaomi, MediaTek, and MicroTrust blobs;
they are not committed to this repository. The build requires approximately
100 GB of disk space and 16 GB of RAM.

## Installing

```bash
fastboot flash recovery recovery.img
```

The device has a dedicated `recovery` partition. Boot directly to recovery
with **Volume Up + Power**.

## If the safe image still shows the splash

While it is stuck, collect these files if ADB is available:

```bash
adb pull /tmp/recovery.log
adb pull /sys/fs/pstore/console-ramoops
adb pull /cache/recovery/last_log.gz
adb shell getprop ro.pbrp.crypto
adb shell getprop ro.boot.super_partition
```

Do not repeatedly flash the crypto image if the safe image has not been tested;
the crypto image intentionally enters the vendor HAL path.

## Layout and source references

The `safe`, `static`, and `dynamic` fstabs are under
`pbrp_device_tree/variants/`. The default checked-in fstab is safe so a local
build cannot accidentally start with the dynamic logical entries.

The device configuration is based on the working begonia tree maintained by
[Saikrishna1504](https://github.com/Saikrishna1504/device_xiaomi_begonia-pbrp).
The recovery source is
[PitchBlackRecoveryProject/android_bootable_recovery](https://github.com/PitchBlackRecoveryProject/android_bootable_recovery).

## Credits

- PitchBlack Recovery Project
- Team Win Recovery Project
- Saikrishna1504
- WuXing90
- LineageOS
