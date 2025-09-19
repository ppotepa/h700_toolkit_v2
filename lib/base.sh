#!/bin/bash
# lib/base.sh - Core base functions for V2 Flash Toolkit
# This file provides fundamental utilities, error handling, logging, and context management
# All wizards and steps should source this file

# Enable strict mode for better error handling
set -euo pipefail

# Trap errors and interrupts for cleanup
trap 'error_handler $? $LINENO $BASH_COMMAND' ERR
trap 'interrupt_handler' INT TERM

# Global variables
TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLKIT_NAME="V2 Flash Toolkit"
TOOLKIT_VERSION="0.1.0-mvp"

# Context array for passing data between steps
# Usage: CTX[key]=value
declare -Ag CTX

# Logging functions
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"

# log "message" "level"
# Logs a message with timestamp and level
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if level should be logged
    case "$LOG_LEVEL" in
        ERROR) [[ "$level" != "ERROR" ]] && return ;;
        WARN) [[ "$level" =~ ^(DEBUG|INFO)$ ]] && return ;;
        INFO) [[ "$level" == "DEBUG" ]] && return ;;
        DEBUG) ;; # Log everything
    esac

    local log_entry="[$timestamp] [$level] $message"

    # Log to file if specified
    if [[ -n "$LOG_FILE" ]]; then
        echo "$log_entry" >> "$LOG_FILE"
    fi

    # Always log to stderr for ERROR and WARN
    if [[ "$level" =~ ^(ERROR|WARN)$ ]]; then
        echo "$log_entry" >&2
    else
        echo "$log_entry"
    fi
}

# error_handler "exit_code" "line_number" "command"
# Called when a command fails (via ERR trap)
error_handler() {
    local exit_code="$1"
    local line_number="$2"
    local command="$3"

    log "Command failed (exit $exit_code) at line $line_number: $command" "ERROR"

    # Clean up any temporary files
    cleanup_temp_files

    # Show error to user if in interactive mode
    if [[ -t 1 ]]; then
        echo "An error occurred. Check the logs for details." >&2
        echo "Press Enter to continue..."
        read -r
    fi

    exit "$exit_code"
}

# interrupt_handler
# Called when script is interrupted (Ctrl+C)
interrupt_handler() {
    log "Script interrupted by user" "WARN"

    # Save current context before exit
    save_context

    # Clean up
    cleanup_temp_files

    echo "Interrupted. Context saved." >&2
    exit 130  # Standard interrupt exit code
}

# Directory setup and validation
setup_directories() {
    # Create essential directories
    mkdir -p logs builds backups work

    log "Directories verified/created: logs, builds, backups, work" "DEBUG"
}

# Context management functions
# save_context
# Saves the current CTX array to .state.json
save_context() {
    local state_file=".state.json"

    # Convert associative array to JSON-like format
    local json="{"
    local first=true

    for key in "${!CTX[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            json+=","
        fi
        json+="\"$key\":\"${CTX[$key]}\""
    done
    json+="}"

    echo "$json" > "$state_file"
    log "Context saved to $state_file" "DEBUG"
}

# load_context
# Loads context from .state.json into CTX array
load_context() {
    local state_file=".state.json"

    if [[ -f "$state_file" ]]; then
        # Simple JSON parsing (basic implementation)
        local content
        content=$(cat "$state_file")

        # Extract key-value pairs (very basic parsing)
        while [[ $content =~ \"([^\"]+)\":\"([^\"]+)\" ]]; do
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            CTX["$key"]="$value"
            content="${content#*\",}"
        done

        log "Context loaded from $state_file" "DEBUG"
    else
        log "No previous state file found, starting fresh" "DEBUG"
    fi
}

# clear_context
# Clears all context data
clear_context() {
    CTX=()
    log "Context cleared" "DEBUG"
}

# Utility functions
# require_command "command_name"
# Checks if a command is available, exits if not
require_command() {
    local cmd="$1"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "Required command '$cmd' not found" "ERROR"
        echo "Error: '$cmd' command is required but not found." >&2
        echo "Please install it or check your PATH." >&2
        exit 1
    fi

    log "Command '$cmd' found at $(command -v "$cmd")" "DEBUG"
}

# cleanup_temp_files
# Cleans up any temporary files created during execution
cleanup_temp_files() {
    # Remove any .tmp files in work directory
    if [[ -d work ]]; then
        find work -name "*.tmp" -type f -delete 2>/dev/null || true
        log "Cleaned up temporary files" "DEBUG"
    fi
}

# get_timestamp
# Returns a timestamp string for file naming
get_timestamp() {
    date +%Y%m%d-%H%M%S
}

# validate_file_exists "file_path" "description"
# Validates that a file exists, logs error if not
validate_file_exists() {
    local file_path="$1"
    local description="${2:-file}"

    if [[ ! -f "$file_path" ]]; then
        log "$description not found: $file_path" "ERROR"
        return 1
    fi

    log "$description found: $file_path" "DEBUG"
    return 0
}

# validate_directory_exists "dir_path" "description"
# Validates that a directory exists, logs error if not
validate_directory_exists() {
    local dir_path="$1"
    local description="${2:-directory}"

    if [[ ! -d "$dir_path" ]]; then
        log "$description not found: $dir_path" "ERROR"
        return 1
    fi

    log "$description found: $dir_path" "DEBUG"
    return 0
}

# Mock vs Real mode detection
is_mock_mode() {
    [[ "${MOCK:-1}" == "1" ]]
}

is_dry_run_mode() {
    [[ "${DRY_RUN:-0}" == "1" ]]
}

# Initialize the base system
init_base() {
    log "Initializing $TOOLKIT_NAME v$TOOLKIT_VERSION" "INFO"

    # Set up directories
    setup_directories

    # Load previous context
    load_context

    # Check for required commands (basic set)
    require_command whiptail  # For UI
    require_command jq        # For JSON processing (if available)

    log "Base initialization complete" "INFO"
}

# Export functions for use in other scripts
export -f log save_context load_context clear_context
export -f require_command cleanup_temp_files get_timestamp
export -f validate_file_exists validate_directory_exists
export -f is_mock_mode is_dry_run_mode
