# TUI Maquettes — V2 Flash Toolkit

**Conventions**

* Footer shows hints: `↑/↓ select · Enter confirm · ESC cancel · F1 Help · F4 View Log`
* Danger actions show red title + double-confirm.
* `[…]` = checkbox · `( )` = radio · `<…>` = input · `▶` = default button.

---

# kernel\_build.step\_1 — Select Kernel Repository

```
┌─ Select Kernel Repository ───────────────────────────────────────────────┐
│ Choose a source for the kernel code.                                     │
│                                                                          │
│   ▸ anbernic/h700-linux (official-ish mirror)                            │
│     community/h700-kernel-tuned                                          │
│     forks/grzegorz/rx28-disp-panel                                       │
│     forks/karol/h700-exp-dma                                             │
│     ----------------------------------------------------------------     │
│     Enter custom URL…                                                    │
│                                                                          │
│  Details                                                                │
│  Repo: anbernic/h700-linux                                               │
│  Desc: Allwinner H700 A64 family tree + RG35XX H tweaks                  │
│                                                                          │
│                              [ Help ]  [ Cancel ]   ▶[ Continue ]        │
└──────────────────────────────────────────────────────────────────────────┘
```

**What it does**

* Lists curated repos from `config/repos.yml` plus a “custom URL” path.
* On “custom URL”, opens an input box.

**State updated**

* `WZ[repo_url]`, `WZ[repo_name]`

**Validation**

* If URL empty/invalid → inline error.

---

# kernel\_build.step\_2 — Select Branch/Tag

```
┌─ Pick Branch or Tag ─────────────────────────────────────────────────────┐
│ Show branches/tags fetched from remote. Use fuzzy search with fzf.       │
│                                                                          │
│   ▸ branch: main                                                         │
│     branch: rg35xxh-stable                                               │
│     tag: v6.10.12-rg                                                     │
│     tag: v6.10.9                                                         │
│                                                                          │
│  Remote: origin  |  Repo: anbernic/h700-linux                            │
│                                                                          │
│                         [ Back ]  [ Help ]   ▶[ Continue ]               │
└──────────────────────────────────────────────────────────────────────────┘
```

**What it does**

* Calls `git ls-remote` (via `lib/git.sh`), renders list.

**State**

* `WZ[ref]` (branch/tag name)

---

# kernel\_build.step\_3 — Apply Config Patch?

```
┌─ Kernel Config Patch ────────────────────────────────────────────────────┐
│ Apply a .config fragment to base defconfig, then olddefconfig?           │
│                                                                          │
│   [x] Apply config patch                                                 │
│       Patch file:  ./config_patch                                        │
│       Base defconfig:  defconfig (auto)                                  │
│                                                                          │
│ Notes: uses scripts/kconfig/merge_config.sh, then make olddefconfig.     │
│                                                                          │
│                 [ Back ]  [ Browse Patch… ]  [ Help ]  ▶[ Continue ]     │
└──────────────────────────────────────────────────────────────────────────┘
```

**What it does**

* Optional merge with `merge_config.sh`, fallback to plain defconfig.

**State**

* `WZ[apply_patch]=1/0`, `WZ[patch_path]`

**Validation**

* If checked but file missing → error banner.

---

# kernel\_build.step\_4 — Build Settings

```
┌─ Build Settings ─────────────────────────────────────────────────────────┐
│ Threads: < 8 >      Target arch: ( ) arm   (•) arm64                     │
│ Output dir: < builds/anbernic-h700/20250919-1122 >                        │
│                                                                          │
│ [ ] Save these as defaults                                                │
│                                                                          │
│ Estimated time: ~6–12 min on 8 cores. Progress will be shown.            │
│                                                                          │
│                        [ Back ]  [ Help ]   ▶[ Start Build ]             │
└──────────────────────────────────────────────────────────────────────────┘
```

**State**

* `WZ[jobs]`, `WZ[arch]`, `WZ[outdir]`

---

# kernel\_build.step\_5 — Build Progress

```
┌─ Building Kernel (do not close) ─────────────────────────────────────────┐
│ make -j8 …                                                               │
│                                                                          │
│ [######################…………………..] 62%                                    │
│  CC drivers/...                                                          │
│  LD vmlinux                                                              │
│                                                                          │
│ Log: logs/20250919-1122-build.log                                        │
│                                                                          │
│                                   [ View Log ]   ▶[ Run in Background ]  │
└──────────────────────────────────────────────────────────────────────────┘
```

