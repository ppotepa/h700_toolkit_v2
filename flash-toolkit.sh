#!/bin/bash
# flash-toolkit.sh - Main entrypoint for V2 Flash Toolkit
# This script implements the router mechanism for navigating between wizards and steps
# Handles environment variables, step discovery, and context management

# Enable strict mode
set -euo pipefail

# Get the absolute path of the toolkit root
TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TOOLKIT_ROOT

# Load core libraries
source "$TOOLKIT_ROOT/lib/base.sh"
source "$TOOLKIT_ROOT/lib/ui.sh"
source "$TOOLKIT_ROOT/lib/config.sh"

# Initialize the system
init_base
init_config

# Validate configuration
if ! validate_config; then
    log "Configuration validation failed, exiting" "ERROR"
    exit 1
fi

# Global variables for router
declare -a AVAILABLE_WIZARDS
declare -A WIZARD_STEPS
CURRENT_WIZARD=""
CURRENT_STEP=""

# discover_wizards
# Discovers available wizards by scanning the wizards/ directory
discover_wizards() {
    log "Discovering available wizards" "DEBUG"

    AVAILABLE_WIZARDS=(
        "kernel-build:Kernel Build"
        "flash:Flash Image"
        "bootimg_adjust:Boot.img / RootFS Adjuster"
        "backup_restore:Backup / Restore"
    )

    log "Found ${#AVAILABLE_WIZARDS[@]} wizards" "DEBUG"
}

# discover_steps "wizard_name"
# Discovers and sorts steps for a given wizard
discover_steps() {
    local wizard="$1"
    local wizard_dir="$TOOLKIT_ROOT/wizards"

    log "Discovering steps for wizard: $wizard" "DEBUG"

    # Clear previous steps
    WIZARD_STEPS=()

    # Find all step files for this wizard
    local step_files
    mapfile -t step_files < <(find "$wizard_dir" -name "*__*.sh" -type f | sort)

    # Parse step IDs and sort them
    local step_ids=()
    local step_paths=()

    for step_file in "${step_files[@]}"; do
        # Extract step ID from filename (e.g., "1-0__choose_kernel_from_gh.sh" -> "1-0")
        local filename
        filename=$(basename "$step_file")
        local step_id="${filename%%__*}"

        # Validate step ID format (numeric segments separated by hyphens)
        if [[ "$step_id" =~ ^[0-9]+(-[0-9]+)*$ ]]; then
            step_ids+=("$step_id")
            step_paths+=("$step_file")
        else
            log "Invalid step ID format: $step_id in $filename" "WARN"
        fi
    done

    # Sort step IDs numerically
    local sorted_indices
    mapfile -t sorted_indices < <(
        for i in "${!step_ids[@]}"; do
            echo "$i ${step_ids[$i]}"
        done | sort -k2 -V | cut -d' ' -f1
    )

    # Store sorted steps
    for idx in "${sorted_indices[@]}"; do
        local step_id="${step_ids[$idx]}"
        local step_path="${step_paths[$idx]}"
        WIZARD_STEPS["$step_id"]="$step_path"
        log "Found step: $step_id -> $step_path" "DEBUG"
    done

    log "Discovered ${#WIZARD_STEPS[@]} steps for wizard $wizard" "DEBUG"
}

# run_step "step_id" "wizard_name"
# Executes a specific step
run_step() {
    local step_id="$1"
    local wizard_name="$2"
    local step_path="${WIZARD_STEPS[$step_id]}"

    if [[ -z "$step_path" ]]; then
        log "Step not found: $step_id" "ERROR"
        ui_msgbox "Error" "Step $step_id not found for wizard $wizard_name"
        return 1
    fi

    if [[ ! -f "$step_path" ]]; then
        log "Step file not found: $step_path" "ERROR"
        ui_msgbox "Error" "Step file not found: $step_path"
        return 1
    fi

    log "Running step: $step_id ($step_path)" "INFO"

    # Set current step context
    CURRENT_STEP="$step_id"

    # Source the step file (it should define functions and handle execution)
    source "$step_path"

    # The step file should define a function named after the step
    local step_function="${wizard_name}_${step_id//-/_}"

    if declare -f "$step_function" >/dev/null 2>&1; then
        # Run the step function
        if "$step_function"; then
            log "Step completed successfully: $step_id" "INFO"
            return 0
        else
            log "Step failed: $step_id" "ERROR"
            return 1
        fi
    else
        log "Step function not found: $step_function" "ERROR"
        ui_msgbox "Error" "Step function $step_function not defined in $step_path"
        return 1
    fi
}

