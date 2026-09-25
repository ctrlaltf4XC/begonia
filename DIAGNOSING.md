# Diagnosing the begonia PBRP splash hang

The PBRP logo is the recovery GUI splash. It is drawn in `gui_init()` before
`Setup_Fstab_Partitions()` and `Decrypt_Data()` run, so seeing the logo does not
mean the recovery reached the main menu.

## Root cause candidates

### 0. MicroTrust initialization order (likely for crypto builds)

The old `microtrust_begonia.rc` created `/data/vendor/thh/*` on
`post-fs-data`, but PBRP can start `teei_daemon` as soon as
`hwservicemanager.ready=true`. Android init's `mkdir` is not recursive, so the
missing `/data/vendor` parent could leave the TEE layout incomplete before
keymaster was called. The rc file now creates `/data` and `/data/vendor` on
`init`, before the HAL start trigger.

### 1. Synchronous FBE / keymaster path (most likely for the old image)

On the Android 12.1 PBRP source, `TWPartitionManager::Decrypt_Data()` calls
`fscrypt_mount_metadata_encrypted()` while startup is still on the splash. That
path depends on the vendor MicroTrust TEE, keymaster ABI, and service timing.
A failed or incompatible service can block there indefinitely. The recovery
patch now also follows Saikrishna1504's guard: it calls fscrypt only after the
`/metadata` key-directory partition is successfully mounted.

The previous `beanpod_crypto=false` toggle was incomplete: the device makefile,
crypto properties, init service trigger, fetched blobs, and encrypted fstab
still enabled the path. The default image now disables all of those pieces
together and uses `recovery.fstab.safe`, which omits `/data`.

### 2. Logical-partition wait (dynamic builds)

PBRP's `Prepare_Super_Volume()` contains an unbounded wait for a logical mapper
node. A dynamic image flashed on a static layout can therefore never reach the
main UI. `patches/apply-patches.sh` now bounds this wait to 10 seconds and
returns failure so the partition is skipped.

### 3. Display blank/unblank (secondary)

PBRP's `TW_SCREEN_BLANK_ON_BOOT=true` invokes an MTK framebuffer blank/unblank
sequence during `gui_init()`. It is now disabled by default because the MTK
display driver can wait in that path.

### 4. Forced retrofit-super detection (avoided in safe mode)

`androidboot.super_partition=system` and the retrofit-super source patch are
now applied only to the explicit `dynamic` build. The safe/static startup path
does not force lptools/super setup.

## Verification order

1. Build and flash `safe` + `crypto=false` first.
2. Confirm that the main menu appears. This image does not access encrypted
   `/data` and does not erase it.
3. Only then test `static` or `dynamic` with `crypto=true` on a known ROM.
4. If the safe image still hangs, collect `/tmp/recovery.log`,
   `/sys/fs/pstore/console-ramoops`, and `/cache/recovery/last_log.gz` while it
   is stuck.

The GitHub Actions build proves compilation only; hardware boot verification is
still required.
