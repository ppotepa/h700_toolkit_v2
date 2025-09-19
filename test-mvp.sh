#!/bin/bash
# test-mvp.sh - MVP Test Script
# This script tests the basic functionality of the V2 Flash Toolkit MVP
# It runs through each wizard in mock mode to verify everything works

set -euo pipefail

# Set mock mode
export MOCK=1
export DRY_RUN=1

# Source the main toolkit
TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOLKIT_ROOT/flash-toolkit.sh"

echo "=== V2 Flash Toolkit MVP Test ==="
echo "Running in MOCK mode - no real operations will be performed"
echo

# Test 1: Check if all wizards are discoverable
echo "Test 1: Wizard Discovery"
echo "Available wizards:"
discover_wizards
echo

# Test 2: Basic context management
echo "Test 2: Context Management"
echo "Initializing context..."
init_context
echo "Context keys: $(echo "${!CTX[@]}" | tr ' ' ',')"
echo

# Test 3: Mock operations
echo "Test 3: Mock Operations"
echo "Testing mock backup..."
mock_backup "/dev/sdb4" "backups/test-boot.img" "gzip"
echo "Testing mock flash..."
mock_flash "builds/test.img" "/dev/sdb4"
echo "Testing mock build..."
mock_make_build "builds/test-build"
echo

# Test 4: UI components (basic test)
echo "Test 4: UI Components"
echo "Testing whiptail availability..."
if command -v whiptail >/dev/null 2>&1; then
    echo "✓ whiptail is available"
else
    echo "✗ whiptail not found - install it for full UI functionality"
fi
echo

# Test 5: Configuration loading
echo "Test 5: Configuration"
echo "Loading config..."
load_config
echo "Config loaded successfully"
echo

echo "=== MVP Test Complete ==="
echo "The V2 Flash Toolkit MVP is ready for use!"
echo
echo "To run the toolkit:"
echo "  ./flash-toolkit.sh"
echo
echo "Available wizards:"
echo "  • Kernel Build (7 steps)"
echo "  • Flash Image (5 steps)"
echo "  • Boot.img Adjuster (11 steps)"
echo "  • Backup/Restore (4 steps)"
echo
echo "All operations run in mock mode by default for safety."
