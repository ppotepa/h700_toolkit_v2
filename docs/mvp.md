Perfect—here’s a **minimal implementation spec** for a fully clickable TUI where every screen works, you can navigate the whole flow, and **all time-consuming actions are mocked with progress bars**. Later you’ll flip a switch to use the real functions.

# MVP Scope (Mock-First)

* All four wizards are navigable end-to-end.
* Progress bars & logs are shown for **clone/build/flash/backup/adjust**—but no real disk writes or network builds.
* Device lists, repos, artifacts, boot headers, etc. are **mocked** from fixtures.
* Toggle between **MOCK** and **REAL** with env flags (no code moves).

## Feature flags (env)

* `MOCK=1` → use mock data & delays (default in MVP).
* `DRY_RUN=1` → print real commands without executing (later).
* `THEME=light|dark` (optional).
* `WIZARD=kernel-build|flash|bootimg_adjust|backup_restore` (jump directly).
* `GOTO=ID` (e.g., `1-1-1`) to open a specific step.

---

# File/Folder Baseline (MVP)

*(unchanged from your spec; only “mocks/” added)*

```
flash-toolkit/
├─ flash-toolkit.sh
├─ .env.example
├─ config/{repos.yml,devices.yml,ui-copy.yml,safety.yml}
├─ lib/
│  ├─ base.sh     # strict mode, traps, ctx, logging
│  ├─ ui.sh       # menu/input/gauge/spinner wrappers
│  ├─ disk.sh     # IN MVP: reads fixtures (no real lsblk)
│  ├─ git.sh      # IN MVP: mocks clone/branch list
│  ├─ build.sh    # IN MVP: mocks make & artifacts
│  ├─ bootimg.sh  # IN MVP: mocks abootimg/mkbootimg
│  ├─ modules.sh  # IN MVP: mocks /lib/modules sync
│  ├─ qemu.sh     # IN MVP: mocks smoke test
│  └─ config.sh   # YAML/env loader
├─ mocks/
│  ├─ progress.sh   # progress generators (gauge/spinner)
│  ├─ data.sh       # canned lists (repos, refs, artifacts)
│  └─ fs.sh         # fake file ops (touch logs/outputs)
├─ wizards/
│  ├─ kernel_build.sh
│  ├─ flash.sh
│  ├─ bootimg_adjust.sh
│  ├─ backup_restore.sh
│  └─ kernel-build/
│     ├─ 1-0__choose_kernel_from_gh.sh
│     ├─ 1-1__pick_branch_tag.sh
│     ├─ 1-1-1__repo_health_check.sh
│     ├─ 1-2__apply_config_patch.sh
│     ├─ 2-0__build_settings.sh
│     ├─ 2-1__build_progress.sh
│     └─ 3-0__artifacts_summary.sh
├─ templates/{config_patch.example,cmdline.example,ui-theme.example}
├─ test/{bats/,fixtures/lsblk-sample.json}
├─ builds/   # mock artifacts dropped here
├─ backups/  # mock files dropped here
├─ logs/     # log per wizard run
└─ work/     # mock bootimg workdirs
```

---

# Router & Step-ID Pattern (works now)

* **Per-step files** under `wizards/<wizard>/<ID>__<slug>.sh`
* IDs are numeric segments: `1-0`, `1-1`, `1-1-1`; router sorts **numerically** by segment.
* **Anchors** in `config/safety.yml` (e.g., `1-0`) must exist; otherwise a placeholder is injected.
* **Context** `declare -Ag CTX` passed to steps; saved to `.state.json`.

---

# Mock Layer (drop-in, later swapped for real)

## mocks/progress.sh

* `mock_gauge "Title" duration_secs` → feeds `0..100` into `whiptail --gauge`.
* `mock_spinner "Message" duration_secs` → gum spinner fallback.
* `mock_chunked_gauge "Title" "phase1:40" "phase2:60"` → multi-phase %.

> Example gauge driver (concept):

```bash
mock_gauge() {
  local title="$1"; local secs="${2:-10}"
  { for i in $(seq 0 100); do echo $i; sleep "$(awk "BEGIN{print $secs/100}")"; done; } \
  | whiptail --gauge "$title" 7 60 0
}
```

## mocks/data.sh

* `mock_repos`: array of curated repo names.
* `mock_refs(repo)`: tags/branches list.
* `mock_lsblk`: echoes `test/fixtures/lsblk-sample.json`.
* `mock_artifacts(repo)`: returns Image/DTB paths (created as empty files).

## mocks/fs.sh

* `mock_touch_log wizard` → `logs/<ts>-<wizard>.log`
* `mock_make_build outdir` → creates fake files in `builds/...` + writes lines to log (for realism).
* `mock_backup path` → creates `backups/...img` and shows gauge.
* `mock_flash` / `mock_mkbootimg` / `mock_abootimg` → simulate with durations.

