#!/bin/bash
# lib/ui.sh - UI wrapper functions for V2 Flash Toolkit
# This file provides whiptail-based UI components for menus, inputs, progress bars, etc.
# All functions are designed to work in terminal environments

# Source base functions if not already loaded
if ! declare -f log >/dev/null 2>&1; then
    source "$(dirname "${BASH_SOURCE[0]}")/base.sh"
fi

# UI Constants
UI_WIDTH=70
UI_HEIGHT=20
UI_TITLE="${TOOLKIT_NAME:-V2 Flash Toolkit}"

# ui_menu "title" "item1" "item2" ... "itemN"
# Displays a menu and returns the selected item
ui_menu() {
    local title="$1"
    shift
    local items=("$@")
    local menu_items=()
    local i=1

    # Build menu items array
    for item in "${items[@]}"; do
        menu_items+=("$i" "$item")
        ((i++))
    done

    # Add back option if more than one item
    if [[ ${#items[@]} -gt 1 ]]; then
        menu_items+=("0" "Back")
    fi

    local choice
    choice=$(whiptail --title "$UI_TITLE - $title" \
                     --menu "$title" \
                     $UI_HEIGHT $UI_WIDTH $((UI_HEIGHT-8)) \
                     "${menu_items[@]}" \
                     3>&1 1>&2 2>&3)

    local exit_code=$?

    # Handle whiptail exit codes
    if [[ $exit_code -eq 1 ]]; then
        # Cancel/ESC pressed
        echo "CANCEL"
        return 1
    elif [[ $exit_code -eq 255 ]]; then
        # Window closed
        echo "CANCEL"
        return 1
    fi

    # Return selected item (adjust for 0-based indexing)
    if [[ "$choice" == "0" ]]; then
        echo "BACK"
    else
        echo "${items[$((choice-1))]}"
    fi
}

# ui_input "title" "prompt" "default_value"
# Shows an input box and returns the entered value
ui_input() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"

    local result
    result=$(whiptail --title "$UI_TITLE - $title" \
                     --inputbox "$prompt" \
                     8 $UI_WIDTH "$default" \
                     3>&1 1>&2 2>&3)

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "CANCEL"
        return 1
    fi

    echo "$result"
}

# ui_yesno "title" "message" "default_yes"
# Shows a yes/no dialog, returns 0 for yes, 1 for no
ui_yesno() {
    local title="$1"
    local message="$2"
    local default="${3:-no}"

    local default_flag="--defaultno"
    if [[ "$default" == "yes" ]]; then
        default_flag="--defaultyes"
    fi

    whiptail --title "$UI_TITLE - $title" \
             --yesno "$message" \
             8 $UI_WIDTH \
             $default_flag

    echo $?
}

# ui_msgbox "title" "message"
# Shows a message box
ui_msgbox() {
    local title="$1"
    local message="$2"

    whiptail --title "$UI_TITLE - $title" \
             --msgbox "$message" \
             8 $UI_WIDTH
}

# ui_textbox "title" "file_path"
# Shows a text file in a scrollable box
ui_textbox() {
    local title="$1"
    local file_path="$2"

    if [[ ! -f "$file_path" ]]; then
        ui_msgbox "Error" "File not found: $file_path"
        return 1
    fi

    whiptail --title "$UI_TITLE - $title" \
             --textbox "$file_path" \
             $UI_HEIGHT $UI_WIDTH
}

# ui_gauge "title" "command"
# Shows a progress gauge fed by a command that outputs 0-100
ui_gauge() {
    local title="$1"
    local command="$2"

    # Run command and pipe to gauge
    eval "$command" | whiptail --title "$UI_TITLE - $title" \
                              --gauge "Please wait..." \
                              6 $UI_WIDTH 0
}

# ui_spinner "title" "command"
# Shows a spinner while running a command
ui_spinner() {
    local title="$1"
    local command="$2"

    # Try gum spinner first
    if command -v gum >/dev/null 2>&1; then
        gum spin --spinner dot --title "$title" -- bash -c "$command"
    else
        # Fallback to simple message
        echo "Running: $title"
        eval "$command"
        echo "Completed: $title"
    fi
}

# ui_progress "title" "total_steps"
# Interactive progress tracking
ui_progress() {
    local title="$1"
    local total="$2"
    local current=0

    while [[ $current -lt $total ]]; do
        local percent=$((current * 100 / total))
        echo "$percent"
        sleep 1
        ((current++))
    done | whiptail --title "$UI_TITLE - $title" \
                   --gauge "Progress..." \
                   6 $UI_WIDTH 0
}

# ui_select_file "title" "directory" "pattern"
# File selection dialog
ui_select_file() {
    local title="$1"
    local directory="${2:-.}"
    local pattern="${3:-*}"

    # Get list of files
    local files
    mapfile -t files < <(find "$directory" -name "$pattern" -type f 2>/dev/null | head -20)

    if [[ ${#files[@]} -eq 0 ]]; then
        ui_msgbox "No Files" "No files found matching '$pattern' in $directory"
        echo "CANCEL"
        return 1
    fi

    # Create menu items
    local menu_items=()
    local i=1
    for file in "${files[@]}"; do
        menu_items+=("$i" "$(basename "$file")")
        ((i++))
    done

    local choice
    choice=$(whiptail --title "$UI_TITLE - $title" \
                     --menu "Select a file:" \
                     $UI_HEIGHT $UI_WIDTH $((UI_HEIGHT-8)) \
                     "${menu_items[@]}" \
                     3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        echo "CANCEL"
        return 1
    fi

    echo "${files[$((choice-1))]}"
}

# ui_danger_confirm "title" "message" "confirm_text"
# Double confirmation for dangerous operations
ui_danger_confirm() {
    local title="$1"
    local message="$2"
    local confirm_text="${3:-YES}"

    # First confirmation
    if ! ui_yesno "$title" "$message" "no"; then
        return 1
    fi

    # Second confirmation with typing
    local typed
    typed=$(ui_input "$title - Confirm" "Type '$confirm_text' to confirm:")

    if [[ "$typed" != "$confirm_text" ]]; then
        ui_msgbox "Confirmation Failed" "Incorrect confirmation text entered."
        return 1
    fi

    return 0
}

# ui_show_footer "current_step" "total_steps"
# Shows consistent footer with navigation hints
ui_show_footer() {
    local current="${1:-}"
    local total="${2:-}"

    local footer="↑/↓ Navigate · Enter Select · ESC Cancel"
    if [[ -n "$current" && -n "$total" ]]; then
        footer+=" · Step $current/$total"
    fi
    footer+=" · F1 Help · F4 View Log"

    echo "$footer"
}

# ui_help "topic"
# Shows help for a specific topic
ui_help() {
    local topic="${1:-general}"

    case "$topic" in
        "general")
            ui_msgbox "Help - General" \
"Welcome to V2 Flash Toolkit!

Navigation:
• Use ↑/↓ arrows to navigate menus
• Press Enter to select/confirm
• Press ESC to cancel/go back
• Press F1 for help
• Press F4 to view current log

Safety:
• All operations in MOCK mode are safe
• Real operations require confirmation
• Backups are recommended before flashing

For more help, check the documentation."
            ;;
        "kernel-build")
            ui_msgbox "Help - Kernel Build" \
"Kernel Build Wizard:

1. Select Repository: Choose from curated kernel sources
2. Pick Branch/Tag: Select specific version to build
3. Apply Config Patch: Optional kernel configuration
4. Build Settings: Configure build parameters
5. Build Progress: Monitor compilation (mocked in MVP)
6. Artifacts Summary: Review generated files

All builds are simulated in MVP mode."
            ;;
        "flash")
            ui_msgbox "Help - Flash Image" \
"Flash Image Wizard:

1. Pick Artifact: Select kernel/system image to flash
2. Select SD Card: Choose target device
3. Backup First: Recommended safety backup
4. Flash Progress: Monitor write operation (mocked)
5. Verify: Optional verification (mocked)

WARNING: Real flashing will overwrite device data!"
            ;;
        "bootimg-adjust")
            ui_msgbox "Help - Boot.img Adjuster" \
"Boot.img Adjuster Wizard:

1. Choose Base Boot Image: Extract from device or select file
2. Extract & Inspect: View boot image contents
3. Select New Kernel: Choose replacement kernel
4. DTB Mode/Variant: Configure device tree
5. Cmdline Editor: Modify kernel parameters
6. Repack Boot Image: Create new boot.img (mocked)
7. Modules Sync: Update kernel modules (mocked)
8. Flash Boot Partition: Write to device (mocked)

Ensures boot compatibility with new kernel."
            ;;
        "backup-restore")
            ui_msgbox "Help - Backup/Restore" \
"Backup/Restore Wizard:

1. Choose Action: Backup or Restore
2. Pick Source/Target: Select device/file
3. Progress: Monitor operation (mocked)
4. Verify: Optional verification (mocked)

Supports full disk or partition operations."
            ;;
        *)
            ui_msgbox "Help - Unknown Topic" "Help topic '$topic' not found."
            ;;
    esac
}