**What it does**

* Gauge fed by `pv -l` heuristic.
* Background keeps logging; returns to menu with a banner.

---

# kernel\_build.step\_6 — Artifacts Summary

```
┌─ Build Complete ─────────────────────────────────────────────────────────┐
│ Artifacts in: builds/anbernic-h700/20250919-1122                         │
│                                                                          │
│   ✓ Image.gz                                                             │
│   ✓ arch/arm64/boot/dts/allwinner/sun50i-h700-anbernic-rg35xx-h.dtb      │
│   ✓ modules: /lib/modules/6.10.12-rg                                     │
│   ⚠ boot.img not generated (create via Adjust wizard)                    │
│                                                                          │
│ What next?                                                               │
│   ▸ Go to Flash Image                                                    │
│     Open Boot.img / RootFS Adjuster                                      │
│     Return to Main Menu                                                  │
│                                                                          │
│                         [ View Log ]   ▶[ Continue ]                     │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# flash.step\_1 — Pick Build Artifact

```
┌─ Select Image or Kernel to Flash ────────────────────────────────────────┐
│   ▸ builds/.../system.img (3.2 GB)                                       │
│     builds/.../new-boot.img (24 MB)                                      │
│     builds/.../Image.gz (kernel only)                                    │
│     Browse…                                                               │
│                                                                          │
│ Tip: If flashing a custom kernel, prefer using Boot.img Adjuster next.   │
│                                                                          │
│                            [ Back ]  [ Help ]   ▶[ Continue ]            │
└──────────────────────────────────────────────────────────────────────────┘
```

**State**

* `WZ[artifact_path]`

---

# flash.step\_2 — Select SD Card

```
┌─ Choose Target Device ───────────────────────────────────────────────────┐
│ Detected block devices:                                                  │
│   ▸ /dev/sdb  64 GB  KINGSTON  (Suggested)                               │
│     /dev/sdc  256 GB SAMSUNG                                            │
│                                                                          │
│ Partitions (/dev/sdb):                                                   │
│   p1 …                                                                    │
│   p4  64 MB  (boot)                                                      │
│   p5  12 GB  (rootfs)                                                    │
│                                                                          │
│ 🔴 WARNING: Writing to a disk will erase data. Make a backup first.      │
│                                                                          │
│                    [ Back ]  [ Help ]   ▶[ I Understand, Continue ]      │
└──────────────────────────────────────────────────────────────────────────┘
```

**Guardrail**

* If target is system root → hard block with explanation.

---

# flash.step\_3 — Backup First?

```
┌─ Backup Before Flash ────────────────────────────────────────────────────┐
│ Recommended. Choose scope:                                               │
│   (•) Full disk → backups/disk-KINGSTON-64GB-20250919.img.zst            │
│   ( ) Boot partition only → backups/boot-20250919.img                    │
│   ( ) Skip backup                                                        │
│                                                                          │
│ Compression: (•) zstd  ( ) gzip  ( ) none                                │
│                                                                          │
│                     [ Back ]  [ Help ]   ▶[ Start Backup ]               │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# flash.step\_4 — Flash Progress

```
┌─ Flashing /dev/sdb (do not remove) ──────────────────────────────────────┐
│ pv image.img | dd of=/dev/sdb bs=4M conv=fsync status=progress           │
│                                                                          │
│ [#########################………………] 71%  (93 MB/s, 1m22s remaining)        │
│                                                                          │
│ Log: logs/20250919-1144-flash.log                                        │
│                                                          ▶[ View Log ]   │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# flash.step\_5 — Verify & Done

```
┌─ Flash Complete ─────────────────────────────────────────────────────────┐
│ Optional verify?                                                         │
│   [ ] Compare hashes (slow)                                              │
│                                                                          │
│ Next steps:                                                              │
│   ▸ Run Boot.img / RootFS Adjuster                                       │
│     Return to Main Menu                                                  │
│                                                                          │
│                         [ View Log ]   ▶[ Continue ]                     │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# bootimg\_adjust.step\_1 — Choose Base (Stock) Boot Image

```
┌─ Boot.img / RootFS Adjuster ─────────────────────────────────────────────┐
│ How would you get the base (stock) boot image?                           │
│   ▸ Extract from device partition now (/dev/sdb4 ~64 MB)                 │
│     Browse file…                                                         │
│                                                                          │
│ Note: Stock header sets pagesize/base/cmdline—copying these avoids loops.│
│                                                                          │
│                            [ Back ]  [ Help ]   ▶[ Continue ]            │
└──────────────────────────────────────────────────────────────────────────┘
```