# get_next_step "current_step_id"
# Returns the next step ID in sequence
get_next_step() {
    local current="$1"
    local next_step=""

    # Find current step in sorted order
    local sorted_steps
    mapfile -t sorted_steps < <(
        for step in "${!WIZARD_STEPS[@]}"; do
            echo "$step"
        done | sort -V
    )

    local found_current=false
    for step in "${sorted_steps[@]}"; do
        if [[ "$found_current" == true ]]; then
            next_step="$step"
            break
        fi
        if [[ "$step" == "$current" ]]; then
            found_current=true
        fi
    done

    echo "$next_step"
}

# get_previous_step "current_step_id"
# Returns the previous step ID in sequence
get_previous_step() {
    local current="$1"
    local prev_step=""

    # Find current step in sorted order
    local sorted_steps
    mapfile -t sorted_steps < <(
        for step in "${!WIZARD_STEPS[@]}"; do
            echo "$step"
        done | sort -V
    )

    local previous=""
    for step in "${sorted_steps[@]}"; do
        if [[ "$step" == "$current" ]]; then
            prev_step="$previous"
            break
        fi
        previous="$step"
    done

    echo "$prev_step"
}

# run_wizard "wizard_name"
# Runs a complete wizard from start to finish
run_wizard() {
    local wizard_name="$1"

    log "Starting wizard: $wizard_name" "INFO"

    # Set current wizard
    CURRENT_WIZARD="$wizard_name"

    # Discover steps for this wizard
    discover_steps "$wizard_name"

    if [[ ${#WIZARD_STEPS[@]} -eq 0 ]]; then
        log "No steps found for wizard: $wizard_name" "ERROR"
        ui_msgbox "Error" "No steps found for wizard $wizard_name"
        return 1
    fi

    # Get first step
    local first_step
    first_step=$(printf '%s\n' "${!WIZARD_STEPS[@]}" | sort -V | head -1)

    if [[ -z "$first_step" ]]; then
        log "Could not determine first step" "ERROR"
        return 1
    fi

    # Run steps in sequence
    local current_step="$first_step"
    while [[ -n "$current_step" ]]; do
        log "Running step: $current_step" "DEBUG"

        if ! run_step "$current_step" "$wizard_name"; then
            log "Step failed, stopping wizard" "WARN"
            break
        fi

        # Check if wizard should continue
        if [[ "${CTX[continue]:-true}" != "true" ]]; then
            log "Wizard stopped by user request" "INFO"
            break
        fi

        # Get next step
        current_step=$(get_next_step "$current_step")

        if [[ -z "$current_step" ]]; then
            log "Wizard completed successfully" "INFO"
            ui_msgbox "Completed" "Wizard $wizard_name completed successfully!"
            break
        fi
    done

    # Clear wizard context
    CURRENT_WIZARD=""
    CURRENT_STEP=""
}

# show_main_menu
# Displays the main wizard selection menu
show_main_menu() {
    local menu_items=()

    # Build menu items from available wizards
    for wizard_info in "${AVAILABLE_WIZARDS[@]}"; do
        local wizard_id="${wizard_info%%:*}"
        local wizard_desc="${wizard_info#*:}"
        menu_items+=("$wizard_desc")
    done

    menu_items+=("Exit")

    local choice
    choice=$(ui_menu "Main Menu" "${menu_items[@]}")

    case "$choice" in
        "CANCEL"|"BACK")
            return 1
            ;;
        "Exit")
            log "User selected exit" "INFO"
            return 1
            ;;
        *)
            # Find the wizard ID for the selected description
            for wizard_info in "${AVAILABLE_WIZARDS[@]}"; do
                local wizard_id="${wizard_info%%:*}"
                local wizard_desc="${wizard_info#*:}"
                if [[ "$wizard_desc" == "$choice" ]]; then
                    run_wizard "$wizard_id"
                    break
                fi
            done
            ;;
    esac

    return 0
}