# ui_view_log "wizard_name"
# Shows the current log file for a wizard
ui_view_log() {
    local wizard="${1:-current}"
    local log_file

    # Find the most recent log for this wizard
    log_file=$(find logs -name "*-${wizard}.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
               sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$log_file" ]]; then
        ui_msgbox "No Log Found" "No log file found for $wizard"
        return 1
    fi

    ui_textbox "Log - $wizard" "$log_file"
}

# ui_select_file "title" "start_dir" "pattern"
# Shows a file selection dialog and returns the selected file path
ui_select_file() {
    local title="$1"
    local start_dir="${2:-.}"
    local pattern="${3:-*}"

    # Get list of files matching pattern
    local files
    mapfile -t files < <(find "$start_dir" -name "$pattern" -type f 2>/dev/null | head -20)

    if [[ ${#files[@]} -eq 0 ]]; then
        ui_msgbox "No Files Found" "No files found matching pattern: $pattern"
        echo "CANCEL"
        return 1
    fi

    # Create menu items
    local menu_items=()
    for file in "${files[@]}"; do
        local filename
        filename=$(basename "$file")
        local dirname
        dirname=$(dirname "$file")
        menu_items+=("$file" "$filename ($dirname)")
    done

    local choice
    choice=$(ui_menu "$title" "${menu_items[@]}")

    if [[ "$choice" == "CANCEL" || "$choice" == "BACK" ]]; then
        echo "CANCEL"
        return 1
    fi

    echo "$choice"
}

# Export UI functions
export -f ui_menu ui_input ui_yesno ui_msgbox ui_textbox
export -f ui_gauge ui_spinner ui_progress ui_select_file
export -f ui_danger_confirm ui_show_footer ui_help ui_view_log
