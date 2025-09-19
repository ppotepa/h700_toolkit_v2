# V2 Flash Toolkit MVP

A terminal-based toolkit for flashing and managing Allwinner H700 devices (like RG35XX-H), built with Bash and whiptail.

## Overview

This MVP provides a working maquette of the V2 Flash Toolkit with four main wizards:

- **Kernel Build** (7 steps) - Build custom kernels from GitHub repositories
- **Flash Image** (5 steps) - Flash pre-built images to device partitions
- **Boot.img Adjuster** (11 steps) - Extract, modify, and repack boot images
- **Backup/Restore** (4 steps) - Backup and restore device partitions

All operations run in **mock mode by default** for safety during development and testing.

## Features

- **Safe Mock Operations**: All dangerous operations (flashing, partitioning) are simulated
- **Progress Bars**: Visual feedback for long-running operations
- **Context Persistence**: Wizard state is saved and can be resumed
- **Comprehensive Logging**: All operations are logged with timestamps
- **Modular Architecture**: Easy to extend with new wizards and steps
- **Environment Controls**: Toggle mock/real modes with environment variables

## Quick Start

### Prerequisites

- Bash 4+
- whiptail (for TUI)
- Standard Unix tools (dd, find, etc.)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd h700_toolkit_v2

# Make executable
chmod +x flash-toolkit.sh
```

### Running

```bash
# Run the main toolkit
./flash-toolkit.sh

# Run MVP test
./test-mvp.sh
```

## Environment Variables

Control toolkit behavior with these variables:

```bash
# Mock mode (default: enabled)
export MOCK=1          # Enable mock operations
export MOCK=0          # Disable mock operations

# Dry run mode
export DRY_RUN=1       # Show commands without executing
export DRY_RUN=0       # Execute commands normally

# Verbose logging
export VERBOSE=1       # Enable verbose logging
export VERBOSE=0       # Disable verbose logging
```

## Architecture

### Core Components

- `flash-toolkit.sh` - Main entry point with router
- `lib/base.sh` - Core utilities (logging, context, error handling)
- `lib/ui.sh` - Whiptail UI wrappers
- `lib/config.sh` - Configuration loading
- `mocks/` - Mock implementations for safe testing
- `wizards/` - Wizard orchestrators and step files

### Wizard Structure

Each wizard follows this pattern:

```
wizards/
├── wizard_name.sh              # Orchestrator with step functions
└── wizard_name/
    ├── 1-0__step_name.sh       # Individual step files
    ├── 2-0__another_step.sh
    └── ...
```

### Context Management

Wizard state is stored in the `CTX` associative array and persisted to `.state.json`:

```bash
# Access context variables
echo "${CTX[wizard_name]}"
echo "${CTX[current_step]}"

# Context is automatically saved between steps
```

## Wizards

### Kernel Build Wizard

Builds custom kernels from GitHub repositories:

1. Choose kernel repository
2. Select branch/tag
3. Configure build options
4. Build kernel
5. Build modules
6. Package artifacts
7. Summary

### Flash Image Wizard

Flashes pre-built images to device partitions:

1. Pick build artifact
2. Select target device
3. Create safety backup
4. Flash image
5. Verify installation

### Boot.img Adjuster Wizard

Extracts, modifies, and repacks boot images:

1. Choose base boot image
2. Extraction summary
3. Select new kernel
4. Choose DTB mode
5. Select DTB variants
6. Edit kernel cmdline
7. Repack boot image
8. Sync kernel modules
9. Flash boot partition
10. Optional QEMU test
11. Completion

### Backup/Restore Wizard

Manages device partition backups:

1. Choose action (backup/restore)
2. Select partitions
3. Execute operation
4. Completion

## Mock Framework

All dangerous operations are mocked for safety:

- **File Operations**: `mock_backup()`, `mock_flash()`, `mock_make_build()`
- **Data Sources**: `mock_repos()`, `mock_lsblk()`, `mock_artifacts()`
- **Progress Feedback**: `mock_gauge()`, `mock_spinner()`

Mock files are created in these directories:
- `builds/` - Build artifacts
- `backups/` - Backup images
- `logs/` - Operation logs
- `work/` - Working directories

## Development

### Adding a New Wizard

1. Create `wizards/new_wizard.sh` with step functions
2. Create `wizards/new_wizard/` directory
3. Add step files with ID-based naming
4. Update router in `flash-toolkit.sh`

### Adding Mock Functions

Add to `mocks/fs.sh` or `mocks/data.sh`:

```bash
# Mock function example
mock_new_operation() {
    local param="$1"
    local log_file
    log_file=$(mock_touch_log "new_operation")

    echo "Mocking new operation..." >> "$log_file"
    # Create mock artifacts
    touch "mock_output_$param"
}
```

### Testing

Run the MVP test suite:

```bash
./test-mvp.sh
```

This verifies:
- Wizard discovery
- Context management
- Mock operations
- UI components
- Configuration loading

## Safety Features

- **Mock Mode Default**: All operations are safe by default
- **Safety Backups**: Automatic backups before destructive operations
- **Double Confirmation**: Dangerous operations require explicit confirmation
- **Comprehensive Logging**: All operations are logged for debugging
- **Error Recovery**: Context persistence allows resuming after errors

## Future Development

This MVP serves as a foundation for the full implementation:

- Replace mock functions with real operations
- Add device-specific profiles
- Implement advanced features (OTA updates, etc.)
- Add comprehensive testing
- Create installation packages

## Troubleshooting

### Common Issues

**"whiptail not found"**
```bash
# Install whiptail
sudo apt-get install whiptail  # Ubuntu/Debian
sudo yum install newt          # CentOS/RHEL
```

**"Permission denied"**
```bash
chmod +x flash-toolkit.sh
chmod +x test-mvp.sh
```

**Mock files not created**
- Check write permissions in current directory
- Ensure `builds/`, `backups/`, `logs/` directories exist

### Logs

Check logs in the `logs/` directory:
```bash
ls logs/
cat logs/latest.log
```

## Contributing

This MVP includes extensive comments and documentation to guide future development. Each file contains:

- Function documentation
- Implementation notes
- Future extension points
- Safety considerations

## License

[Add license information]