# handle_goto "goto_spec"
# Handles GOTO environment variable for jumping to specific steps
handle_goto() {
    local goto_spec="$1"

    if [[ -z "$goto_spec" ]]; then
        return 0
    fi

    log "Processing GOTO: $goto_spec" "INFO"

    # Parse GOTO format: wizard:step or just step (assumes current wizard)
    local wizard=""
    local step=""

    if [[ "$goto_spec" =~ ^([^:]+):(.*)$ ]]; then
        wizard="${BASH_REMATCH[1]}"
        step="${BASH_REMATCH[2]}"
    else
        step="$goto_spec"
        # Use WIZARD env var or default
        wizard="${WIZARD:-kernel-build}"
    fi

    log "GOTO parsed: wizard=$wizard, step=$step" "DEBUG"

    # Validate wizard
    local valid_wizard=false
    for wizard_info in "${AVAILABLE_WIZARDS[@]}"; do
        local wizard_id="${wizard_info%%:*}"
        if [[ "$wizard_id" == "$wizard" ]]; then
            valid_wizard=true
            break
        fi
    done

    if [[ "$valid_wizard" != true ]]; then
        log "Invalid wizard in GOTO: $wizard" "ERROR"
        return 1
    fi

    # Set current wizard and discover steps
    CURRENT_WIZARD="$wizard"
    discover_steps "$wizard"

    # Validate step exists
    if [[ -z "${WIZARD_STEPS[$step]}" ]]; then
        log "Invalid step in GOTO: $step" "ERROR"
        return 1
    fi

    # Run the specific step
    run_step "$step" "$wizard"

    return 0
}

# main
# Main entry point
main() {
    log "V2 Flash Toolkit starting" "INFO"

    # Discover available wizards
    discover_wizards

    # Handle direct wizard execution
    if [[ -n "${WIZARD:-}" ]]; then
        log "Direct wizard execution requested: $WIZARD" "INFO"

        # Validate wizard
        local valid_wizard=false
        for wizard_info in "${AVAILABLE_WIZARDS[@]}"; do
            local wizard_id="${wizard_info%%:*}"
            if [[ "$wizard_id" == "$WIZARD" ]]; then
                valid_wizard=true
                break
            fi
        done

        if [[ "$valid_wizard" == true ]]; then
            if [[ -n "${GOTO:-}" ]]; then
                handle_goto "$GOTO"
            else
                run_wizard "$WIZARD"
            fi
        else
            log "Invalid wizard specified: $WIZARD" "ERROR"
            echo "Invalid wizard: $WIZARD" >&2
            echo "Available wizards: ${AVAILABLE_WIZARDS[*]}" >&2
            exit 1
        fi
    else
        # Show main menu
        while show_main_menu; do
            # Continue showing menu until user exits
            :
        done
    fi

    # Save context before exit
    save_context

    log "V2 Flash Toolkit exiting" "INFO"
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --wizard|-w)
            export WIZARD="$2"
            shift 2
            ;;
        --goto|-g)
            export GOTO="$2"
            shift 2
            ;;
        --list)
            # List available wizards and steps
            discover_wizards
            echo "Available wizards:"
            for wizard_info in "${AVAILABLE_WIZARDS[@]}"; do
                local wizard_id="${wizard_info%%:*}"
                local wizard_desc="${wizard_info#*:}"
                echo "  $wizard_id: $wizard_desc"
            done
            exit 0
            ;;
        --help|-h)
            echo "V2 Flash Toolkit"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -w, --wizard WIZARD    Run specific wizard directly"
            echo "  -g, --goto STEP        Jump to specific step (format: wizard:step or step)"
            echo "  --list                 List available wizards"
            echo "  -h, --help             Show this help"
            echo ""
            echo "Environment variables:"
            echo "  MOCK=1                 Run in mock mode (default)"
            echo "  DRY_RUN=1              Print commands without executing"
            echo "  THEME=default          UI theme"
            echo "  LOG_LEVEL=INFO         Logging level"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
