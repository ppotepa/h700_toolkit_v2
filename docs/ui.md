Awesome — here’s a **complete, step-by-step UI/UX guide** with **file names, patterns, and folder structure** tailored to your V2 Flash Toolkit (Kernel Build → Flash → **Boot.img/RootFS Adjuster** → Backup/Restore). It’s written like an implementation playbook you can hand to the team.

---

# Project structure (production-ready TUI)

```
flash-toolkit/
├─ flash-toolkit.sh                  # single entrypoint (main TUI)
├─ README.md                         # short how-to + safety notes
├─ .env.example                      # THEME, DRY_RUN, etc.
├─ .gitignore                        # ignore logs/backups/work/.state.json
├─ .state.json                       # (optional) last selections cache
│
├─ config/
│  ├─ repos.yml                      # curated kernel repos
│  ├─ devices.yml                    # device profiles (page_size, dtb mode, parts)
│  ├─ ui-copy.yml                    # all UI strings/microcopy (i18n-ready)
│  └─ safety.yml                     # guardrails & confirmations
│
├─ lib/
│  ├─ base.sh                        # strict mode, traps, logging, state
│  ├─ ui.sh                          # whiptail/gum/fzf wrappers, menus/gauges
│  ├─ disk.sh                        # lsblk/blkid parsing, pickers, guards
│  ├─ git.sh                         # clone + branch/tag selection
│  ├─ build.sh                       # defconfig + merge_config + make
│  ├─ bootimg.sh                     # abootimg/unmkbootimg/mkbootimg helpers
│  ├─ modules.sh                     # /lib/modules sync + depmod
│  ├─ qemu.sh                        # QEMU_BOOT_ORCH smoke test hooks
│  └─ config.sh                      # YAML/env loader + defaults
│
├─ wizards/
│  ├─ kernel_build.sh                # screens: kernel_build.step_1..step_6
│  ├─ flash.sh                       # screens: flash.step_1..step_5
│  ├─ bootimg_adjust.sh              # screens: bootimg_adjust.step_1..step_11
│  └─ backup_restore.sh              # screens: backup_restore.step_1..step_4
│
├─ templates/
│  ├─ config_patch.example           # sample Kconfig fragment
│  ├─ cmdline.example                # baseline kernel cmdline
│  └─ ui-theme.example               # theme tokens (gum/whiptail)
│
├─ builds/
│  └─ <repo-slug>/<YYYYmmdd-HHMMss>/ # Image/zImage, *.dtb, dtb.img, new-boot.img
│
├─ backups/
│  ├─ disk-<model>-<size>-<ts>.img.zst
│  ├─ boot-<ts>.img                  # stock boot dump
│  └─ boot-<ts>-preflash.img         # auto-backup before flashing new-boot.img
│
├─ logs/
│  └─ <YYYYmmdd-HHMMss>-<wizard>.log # one per wizard run
│
├─ work/                             # ephemeral bootimg workdirs (gitignored)
│  └─ bootimg-<YYYYmmdd-HHMMss>/     # extracted kernel/ramdisk/dtb/bootimg.cfg
│
├─ test/
│  ├─ bats/
│  │  ├─ disk_parsing.bats
│  │  ├─ bootimg_header.bats
│  │  └─ mkbootimg_args.bats
│  └─ fixtures/
│     └─ lsblk-sample.json
│
└─ tools/
   ├─ bin/
   │  ├─ abootimg                    # or wrapper if not in PATH
   │  ├─ unmkbootimg
   │  ├─ mkbootimg
   │  └─ qemu-system-aarch64         # optional for smoke test
   └─ install-deps.sh                # fetch pv, dd, fzf, gum, shfmt, shellcheck

```

**Naming conventions**

* Scripts: `kebab-case.sh`; functions `snake_case`.
* Logs & folders timestamp: `YYYYmmdd-HHMMss`.
* Wizard IDs: `build`, `flash`, `adjust`, `backup`.

---

# Entry point & menu flow

**File:** `flash-toolkit.sh`
**Role:** Wiring, feature flags, main menu.

**Main menu order (final):**
    
```
[1] Kernel Build
[2] Flash Image
[3] Boot.img / RootFS Adjuster   # ← sits between Flash and Restore
[4] Backup / Restore
[5] Exit
```

**UX rules**

* Always show a **status footer**: ⓘ “Use ↑/↓ to navigate, Enter to confirm, ESC to cancel.”
* Every destructive screen uses **double confirmation** with red accent and explicit target display.
* Show **progress indicators** for any step >1s (gum spinner for unknown, whiptail gauge for known %).
* Provide **View log** action after each wizard (opens via `less`).

