# PitchBlack Recovery for Redmi Note 8 Pro (begonia)

A complete, buildable **PitchBlack Recovery Project (PBRP)** device tree for the
Redmi Note 8 Pro — codename **begonia** / **begoniain** — MediaTek **MT6785**
(Helio G90T).

The single recovery image produced by this tree supports:

| Capability | Status |
|---|---|
| **Non-dynamic partitions** (stock Android 9/10 firmware) | yes |
| **Retrofit dynamic partitions** (`/super` over system+vendor, Android 11 to 16) | yes |
| **FDE** — full-disk encryption, AES-256-XTS (Android 9) | yes |
| **FBE v1** — file-based encryption (Android 10/11) | yes |
| **FBE v2** — metadata-based FBE (Android 12+) | yes |
| **FBE with hardware wrapped keys** — MicroTrust TEE (Android 13 to 16) | yes |
| Reading **ext4 / f2fs / erofs / exFAT / NTFS** | yes |
| **Android 16 (LineageOS 23 / AOSP 16) ROMs** | yes |

---

## Contents

```
pbrp_device_tree/                    <- copy to device/xiaomi/begonia
├── BoardConfig.mk                   board config incl. dual-layout + crypto
├── device.mk                        common device makefile
├── pb_begonia.mk                    PBRP product definition (lunch: pb_begonia)
├── AndroidProducts.mk               lunch choices
├── Android.mk / Android.bp          build glue
├── board-info.txt                   assert info
├── system.prop / vendor.prop        properties (FBE wrappedkey etc.)
├── prebuilt/
│   ├── Image.gz                     MT6785 kernel 4.14 (prebuilt)
│   ├── dtbo.img                     device tree overlay
│   └── dtb/mtk.dtb                  device tree blob
├── libshim_beanpod/                 ABI shim for the TEE keymaster HAL
├── patches/apply-patches.sh         upstream source patches (idempotent)
├── recovery/root/
│   ├── init.recovery.mt6785.rc      main recovery init
│   ├── init.begonia.rc              layout detection hook
│   ├── init.recovery.usb.rc         USB gadget config
│   ├── microtrust_begonia.rc        teei_daemon + TA configuration
│   ├── ueventd.rc                   device node permissions
│   ├── sbin/begonia-layout-detect.sh  runtime dynamic vs non-dynamic probe
│   ├── system/etc/recovery.fstab    dual-layout fstab
│   ├── system/etc/twrp.flags        backup/flash partition definitions
│   └── .../vintf/*.xml              HAL manifests
├── fetch-decryption-blobs.sh        pulls the TEE decryption stack
└── fetch-vendor-blobs.sh            local alternative (needs vendor tree)
```

`.github/workflows/build-pbrp.yml` builds the image in CI.

---

## Why this design

### PBRP has no Android 16 branch

Checking `PitchBlackRecoveryProject/manifest_pb`, the newest branches are:

| Branch | Last updated |
|---|---|
| `android-12.1` | **Sep 2025** (actively maintained) |
| `android-14.0` | Sep 2024 |
| `android-11.0` | Oct 2024 |

There is **no `android-15.0` or `android-16.0`**. "A16 support" therefore means
the recovery must *operate correctly on a device running Android 16*, not that
PBRP itself is compiled from A16 sources. That is achieved here by:

* **FBE v2 + wrapped keys** — A16 uses fscrypt v2 with keys sealed by the TEE
  (`/metadata/vold/metadata_encryption`, `dm-default-key`). The beanpod
  keymaster@4.0 / gatekeeper@1.0 stack is therefore included and relinked.
* **Retrofit dynamic partitions** — A16 ROMs for begonia put system, vendor,
  product, system_ext and odm inside `/super`, which itself lives on top of the
  physical `system` + `vendor` extents.
* **erofs** — A16 system/vendor images are erofs-compressed.

The default build target is **`android-12.1`** (PBRP 4.0 / TWRP 3.7.1_12), which
is the newest *stable, maintained* PBRP branch and already contains the FBE v2,
wrapped-key and lptools code paths. The workflow also offers `android-14.0`.

### How one image handles both partition layouts

begonia shipped with Android 9 (non-dynamic). Android 11+ ROMs retrofit a
`/super` onto the existing `system`+`vendor` extents.

`recovery.fstab` declares **both**:

* `system`, `vendor`, `product`, `system_ext`, `odm` with the `logical` flag →
  resolved through device-mapper when a super exists.
* `/dev/block/platform/bootdevice/by-name/system` and `.../vendor` → used
  directly when there is no super.

Because a missing logical device simply makes that entry un-mountable while the
physical entry still resolves, **the same image boots and flashes on both**.

In addition `sbin/begonia-layout-detect.sh` probes at runtime (kernel cmdline,
`/dev/block/mapper`, LP metadata magic) and publishes `ro.begonia.layout`.

### Decryption

