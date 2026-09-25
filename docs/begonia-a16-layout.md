# begonia (Redmi Note 8 Pro) — Android 16 QPR2 verified layout

Measured on-device 2026-09-25 against a working TWRP 3.7.1, not inferred.

## No physical `super`

`by-name` has no `super`. The super lives **inside the physical `system`
partition** (retrofit), and the bootloader passes:

    androidboot.super_partition=system

BoardConfig sizes match the physical partitions exactly, confirming the layout:

| partition   | physical size (bytes) | BoardConfig SUPER_PARTITION_*_DEVICE_SIZE |
|-------------|----------------------|-------------------------------------------|
| system      |            3758096384 | 3758096384 (SYSTEM)  — match             |
| vendor      |            1610612736 | 1610612736 (VENDOR)  — match             |
| product     |            1829220352 | —                                        |
| system_ext  |            1175416832 | —                                        |
| odm         |              31789056 | —                                        |

## by-name/* is NOT what you mount

Read the ext4 magic (0xEF53) at offset 1080 of each physical partition:

| node                | first bytes | ext4 @1080 | meaning                        |
|---------------------|-------------|------------|--------------------------------|
| by-name/system      | all zero    | not found  | retrofit super **container**  |
| by-name/vendor      | all zero    | **53 ef**  | only real ext4 by-name node    |
| by-name/product     | all zero    | not found  | carved into super             |
| by-name/system_ext  | all zero    | not found  | carved into super             |
| by-name/odm         | all zero    | not found  | carved into super             |

The mountable filesystems are the dynamic devices:

    /dev/block/mapper/system      -> dm-0
    /dev/block/mapper/vendor      -> dm-1
    /dev/block/mapper/product     -> dm-2
    /dev/block/mapper/odm         -> dm-3
    /dev/block/mapper/system_ext  -> dm-4

which is why the ROM's own fstab uses the `logical` fs_mgr flag against a
*partition name* rather than a `/dev/block/...` path:

    system   /system  ext4  ro,barrier=1  wait,logical

Mounting `by-name/system` as ext4 fails outright and leaves recovery stuck on
the splash.

## USB

Kernel passes `androidboot.usbconfigfs=true`. `/sys/class/android_usb/android0`
does **not** exist — TWRP logs `Cannot find file .../idVendor` and
`E:[MTP] Failed to start usb driver!` for exactly this reason. TWRP still gets
adb because it runs over functionfs (`/dev/usb-ffs/adb`). Our build sets
`TW_EXCLUDE_DEFAULT_USB_INIT := true`, so nothing else configures the gadget
and a broken init.rc leaves us with no USB at all.

Enumerated as `2717:ff48` (Xiaomi MTP + ADB), so idProduct is `0xff48`.

## recovery partition

`/dev/block/bootdevice/by-name/recovery` -> `/dev/block/sdc1`, 67108864 bytes,
which is exactly the size of the built `recovery.img`.