---

# UI building blocks

**File:** `lib/ui.sh`

* `ui_menu title items[@] default_index -> choice`
* `ui_confirm title message danger=true -> yes/no`
* `ui_input title placeholder default -> value`
* `ui_gauge title feed_fn` (reads `0..100` from stdin)
* `ui_spinner title cmd...` (gum spin fallback to `printf`)

**Microcopy source:** `config/ui-copy.yml`

* Titles: “Select Kernel Repo”, “Confirm Flash Target”
* Warnings: “This will overwrite /dev/sdX (128 GB, KINGSTON). Are you absolutely sure?”

**Theme tokens:** `templates/ui-theme.example`

* gum: borders, margins; whiptail: `--backtitle`, colour envs.

---

# Device & partition selection UX

**File:** `lib/disk.sh`

* `list_block_devices_json` (lsblk -J -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL,PATH)
* `suggest_boot_partition` (heuristic: ≈64 MB, label matches profile)
* `ui_pick_disk` → menu grouped by **Model / Size**, highlights “(Suggested)”
* On selection, show **summary screen**: device, size, model, partitions, **boot** & **rootfs** candidates.

**UX safeguards**

* If target device matches system root (`/`), **hard block** with explanation and “Open docs”.
* Show **dry-run hint** when `.env` sets `DRY_RUN=1`.

---

# Step-by-step UX for each wizard

## \[1] Kernel Build (`wizards/kernel_build.sh`)

**Screens & files**

1. **Select Kernel Repo**

   * Uses `config/repos.yml`.
   * Options: curated list + “Enter custom URL…” (input dialog).
2. **Pick Branch/Tag**

   * `git ls-remote --tags --heads` → fzf list.
3. **Apply Config Patch?**

   * If yes, prompt for patch file (default `./config_patch` or `templates/config_patch.example`).
4. **Build Settings**

   * Cores (`nproc`), target arch, outdir (defaults to `builds/<repo>/<ts>`).
5. **Build Progress**

   * `make -jN` | gauge (approx with `pv -l`).
6. **Artifacts Summary**

   * Show produced `Image/zImage`, `*.dtb`, `boot.img` (if any).
   * CTA: “Proceed to Flash” or “Return to Menu”.

**Logs:** `logs/<ts>-build.log` (tee).

---

## \[2] Flash Image (`wizards/flash.sh`)

**Screens & files**

1. **Pick Build Artifact**

   * fzf over `builds/**/{*.img,Image*,zImage*}` with clear labels.
2. **Select SD Card**

   * Device picker + suggested boot partition.
3. **Backup First?** (recommended)

   * If yes: choose scope (full disk vs boot partition).
4. **Flash**

   * Pipe `pv` → `dd of=/dev/sdX bs=4M conv=fsync status=progress` + gauge.
5. **Verify** (optional)

   * `cmp` or hash compare.

**Safety copy examples**

* Title: “Confirm Flash Target”
* Body: “About to write **new image** to **/dev/sdb** (64 GB, KINGSTON). This will erase existing data on selected partition(s). Proceed?”

---

## \[3] Boot.img / RootFS Adjuster (`wizards/bootimg_adjust.sh`)

**Core UX objective:** eliminate boot loops by repacking a valid boot.img from stock template + your kernel + correct DTB + sane cmdline + synced modules.

**Screens & files**

1. **Choose Base (Stock) Boot Image**

   * Options: “Extract from /dev/sdX4 now” or “Browse file…”.
   * If extracting, auto-backup to `backups/boot-<ts>.img`.
2. **Extract & Inspect** (gauge)

   * `abootimg -x` or `unmkbootimg` to `work/bootimg-<ts>/`
   * Show: `kernel`, `ramdisk.cpio.gz`, `dtb` (if any), `bootimg.cfg` (page\_size, base).
3. **Select New Kernel**

   * Browse `builds/**/Image*|zImage*`
   * Show detected version (`strings Image | grep -m1 "Linux version"`).
4. **DTB Mode**

   * Choose one:

     * **with-dt**: `mkbootimg --dt dtb.img`
     * **catdt**: `cat Image dtb.img > Image_dtb` (concatenate)
   * Then **Select DTB Variant** (from your build tree or `templates/dtb/`).
   * If multiple: build `dtb.img` (cat or `mkdtimg` per device profile).
