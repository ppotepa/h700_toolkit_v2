#!/bin/bash
# lib/config.sh - Configuration management for V2 Flash Toolkit
# This file handles loading and parsing of YAML configuration files and environment variables
# Provides functions to access configuration data throughout the application

# Source base functions if not already loaded
if ! declare -f log >/dev/null 2>&1; then
    source "$(dirname "${BASH_SOURCE[0]}")/base.sh"
fi

# Configuration arrays (associative arrays for key-value storage)
declare -Ag CONFIG_REPOS
declare -Ag CONFIG_DEVICES
declare -Ag CONFIG_UI_COPY
declare -Ag CONFIG_SAFETY

# load_yaml_config "file_path" "target_array"
# Loads a YAML file into an associative array
# Note: This is a basic YAML parser for simple key-value structures
load_yaml_config() {
    local file_path="$1"
    local target_array="$2"
    local current_key=""
    local in_array=false
    local array_items=()

    if [[ ! -f "$file_path" ]]; then
        log "Configuration file not found: $file_path" "ERROR"
        return 1
    fi

    log "Loading configuration from $file_path" "DEBUG"

    # Read file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Remove leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Handle array items (lines starting with -)
        if [[ "$line" =~ ^-[[:space:]] ]]; then
            if [[ "$in_array" == true ]]; then
                local item="${line:1}"
                item="${item#"${item%%[![:space:]]*}"}"
                array_items+=("$item")
            fi
            continue
        fi

        # Handle key-value pairs
        if [[ "$line" =~ ^[[:space:]]*([^:]+):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Check if this starts an array
            if [[ "$value" == "" ]]; then
                in_array=true
                current_key="$key"
                array_items=()
            else
                # Store key-value pair
                eval "$target_array[\"$key\"]=\"$value\""
                in_array=false
            fi
        fi
    done < "$file_path"

    # Store array data if we were in an array
    if [[ "$in_array" == true && ${#array_items[@]} -gt 0 ]]; then
        eval "$target_array[\"$current_key\"]=\"${array_items[*]}\""
    fi

    log "Configuration loaded successfully from $file_path" "DEBUG"
}

# load_env_config
# Loads configuration from environment variables and .env file
load_env_config() {
    # Load .env file if it exists
    if [[ -f ".env" ]]; then
        log "Loading environment from .env file" "DEBUG"
        set -a  # Automatically export all variables
        source .env
        set +a
    fi

    # Set defaults for environment variables
    export MOCK="${MOCK:-1}"
    export DRY_RUN="${DRY_RUN:-0}"
    export THEME="${THEME:-default}"
    export WIZARD="${WIZARD:-}"
    export GOTO="${GOTO:-}"
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"

    log "Environment configuration loaded" "DEBUG"
    log "MOCK=$MOCK, DRY_RUN=$DRY_RUN, THEME=$THEME" "DEBUG"
}

# init_config
# Initializes all configuration by loading files and environment
init_config() {
    log "Initializing configuration system" "INFO"

    # Load environment configuration first
    load_env_config

    # Load YAML configuration files
    load_yaml_config "config/repos.yml" "CONFIG_REPOS"
    load_yaml_config "config/devices.yml" "CONFIG_DEVICES"
    load_yaml_config "config/ui-copy.yml" "CONFIG_UI_COPY"
    load_yaml_config "config/safety.yml" "CONFIG_SAFETY"

    log "Configuration initialization complete" "INFO"
}

# Configuration access functions

# get_config_value "section" "key"
# Gets a configuration value from the specified section
get_config_value() {
    local section="$1"
    local key="$2"
    local array_name="CONFIG_${section^^}"

    # Check if the array exists
    if ! declare -p "$array_name" >/dev/null 2>&1; then
        log "Configuration section not found: $section" "WARN"
        return 1
    fi

    # Get the value
    local value
    eval "value=\${$array_name[\"$key\"]}"

    if [[ -z "$value" ]]; then
        log "Configuration key not found: $section.$key" "DEBUG"
        return 1
    fi

    echo "$value"
}

# get_repos_list
# Returns a list of available repositories
get_repos_list() {
    local repos=()
    for key in "${!CONFIG_REPOS[@]}"; do
        if [[ "$key" =~ ^[^/]+/[^/]+$ ]]; then
            repos+=("$key")
        fi
    done
    echo "${repos[@]}"
}

# get_repo_info "repo_name" "field"
# Gets specific information about a repository
get_repo_info() {
    local repo="$1"
    local field="$2"
    local key="${repo}_${field}"

    get_config_value "REPOS" "$key"
}

# get_device_info "device_name" "field"
# Gets specific information about a device
get_device_info() {
    local device="$1"
    local field="$2"
    local key="${device}_${field}"

    get_config_value "DEVICES" "$key"
}

# get_ui_copy "key"
# Gets UI copy/text for the specified key
get_ui_copy() {
    local key="$1"

    get_config_value "UI_COPY" "$key"
}

# get_safety_setting "key"
# Gets safety configuration for the specified key
get_safety_setting() {
    local key="$1"

    get_config_value "SAFETY" "$key"
}

# validate_config
# Validates that all required configuration is present
validate_config() {
    local errors=()

    # Check for required repositories
    if [[ ${#CONFIG_REPOS[@]} -eq 0 ]]; then
        errors+=("No repositories configured in config/repos.yml")
    fi

    # Check for required devices
    if [[ ${#CONFIG_DEVICES[@]} -eq 0 ]]; then
        errors+=("No devices configured in config/devices.yml")
    fi

    # Check for required UI copy
    if [[ ${#CONFIG_UI_COPY[@]} -eq 0 ]]; then
        errors+=("No UI copy configured in config/ui-copy.yml")
    fi

    # Report errors
    if [[ ${#errors[@]} -gt 0 ]]; then
        log "Configuration validation failed:" "ERROR"
        for error in "${errors[@]}"; do
            log "  - $error" "ERROR"
        done
        return 1
    fi

    log "Configuration validation passed" "DEBUG"
    return 0
}

# dump_config
# Dumps current configuration for debugging
dump_config() {
    log "=== Configuration Dump ===" "DEBUG"

    log "Environment:" "DEBUG"
    log "  MOCK=$MOCK" "DEBUG"
    log "  DRY_RUN=$DRY_RUN" "DEBUG"
    log "  THEME=$THEME" "DEBUG"
    log "  WIZARD=$WIZARD" "DEBUG"
    log "  GOTO=$GOTO" "DEBUG"
    log "  LOG_LEVEL=$LOG_LEVEL" "DEBUG"

    log "Repositories (${#CONFIG_REPOS[@]}):" "DEBUG"
    for key in "${!CONFIG_REPOS[@]}"; do
        log "  $key = ${CONFIG_REPOS[$key]}" "DEBUG"
    done

    log "Devices (${#CONFIG_DEVICES[@]}):" "DEBUG"
    for key in "${!CONFIG_DEVICES[@]}"; do
        log "  $key = ${CONFIG_DEVICES[$key]}" "DEBUG"
    done

    log "UI Copy (${#CONFIG_UI_COPY[@]}):" "DEBUG"
    for key in "${!CONFIG_UI_COPY[@]}"; do
        log "  $key = ${CONFIG_UI_COPY[$key]}" "DEBUG"
    done

    log "Safety (${#CONFIG_SAFETY[@]}):" "DEBUG"
    for key in "${!CONFIG_SAFETY[@]}"; do
        log "  $key = ${CONFIG_SAFETY[$key]}" "DEBUG"
    done

    log "=== End Configuration Dump ===" "DEBUG"
}

# Export configuration functions
export -f load_yaml_config load_env_config init_config
export -f get_config_value get_repos_list get_repo_info
export -f get_device_info get_ui_copy get_safety_setting
export -f validate_config dump_config