---

# Wizard Behavior (MVP)

All screens render and move forward/back. Every “heavy action” calls a **mock**.

## Kernel Build (mocked)

* **Clone/refs**: from `mocks/data.sh`.
* **Apply config**: no-op + short spinner.
* **Build**: create mock artifacts (Image, dtb, modules dir) + 20–60s gauge.
* **Artifacts summary**: show fake paths, enable “Go to Flash/Adjuster”.

## Flash Image (mocked)

* **Pick artifact**: lists mock files from `builds/**`.
* **Select SD card**: uses `mock_lsblk` (fixture), with Suggested boot partition.
* **Backup**: creates `backups/*.img(.zst)` + gauge.
* **Flash**: creates `backups/boot-<ts>-preflash.img` and logs; gauge simulates write.
* **Verify**: optional spinner; no actual cmp.

## Boot.img / RootFS Adjuster (mocked)

* **Choose stock boot.img**: either use a fixture or create `backups/boot-<ts>.img`.
* **Extract summary**: print canned header (page\_size=2048, base=0x40000000).
* **Select new kernel**: from mock artifacts; detect version from string template.
* **DTB mode/variant**: radio/checkbox using devices.yml.
* **Cmdline editor**: prefill from templates; accept edits (store in CTX).
* **Repack**: “mkbootimg” is mocked; drops `new-boot.img` to build folder; gauge.
* **Modules sync**: create `/mnt/rootfs/lib/modules/<ver>` mock path under temp; gauge.
* **Flash boot**: gauge only; logs describe “would dd to /dev/sdX4”.
* **QEMU**: spinner + fake dmesg snippet to log.

## Backup / Restore (mocked)

* **Backup**: create file + gauge (size from config).
* **Restore**: gauge only + log.

---

# Minimal UI Contracts (work now)

* **Menu footer**: `↑/↓ · Enter · ESC · F1 Help · F4 View log`
* **Danger screens**: double confirm; second asks to type `YES`.
* **“View log”**: opens `less` on the current wizard log.
* **Cancel**: returns to previous menu; context persists.

---

# Swapping Mocks → Real

* Every real function has the **same name** behind a shim:

  ```bash
  do_flash() { if [[ "${MOCK:-1}" == "1" ]]; then mock_flash "$@"; else real_flash "$@"; fi; }
  ```
* The wizards call only `do_*` APIs; toggling `MOCK=0` activates real ops without touching screens.
* Add `--dry-run` guard inside real ops to print commands and feed fake progress to the gauge.

---

# Acceptance Criteria (MVP)

1. **Navigation**: All screens across all wizards load and return; Back/Continue work.
2. **Progress**: Every time-consuming action shows a gauge or spinner.
3. **Safety**: Full-disk/partition writes are **never** executed in MVP. (Mocks only.)
4. **Logs**: Each run creates a log in `logs/` with timestamps and step notes.
5. **Artifacts**: `builds/` and `backups/` contain mock files after flows.
6. **Resume**: `.state.json` persists CTX; restart returns to Main Menu cleanly.

---

# MVP Task Breakdown (doable fast)

**Day 1**

* `lib/base.sh`, `lib/ui.sh` (whiptail wrappers), `mocks/progress.sh`, `mocks/data.sh`, `mocks/fs.sh`.
* Router in each wizard orchestrator + load per-step files (ID sort).

**Day 2**

* Implement all **Kernel Build** step files with mocks and logs.
* Implement **Flash** step files with device fixture + mock backup/flash.

**Day 3**

* Implement **Adjuster** step files with mock extract/mkbootimg/modules/flash.
* Implement **Backup/Restore** with mock pipelines.

**Day 4**

* Add `test/bats` basic tests: router ordering; mock guards; anchors exist.
* Polish microcopy in `config/ui-copy.yml`; theme tokens.

**Day 5**

* Add `tools/install-deps.sh`; run smoke across terminals; fix any blocking UX.

---

# Example: One Mocked Progress Call per Area

* Build: `mock_chunked_gauge "Building kernel" "prepare:10" "compile:70" "package:20"`
* Flash disk: `mock_gauge "Flashing /dev/sdb (mock)" 45`
* Backup: `mock_gauge "Creating backup (mock)" 30`
* mkbootimg: `mock_gauge "Repacking boot.img (mock)" 15`
* Modules: `mock_gauge "Syncing modules (mock)" 12`

---

# Developer Commands (MVP Demo)

```
# Run whole app in mock mode
MOCK=1 ./flash-toolkit.sh

# Jump straight to a wizard (mock)
MOCK=1 WIZARD=bootimg_adjust ./flash-toolkit.sh

# List discovered steps & order
./flash-toolkit.sh --wizard kernel-build --list

# Jump to a specific step ID (mock)
MOCK=1 WIZARD=kernel-build GOTO=1-1-1 ./flash-toolkit.sh
```

