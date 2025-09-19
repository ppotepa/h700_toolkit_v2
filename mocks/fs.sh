#!/bin/bash
# mocks/fs.sh - Fake file operations for MVP
# This file provides simulated file system operations that create mock files and directories
# All operations are safe and don't affect real system files

# mock_touch_log "wizard_name"
# Creates a timestamped log file for the wizard
mock_touch_log() {
    local wizard="$1"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local log_file="logs/${timestamp}-${wizard}.log"

    # Create logs directory if it doesn't exist
    mkdir -p logs

    # Create log file with initial entries
    cat > "$log_file" << EOF
$(date '+%Y-%m-%d %H:%M:%S') Starting $wizard wizard (MOCK MODE)
$(date '+%Y-%m-%d %H:%M:%S') All operations are simulated
EOF

    echo "$log_file"
}

# mock_make_build "outdir"
# Simulates a kernel build by creating fake artifacts and writing build log entries
mock_make_build() {
    local outdir="$1"
    local log_file
    log_file=$(mock_touch_log "kernel_build")

    # Create output directory
    mkdir -p "$outdir"

    # Simulate build phases with log entries
    echo "$(date '+%Y-%m-%d %H:%M:%S') Preparing build environment..." >> "$log_file"
    sleep 1

    echo "$(date '+%Y-%m-%d %H:%M:%S') Configuring kernel with defconfig..." >> "$log_file"
    sleep 1

    echo "$(date '+%Y-%m-%d %H:%M:%S') Building kernel (make -j8)..." >> "$log_file"
    sleep 2

    # Create mock build artifacts
    touch "$outdir/.config"
    touch "$outdir/Image"
    touch "$outdir/Image.gz"
    touch "$outdir/zImage"
    touch "$outdir/sun50i-h700-anbernic-rg35xx-h.dtb"
    touch "$outdir/sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb"

    # Create modules directory
    mkdir -p "$outdir/lib/modules/6.10.12-rg"
    touch "$outdir/lib/modules/6.10.12-rg/modules.dep"
    touch "$outdir/lib/modules/6.10.12-rg/modules.alias"

    echo "$(date '+%Y-%m-%d %H:%M:%S') Build completed successfully" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Artifacts created in $outdir" >> "$log_file"

    echo "$outdir"
}

# mock_backup "source_path" "dest_file" "compression"
# Simulates creating a backup with optional compression
mock_backup() {
    local source="$1"
    local dest="$2"
    local compression="${3:-none}"
    local log_file
    log_file=$(mock_touch_log "backup")

    # Create backups directory
    mkdir -p backups

    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting backup of $source" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Compression: $compression" >> "$log_file"

    # Simulate backup creation
    case "$compression" in
        "zstd")
            touch "$dest.zst"
            echo "$(date '+%Y-%m-%d %H:%M:%S') Created compressed backup: $dest.zst" >> "$log_file"
            ;;
        "gzip")
            touch "$dest.gz"
            echo "$(date '+%Y-%m-%d %H:%M:%S') Created compressed backup: $dest.gz" >> "$log_file"
            ;;
        *)
            touch "$dest"
            echo "$(date '+%Y-%m-%d %H:%M:%S') Created uncompressed backup: $dest" >> "$log_file"
            ;;
    esac

    echo "$dest"
}

# mock_flash "image_path" "device_path"
# Simulates flashing an image to a device
mock_flash() {
    local image="$1"
    local device="$2"
    local log_file
    log_file=$(mock_touch_log "flash")

    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting flash of $image to $device" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: This is a MOCK operation - no real data written" >> "$log_file"

    # Simulate flash process
    sleep 2

    echo "$(date '+%Y-%m-%d %H:%M:%S') Flash completed successfully (simulated)" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Would have run: dd if=$image of=$device bs=4M conv=fsync" >> "$log_file"
}

# mock_abootimg_extract "bootimg_path" "outdir"
# Simulates extracting a boot image
mock_abootimg_extract() {
    local bootimg="$1"
    local outdir="$2"
    local log_file
    log_file=$(mock_touch_log "bootimg_extract")

    # Create output directory
    mkdir -p "$outdir"

    echo "$(date '+%Y-%m-%d %H:%M:%S') Extracting boot image $bootimg" >> "$log_file"

    # Create mock extracted files
    touch "$outdir/kernel"
    touch "$outdir/ramdisk.cpio.gz"
    touch "$outdir/second"  # Optional second stage
    touch "$outdir/dtb"     # Device tree blob
    touch "$outdir/bootimg.cfg"

    # Create mock bootimg.cfg
    cat > "$outdir/bootimg.cfg" << 'EOF'
page_size=2048
base=0x40000000
cmdline=console=ttyS0,115200 console=tty0 root=/dev/mmcblk0p5 rw
EOF

    echo "$(date '+%Y-%m-%d %H:%M:%S') Extraction completed" >> "$log_file"
    echo "$outdir"
}

# mock_mkbootimg "kernel" "ramdisk" "dtb" "cmdline" "output"
# Simulates creating a boot image
mock_mkbootimg() {
    local kernel="$1"
    local ramdisk="$2"
    local dtb="$3"
    local cmdline="$4"
    local output="$5"
    local log_file
    log_file=$(mock_touch_log "mkbootimg")

    echo "$(date '+%Y-%m-%d %H:%M:%S') Creating boot image" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Kernel: $kernel" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Ramdisk: $ramdisk" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') DTB: $dtb" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Cmdline: $cmdline" >> "$log_file"

    # Create mock output file
    mkdir -p "$(dirname "$output")"
    touch "$output"

    echo "$(date '+%Y-%m-%d %H:%M:%S') Boot image created: $output" >> "$log_file"
    echo "$output"
}

# mock_modules_sync "modules_dir" "rootfs_mount"
# Simulates syncing kernel modules to root filesystem
mock_modules_sync() {
    local modules_dir="$1"
    local rootfs_mount="$2"
    local log_file
    log_file=$(mock_touch_log "modules_sync")

    echo "$(date '+%Y-%m-%d %H:%M:%S') Syncing modules from $modules_dir to $rootfs_mount" >> "$log_file"

    # Simulate module copying
    sleep 1

    echo "$(date '+%Y-%m-%d %H:%M:%S') Running depmod (simulated)" >> "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Modules sync completed" >> "$log_file"
}

# mock_qemu_test "bootimg_path"
# Simulates QEMU boot test
mock_qemu_test() {
    local bootimg="$1"
    local log_file
    log_file=$(mock_touch_log "qemu_test")

    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting QEMU boot test for $bootimg" >> "$log_file"

    # Simulate QEMU output
    sleep 2

    cat >> "$log_file" << 'EOF'
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
[    0.000000] Linux version 6.10.12-rg (mock@build) (gcc (GCC) 12.2.0, GNU ld (GNU Binutils) 2.39) #1 SMP PREEMPT Wed Sep 18 12:00:00 UTC 2025
[    0.000000] Machine model: Allwinner H700
[    0.100000] Decompressing Linux... done, booting the kernel.
[    0.200000] Memory: 512MB = 512MB total
[    0.300000] Mount root filesystem... done
[    0.400000] Init system started successfully
[    0.500000] Kernel boot test PASSED
EOF

    echo "$(date '+%Y-%m-%d %H:%M:%S') QEMU test completed successfully" >> "$log_file"
}