**If extract chosen** → backs up `/dev/sdb4` to `backups/boot-<ts>.img` first.

---

# bootimg\_adjust.step\_2 — Extraction Summary

```
┌─ Extracted Stock Boot Image ─────────────────────────────────────────────┐
│ Work dir: work/bootimg-20250919-1157/                                    │
│ Header: page_size=2048  base=0x40000000  cmdline=…                       │
│ Files:                                                                   │
│   kernel            18.2 MB                                              │
│   ramdisk.cpio.gz    6.8 MB                                              │
│   dtb               present                                              │
│   bootimg.cfg       present                                              │
│                                                                          │
│                    [ Back ]   ▶[ Select New Kernel ]   [ View Log ]      │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# bootimg\_adjust.step\_3 — Select New Kernel

```
┌─ Select New Kernel Image ────────────────────────────────────────────────┐
│   ▸ builds/.../Image.gz (Linux 6.10.12-rg)                               │
│     builds/.../zImage                                                    │
│                                                                          │
│ Detected version: 6.10.12-rg   (from strings)                            │
│                                                                          │
│                        [ Back ]  [ Help ]   ▶[ Continue ]                │
└──────────────────────────────────────────────────────────────────────────┘
```

**State**

* `WZ[new_kernel]`, `WZ[new_kernel_ver]`

---

# bootimg\_adjust.step\_4 — DTB Mode

```
┌─ Choose DTB Mode ────────────────────────────────────────────────────────┐
│ Select how the DTB is provided to the boot image.                        │
│   (•) with-dt   → mkbootimg --dt dtb.img                                 │
│   ( ) catdt     → cat Image + dtb.img → Image_dtb                        │
│                                                                          │
│ Device profile: RG35XX-H (Allwinner H700)                                │
│ Tip: Try with-dt first; catdt is a fallback for picky bootloaders.       │
│                                                                          │
│                        [ Back ]  [ Help ]   ▶[ Continue ]                │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# bootimg\_adjust.step\_5 — Select DTB Variant(s)

```
┌─ Select DTB Variant ─────────────────────────────────────────────────────┐
│   ▣ sun50i-h700-anbernic-rg35xx-h.dtb                                    │
│   ☐ sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb                         │
│   ☐ rg40xx-h.dtb (compat)                                                │
│                                                                          │
│ If multiple selected → build dtb.img (mkdtimg/cat per profile).          │
│                                                                          │
│                        [ Back ]  [ Help ]   ▶[ Build dtb.img ]           │
└──────────────────────────────────────────────────────────────────────────┘
```

**Validation**

* At least one DTB must be chosen.

---

# bootimg\_adjust.step\_6 — Cmdline Editor

