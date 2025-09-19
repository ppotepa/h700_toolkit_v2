#!/bin/bash
# mocks/data.sh - Canned data for MVP mock operations
# This file provides static data arrays and functions for repositories, branches, artifacts, etc.
# All data is hardcoded for demonstration purposes

# Mock repositories array
# Format: "name|url|description"
mock_repos=(
    "anbernic/h700-linux|https://github.com/anbernic/h700-linux|Allwinner H700 A64 family tree + RG35XX H tweaks"
    "community/h700-kernel-tuned|https://github.com/community/h700-kernel-tuned|Community tuned kernel for H700"
    "forks/grzegorz/rx28-disp-panel|https://github.com/grzegorz/rx28-disp-panel|Fork with display panel fixes"
    "forks/karol/h700-exp-dma|https://github.com/karol/h700-exp-dma|Experimental DMA support"
)

# Mock branches/tags for a repository
# mock_refs "repo_name" -> returns array of refs
mock_refs() {
    local repo="$1"
    case "$repo" in
        "anbernic/h700-linux")
            echo "branch:main branch:rg35xxh-stable tag:v6.10.12-rg tag:v6.10.9"
            ;;
        "community/h700-kernel-tuned")
            echo "branch:main branch:performance tag:v6.10.5-tuned tag:v6.9.8-tuned"
            ;;
        "forks/grzegorz/rx28-disp-panel")
            echo "branch:main branch:dev tag:v6.10.10-panel tag:v6.9.12-panel"
            ;;
        "forks/karol/h700-exp-dma")
            echo "branch:main branch:experimental tag:v6.10.8-dma tag:v6.9.15-dma"
            ;;
        *)
            echo "branch:main tag:v6.10.0"
            ;;
    esac
}

# Mock lsblk output (simulates device listing)
# Returns JSON-like structure for device parsing
mock_lsblk() {
    cat << 'EOF'
{
  "blockdevices": [
    {
      "name": "sda",
      "size": "256G",
      "type": "disk",
      "fstype": null,
      "label": null,
      "model": "SAMSUNG SSD",
      "path": "/dev/sda",
      "children": [
        {
          "name": "sda1",
          "size": "512M",
          "type": "part",
          "fstype": "vfat",
          "label": "EFI",
          "path": "/dev/sda1"
        },
        {
          "name": "sda2",
          "size": "237G",
          "type": "part",
          "fstype": "ext4",
          "label": null,
          "path": "/dev/sda2"
        }
      ]
    },
    {
      "name": "sdb",
      "size": "64G",
      "type": "disk",
      "fstype": null,
      "label": null,
      "model": "KINGSTON SD",
      "path": "/dev/sdb",
      "children": [
        {
          "name": "sdb1",
          "size": "512M",
          "type": "part",
          "fstype": "vfat",
          "label": "BOOT",
          "path": "/dev/sdb1"
        },
        {
          "name": "sdb4",
          "size": "64M",
          "type": "part",
          "fstype": "ext4",
          "label": "boot",
          "path": "/dev/sdb4"
        },
        {
          "name": "sdb5",
          "size": "12G",
          "type": "part",
          "fstype": "ext4",
          "label": "rootfs",
          "path": "/dev/sdb5"
        }
      ]
    }
  ]
}
EOF
}

# Mock artifacts for a repository
# mock_artifacts "repo_name" -> creates and returns paths to fake artifacts
mock_artifacts() {
    local repo="$1"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local build_dir="builds/${repo//\//-}/$timestamp"

    # Create build directory
    mkdir -p "$build_dir"

    # Create mock artifacts
    touch "$build_dir/Image"
    touch "$build_dir/Image.gz"
    touch "$build_dir/zImage"
    touch "$build_dir/sun50i-h700-anbernic-rg35xx-h.dtb"
    touch "$build_dir/sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb"
    touch "$build_dir/modules.tar.gz"

    # Create modules directory structure
    mkdir -p "$build_dir/lib/modules/6.10.12-rg"
    touch "$build_dir/lib/modules/6.10.12-rg/modules.dep"

    echo "$build_dir"
}

# Mock boot image header information
mock_bootimg_header() {
    cat << 'EOF'
page_size=2048
base=0x40000000
cmdline=console=ttyS0,115200 console=tty0 root=/dev/mmcblk0p5 rw
EOF
}

# Mock kernel version detection
mock_kernel_version() {
    local kernel_path="$1"
    echo "6.10.12-rg"
}

# Mock device profiles (from config/devices.yml)
mock_device_profiles() {
    cat << 'EOF'
RG35XX-H:
  soc: Allwinner H700
  page_size: 2048
  base: 0x40000000
  dtb_mode: with-dt
  boot_part: /dev/sdb4
  rootfs_part: /dev/sdb5
EOF
}

# Mock QEMU boot test output
mock_qemu_output() {
    cat << 'EOF'
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
[    0.000000] Linux version 6.10.12-rg (mock@build) (gcc (GCC) 12.2.0, GNU ld (GNU Binutils) 2.39) #1 SMP PREEMPT Wed Sep 18 12:00:00 UTC 2025
[    0.000000] Machine model: Allwinner H700
[    0.000000] earlycon: Early serial console at MMIO32 0x0 (options '')
[    0.000000] printk: bootconsole [earlycon0] enabled
[    0.100000] Decompressing Linux... done, booting the kernel.
[    0.200000] Memory: 512MB = 512MB total
[    0.300000] Mount root filesystem... done
[    0.400000] Init system started successfully
[    0.500000] Kernel boot test PASSED
EOF
}
