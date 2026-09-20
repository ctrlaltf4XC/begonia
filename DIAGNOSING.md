# Diagnosing "stuck on the PBRP splash" on begonia

Everything below is grounded in artefacts that were actually pulled down, not
guesswork. Raw evidence: workflow run `35522402522` (branch `dynamic`,
commit `47410aa`, finished 2026-09-20T17:16:35Z) and its `recovery.img`
artifact.

## What the image actually contains

Parsed `recovery.img` (Android boot image, `header_version=2`):

```
magic           ANDROID!
kernel_size     15656241   kernel_addr  0x40080000
ramdisk_size    25899095   ramdisk_addr 0x47c80000
second_size     0
tags_addr       0x4bc80000  page_size 2048
dtb_size        165214      dtb_addr  0x4bc80000
recovery_dtbo   88556 bytes @ 0x27a2800   (== prebuilt/dtbo.img size)
CMDLINE  bootopt=64S3,32N2,64N2 androidboot.selinux=permissive
         androidboot.usbconfigfs=true androidboot.super_partition=system
         androidboot.init_fatal_reboot_target=recovery buildvariant=eng
```

Structure, offsets and DTB are all consistent with the known-working begonia
trees, so the **boot image itself is not malformed**. The ramdisk (3701 entries)
does contain `system/bin/recovery`, `init.recovery.mt6785.rc`,
`system/etc/recovery.fstab` and the vendor keymaster libs.

Because the PBRP splash *is* drawn, `init` ran and the `recovery` binary
started. A hang at the splash therefore means recovery blocked **after** the GUI
was initialised but **before** the main menu — i.e. in fstab processing,
partition setup or `Decrypt_Data()`.

## Finding 1 — the workflow could never build `dynamic` (fixed)

The run was dispatched on the `dynamic` branch, yet its log says:

```
Selected fstab variant: static
```

`workflow_dispatch:` declared **no `inputs:`**, so `INPUT_VARIANT` was never set
and `VARIANT="${INPUT_VARIANT:-static}"` always fell back to `static`. That is
why the UI offered no variant choice, and why every image so far — including
the "dynamic" one — was built with `recovery.fstab.static`.

Fixed by declaring real inputs (`variant`: static/dynamic/safe,
`beanpod_crypto`: bool) and plumbing them through `${{ inputs.* }}`.

Corroborating symptom: the artifact was named `PBRP-begonia-.zip` — the
`Create flashable zip` step referenced `${VARIANT}`, which only existed in the
fstab steps. Same root cause, now fixed.

## Finding 2 — our delta vs. the known-working begonia tree

Our README credits `Saikrishna1504/twrp_device_xiaomi_begonia-pbrp` as the
"working begonia PBRP tree carrying the beanpod decrypt stack". Comparing that
tree's `recovery/root/system/etc/recovery.fstab` (6 entries: system, vendor,
misc, userdata ext4, userdata f2fs, metadata) against the fstab we baked in
(45 entries) shows the divergence:

| Setting | Ours (before) | Known-working tree |
|---|---|---|
| `init_fatal_reboot_target` | `recovery` | `bootloader` |
| `TW_USE_FSCRYPT_POLICY` | `2` | `1` |
| `TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT` | `true` | not set |
| keymaster relink into ramdisk | forced on | not done |
| fstab entries | 45 (incl. `/cache`, `/boot`, `/dtbo`, `/vbmeta`, 17 MTK firmware partitions, zram swap, wildcard `voldmanaged`) | 6 |

Three of these plausibly produce a splash hang:

1. **`init_fatal_reboot_target=recovery`** — a fatal `init` error reboots
   straight back into recovery, which the user sees as a splash hang/loop.
2. **`TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT`** — forces a blank/unblank
   during init. On MTK that lands in the exact path the failing `dmesg` showed:
   `[DISP][_ioctl_wait_self_refresh_trigger] ERROR:[REPAINT] wait_event
   unexpectedly, ret:-512`.
3. **Keymaster relink** — TWRP decrypts `/data` *before* the main menu is drawn.
   We force `libkeymaster4.so` / `libpuresoftkeymasterdevice.so` /
   `libshim_beanpod.so` into the ramdisk and rely on the vendor TEE HAL, which
   has no `hwservicemanager`/`teei_daemon` in recovery. If that call blocks, the
   symptom is precisely a splash hang. The known-working tree does not do this.

## Finding 3 — the docs' own theory (logical fstab busy-wait)

`select-fstab.sh` and the README explain that TWRP's
`TWPartitionManager::Prepare_Super_Volume()` resolves a `logical` entry with a
timeout-free busy-wait:

```c
if (partition->Is_Super && !Prepare_Super_Volume(partition))
    goto clear;                       // partition dropped
while (access(fstabEntry.blk_device.c_str(), F_OK) != 0)
    usleep(100);                      // NO TIMEOUT
```

Upstream PBRP already has the correct fix — commit
`58fda81` *"partitionmanager: don't treat non-existing logical partitions"* —
which **erases** the partition instead of waiting:

```c
-        if ((*iter)->Is_Super) Prepare_Super_Volume((*iter));
+        if ((*iter)->Is_Super && !Prepare_Super_Volume(*iter))
+            Partitions.erase(iter--);
```

This is worth applying rather than shipping two fstabs around it. It does not
explain the current hang (the `static` fstab has no `logical` entries), but it
removes the whole class of failure.

## Changes made

* **Reverted** an earlier, non-functional "display driver" patch
  (`MTK_DISPLAY_SUPPORT`, `libdisp_drv`, `disp_drv.c`). It was not a real fix:
  `libdisp_drv` does not exist, so `TARGET_RECOVERY_DEVICE_MODULES += libdisp_drv`
  would have broken the build, and `MTK_DISPLAY_SUPPORT` is not a real
  Android/TWRP variable.
* `init_fatal_reboot_target` → `bootloader` (matches known-working tree).
* Dropped `TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT` (MTK blank/unblank at init).
* `TW_USE_FSCRYPT_POLICY` → `1` by default; `2` is now opt-in via
  `BEANPOD_FSCRYPT_V2 := true`.
* Keymaster/beanpod relink is now **opt-in** via `BEANPOD_CRYPTO := true`, so the
  vanilla build matches the known-working tree.
* Added `variants/recovery.fstab.safe` — an exact copy of the known-working
  tree's fstab — as a diagnostic baseline.
* Workflow: real `variant` / `beanpod_crypto` inputs, variant validation,
  correct zip naming, variant-tagged artifact names, `BUILD_INFO.txt`, and a fix
  for the `out/target-product` path typo.

## Bisect plan on the device

Build in this order and stop at the first image that reaches the main menu:

1. `variant=safe`, `beanpod_crypto=false` — closest to the working tree. If this
   boots, the fault is in our fstab/board config, not the boot image.
2. `variant=safe`, `beanpod_crypto=true` — isolates the keymaster/decryption path.
3. `variant=static`, `beanpod_crypto=false` — isolates our 45-entry fstab.
4. `variant=dynamic` — only meaningful on Android 11+ firmware.

If even step 1 hangs, capture `dmesg`
(`/sys/fs/pstore/console-ramoops`) and `/cache/recovery/last_log.gz` again, plus
`adb pull /tmp/recovery.log` while it is stuck. `/tmp/recovery.log` is written
early and is the single most useful file for a splash hang.