```
┌─ Kernel Cmdline (advanced) ──────────────────────────────────────────────┐
│ From stock:                                                              │
│   console=ttyS0,115200 console=tty0 root=/dev/mmcblk0p5 rw …             │
│                                                                          │
│ Quick toggles:                                                           │
│   [x] console=tty0          [x] ignore_loglevel     [ ] earlycon         │
│                                                                          │
│ Edit:                                                                    │
│ < console=ttyS0,115200 console=tty0 root=/dev/mmcblk0p5 rw …           > │
│                                                                          │
│                        [ Back ]  [ Help ]   ▶[ Save & Continue ]         │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# bootimg\_adjust.step\_7 — Repack Boot Image

```
┌─ Repack boot.img ────────────────────────────────────────────────────────┐
│ mkbootimg with:                                                          │
│   --kernel:   builds/.../Image.gz                                        │
│   --ramdisk:  ramdisk.cpio.gz                                            │
│   --dt:       dtb.img (mode: with-dt)                                    │
│   --pagesize: 2048   --base: 0x40000000                                  │
│   --cmdline:  (edited)                                                   │
│                                                                          │
│ [ Start ]                                                                │
│                                                                          │
│ [###############…………………] 54%                                             │
│                                                                          │
│ Output: builds/.../new-boot.img (24 MB)                                   │
│                                                                          │
│                           ▶[ Continue ]  [ View Log ]                    │
└──────────────────────────────────────────────────────────────────────────┘
```

**Guardrails**

* If output > boot partition size → **abort with fix tips**.

---

# bootimg\_adjust.step\_8 — Modules Sync

```
┌─ Sync Kernel Modules to RootFS ──────────────────────────────────────────┐
│ Detected kernel: 6.10.12-rg                                              │
│ RootFS partition: /dev/sdb5 (mount: /mnt/rootfs)                         │
│                                                                          │
│   ▸ Copy ./lib/modules/6.10.12-rg → /mnt/rootfs/lib/modules/…            │
│   ▸ Run depmod -a -b /mnt/rootfs 6.10.12-rg                              │
│                                                                          │
│ [x] Do this now (recommended)                                            │
│                                                                          │
│                        [ Skip ]                      ▶[ Execute ]         │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# bootimg\_adjust.step\_9 — Flash Boot Partition

```
┌─ Flash new-boot.img to /dev/sdb4 ────────────────────────────────────────┐
│ First, a safety backup will be created: backups/boot-20250919-pre.img    │
│                                                                          │
│ [#########…………………………………] 28%  (backup)                                   │
│ [#############################……] 82%  (flash)                            │
│                                                                          │
│ Log: logs/20250919-1210-adjust.log                                       │
│                                                          ▶[ View Log ]   │
└──────────────────────────────────────────────────────────────────────────┘
```

**Double confirm**

* Dialog with the exact device path, model, size.

---

# bootimg\_adjust.step\_10 — Optional QEMU Smoke Test

```
┌─ QEMU Boot Test (optional) ──────────────────────────────────────────────┐
│ Running headless boot… capturing first 200 lines of kernel log.          │
│                                                                          │
│ [ OK ] Decompressing Linux…                                              │
│ [ OK ] Mounting root…                                                    │
│ …                                                                         │
│                                                                          │
│ Save log to: logs/20250919-qemu.log                                      │
│                                                                          │
│                         [ Skip ]  ▶[ Save & Continue ]                    │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# bootimg\_adjust.step\_11 — Done

```
┌─ Adjuster Complete ──────────────────────────────────────────────────────┐
│ New boot.img is flashed and modules synced.                              │
│                                                                          │
│ Next steps:                                                              │
│   ▸ Power off device, reinsert SD, and boot.                             │
│   ▸ If black screen: rerun Adjuster with alternate DTB or catdt mode.    │
│                                                                          │
│                         [ View Log ]   ▶[ Return to Menu ]               │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# backup\_restore.step\_1 — Choose Action

```
┌─ Backup / Restore ───────────────────────────────────────────────────────┐
│   ▸ Backup full disk                                                     │
│     Backup single partition                                              │
│     Restore full disk                                                    │
│     Restore single partition                                             │
│                                                                          │
│                         [ Back ]   ▶[ Continue ]                         │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# backup\_restore.step\_2 — Pick Source / Target

```
┌─ Select Source & Destination ────────────────────────────────────────────┐
│ Source:                                                                  │
│   ▸ /dev/sdb (KINGSTON 64 GB)                                            │
│                                                                          │
│ Destination file: < backups/disk-KINGSTON-64GB-20250919.img.zst >        │
│ Compression: (•) zstd  ( ) gzip  ( ) none                                │
│                                                                          │
│                         [ Back ]  [ Help ]   ▶[ Start ]                  │
└──────────────────────────────────────────────────────────────────────────┘
```

*(Restore swaps roles: file → device with double confirm)*

---

# backup\_restore.step\_3 — Progress & Verify

```
┌─ Running backup ─────────────────────────────────────────────────────────┐
│ [################…………………] 63%  (78 MB/s)                                │
│                                                                          │
│ [ ] Verify after completion (hash compare)                               │
│                                                                          │
│ Log: logs/20250919-1230-backup.log                                       │
│                                                          ▶[ View Log ]   │
└──────────────────────────────────────────────────────────────────────────┘
```

---

# backup\_restore.step\_4 — Done

```
┌─ Operation Complete ─────────────────────────────────────────────────────┐
│ Backup saved to: backups/disk-KINGSTON-64GB-20250919.img.zst             │
│                                                                          │
│ Next:                                                                    │
│   ▸ Return to Main Menu                                                  │
│   ▸ Open folder                                                          │
│                                                                          │
│                         [ Open Folder ]   ▶[ Finish ]                    │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Flow glue (what triggers what)

* **From Build → Flash**: Offer CTA as soon as artifacts exist.
* **From Flash → Adjust**: After flashing a system image or raw kernel, propose Adjuster to ensure boot.img+modules coherence (prevents loops).
* **From Adjust → Backup/Restore**: Always offer quick restore if size/verify fails.
* **Logs**: every wizard writes a timestamped log and exposes “View Log”.