```
teei_daemon  ──> loads the MicroTrust Trusted Applications
                    |
keymaster@4.0-service.beanpod ──> unwraps the FBE key (hardware wrapped key)
gatekeeper@1.0-service ────────> verifies the user credential
                    |
              /data decrypted
```

The beanpod binaries were linked against an older `libkeymaster_messages` ABI.
`libshim_beanpod` restores the 17 symbols they need; the list was derived
directly from `readelf -sW libkeymaster4.so | grep UND` and is verified
complete. The vendor binaries even declare `libshim_beanpod.so` as a
---

## Building

### GitHub Actions (recommended)

Push to `main`, or run the **Build PBRP for begonia** workflow manually
(`workflow_dispatch`) and choose the manifest branch. Artefacts
(`recovery.img`, the flashable zip, and the build log) are uploaded to the run.

The workflow:

1. Frees ~30 GB of runner disk.
2. Installs the PBRP build dependencies.
3. `repo init` / `repo sync` the chosen PBRP manifest.
4. Copies this tree to `device/xiaomi/begonia`.
5. Runs `patches/apply-patches.sh`.
6. `lunch pb_begonia-eng` and `make recoveryimage`.

### Locally

```bash
mkdir pbrp && cd pbrp
repo init -u https://github.com/PitchBlackRecoveryProject/manifest_pb -b android-12.1 --depth 1
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags

# place the device tree
git clone <this repo> device/xiaomi/begonia
# (or: cp -a pbrp_device_tree device/xiaomi/begonia)

cd device/xiaomi/begonia
./fetch-decryption-blobs.sh          # TEE decryption stack

cd ../../..
source build/envsetup.sh
lunch pb_begonia-eng
export ALLOW_MISSING_DEPENDENCIES=true
make -j$(nproc) recoveryimage
```

Output: `out/target/product/begonia/recovery.img`

Requires ~100 GB of disk and 16 GB of RAM. Use the CI workflow otherwise.

> **Note:** `fetch-decryption-blobs.sh` downloads proprietary Xiaomi / MediaTek
> / MicroTrust binaries. They are deliberately **not** committed (see
> `.gitignore`) and must not be redistributed.

---

## Installing

```bash
fastboot flash recovery recovery.img
# or flash the zip from an existing custom recovery
```

begonia keeps a dedicated `recovery` partition, so the usual A-only flow
applies — no `boot` patching is needed.

To boot directly into recovery: hold **Volume Up + Power**.

---

## Device facts used by this tree

| Item | Value |
|---|---|
| SoC | MediaTek MT6785 (Helio G90T) |
| Kernel | 4.14, boot image header v2 |
| Kernel load base | `0x40078000` |
| Kernel / ramdisk / tags / dtb offsets | `0x00008000` / `0x07c08000` / `0x0bc08000` / `0x0bc08000` |
| Boot / recovery partition | 64 MiB each |
| Physical system / vendor | 3584 MiB / 1536 MiB |
| Retrofit super total | 5120 MiB (metadata on `system`) |
| Dynamic partitions | system, vendor, product, system_ext, odm |
| Metadata partition | present (FBE v2 key directory) |
| Userdata | ext4 or f2fs, ~112 GiB |
| Block-by-name root | `/dev/block/platform/bootdevice/by-name` |
| Keymaster / gatekeeper | `beanpod` (MicroTrust TEE) |
| Display | 1080x2340 @ 440 dpi (TW portrait_hdpi, Y+80 / H-80) |
| Brightness | `/sys/class/leds/lcd-backlight/brightness`, max 2047 |

---

## Known limitations

* The prebuilt kernel, `dtbo.img` and `mtk.dtb` are 4.14 MT6785 binaries taken
  from the working begonia recovery trees. They boot both Android 9 and
  Android 16 ROMs, but an inline kernel build is not performed here.
* The proprietary TEE blobs are fetched at build time, not vendored.
* `libshim_beanpod` covers the keymaster ABI gap on the PBRP 12.1 and 14.0
  branches. If a future branch changes `libkeymaster_messages`, re-run the
  `readelf` command in the README to regenerate the symbol list.
* Flashing a **non-dynamic** ROM over a **dynamic** install (or vice versa)
  requires a format of `system`/`vendor` (`/super`) first; the recovery
  supports both but cannot convert layouts by itself.

---

## Credits

* [PitchBlack Recovery Project](https://github.com/PitchBlackRecoveryProject) — the recovery itself
* [Team Win Recovery Project](https://github.com/TeamWin) — base recovery, lptools
* [SebaUbuntu](https://github.com/SebaUbuntu) — TWRP device tree generator
* [Saikrishna1504](https://github.com/Saikrishna1504) — working begonia PBRP tree carrying the beanpod decrypt stack
* [WuXing90](https://github.com/WuXing90) — modern begonia trees, retrofit super layout reference
* [begonia-dev](https://github.com/begonia-dev) — maintained begonia device and vendor trees
* [LineageOS](https://github.com/LineageOS) — `mt6785-common` device tree
`DT_NEEDED`, confirming this is the intended mechanism.