5. **Cmdline Editor**

   * Prefill from stock `bootimg.cfg` or `templates/cmdline.example`.
   * Quick toggles: `[x] console=tty0`, `[x] ignore_loglevel`, `[ ] earlycon`.
6. **Repack new boot.img** (gauge)

   * `mkbootimg` with `--pagesize` from stock header, `--base`, `--cmdline`; enforce size ≤ boot partition.
   * Write to `builds/<repo>/<ts>/new-boot.img`.
7. **Modules Sync**

   * Detect new kernel version (`/boot/System.map` or `modinfo`).
   * If `/lib/modules/<ver>` missing on **rootfs partition**, mount it and copy from `build tree/lib/modules/<ver>`; run `depmod -a -b <mount> <ver>`.
8. **Flash boot partition**

   * Backup partition again (small) to `backups/boot-<ts>-preflash.img`.
   * Flash `new-boot.img` → `/dev/sdX4` with `dd bs=4M conv=fsync`.
9. **(Optional) QEMU Sanity Boot**

   * If enabled, run headless QEMU test and show first 200 lines of dmesg.
10. **Done screen**

* “Success. Reinsert SD into device and power-cycle.”

**Hard blocks**

* Page size mismatch? Show fix or abort.
* `new-boot.img` > partition size? Abort with hint to shrink ramdisk or strip symbols.

**Logs:** `logs/<ts>-adjust.log` (include parsed header values).

---

## \[4] Backup / Restore (`wizards/backup_restore.sh`)

**Screens & files**

1. **Scope**: Full disk vs single partition.
2. **Pick Source / Target**

   * Backup: device → file (`backups/<label>-<ts>.img.zst`).
   * Restore: file → device/partition (with double confirm).
3. **Progress** using `pv`/`dd`.
4. **Verify** (optional) hash.

---

# Patterns & file naming

* Artifacts:

  * `builds/<repo-slug>/<ts>/{Image,Image.gz,zImage,*.dtb,dtb.img,new-boot.img}`
* Backups:

  * Disk: `backups/disk-<model>-<size>-<ts>.img.zst`
  * Partition: `backups/<partlabel>-<ts>.img`
* Work dirs:

  * `work/bootimg-<ts>/` (purged on success unless `KEEP_WORK=1`)

---

# Microcopy (ui-copy.yml excerpts)

```yaml
titles:
  main: "V2 Flash Toolkit"
  pick_repo: "Select Kernel Repository"
  flash_confirm: "Confirm Flash Target"
  adjust_intro: "Boot.img / RootFS Adjuster"
warnings:
  destructive: "This action writes to a block device. Proceed only if you have a backup."
  size_mismatch: "New boot.img exceeds boot partition size."
actions:
  proceed: "Proceed"
  back: "Back"
  view_log: "View log"
  open_docs: "Open docs"
```

---

# UX safeguards & polish

* **Preflight check** on startup (`require_cmd`: git, make, pv, dd, lsblk, blkid, abootimg/mkbootimg, fzf, whiptail/gum). Missing tools → friendly installer hint (`tools/install-deps.sh`).
* **Dry run mode** (`DRY_RUN=1`) shows all commands without execution; every CTA labels `[DRY RUN]`.
* **Persistent state**: last selections saved to `.state.json` (repo URL, device path) to streamline repeat runs.
* **Help panels** (`[H]`) on key screens explain DTB modes, page size, cmdline tips.
* **Error surfaces**: show exact failing command + tail of log, never a silent fail.
* **Internationalization**: all UI strings in `ui-copy.yml`. Add `LANG=pl_PL` subset later.

---

# Developer workflow (quality gates)

* `shellcheck` and `shfmt` pre-commit.
* `bats-core` tests under `test/bats/` for:

  * lsblk parsing → device list
  * partition suggestor
  * bootimg header reader → page size/base extraction
  * command builders (mkbootimg args).
* “Simulate device” fixtures in `test/fixtures/`.
* CI job: run strict mode, tests, lint, format check.

---

# End-to-end “happy path” (user journey)

1. **Kernel Build**: pick repo → apply config patch → build with gauge → see artifacts.
2. **Flash Image**: pick .img (or raw Image) → select SD card → backup (recommended) → flash.
3. **Boot.img/RootFS Adjuster**: choose stock boot.img → extract → pick new kernel → select DTB mode & variant → tweak cmdline → repack → sync modules → flash boot partition → (optional) QEMU smoke test.
4. **Backup/Restore**: safety net at any point.

Every step is **visible**, **reversible** (backups), and **logged**.

