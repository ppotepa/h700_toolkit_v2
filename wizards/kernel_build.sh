#!/bin/bash
# wizards/kernel_build.sh - Kernel Build Wizard Orchestrator
# This script coordinates the kernel build process through multiple steps
# Each step is implemented as a separate file in the kernel-build/ directory

# Source required libraries
source "$TOOLKIT_ROOT/lib/base.sh"
source "$TOOLKIT_ROOT/lib/ui.sh"
source "$TOOLKIT_ROOT/lib/config.sh"
source "$TOOLKIT_ROOT/mocks/data.sh"
source "$TOOLKIT_ROOT/mocks/fs.sh"
source "$TOOLKIT_ROOT/mocks/progress.sh"

# Wizard-specific variables
WIZARD_NAME="kernel_build"
WIZARD_TITLE="Kernel Build"

# kernel_build_1_0__choose_kernel_from_gh
# Step 1-0: Choose kernel repository from GitHub
kernel_build_1_0__choose_kernel_from_gh() {
    log "Starting step 1-0: Choose kernel repository" "INFO"

    # Get list of available repositories
    local repos
    mapfile -t repos < <(get_repos_list)

    if [[ ${#repos[@]} -eq 0 ]]; then
        ui_msgbox "Error" "No repositories configured"
        return 1
    fi

    # Create menu items with descriptions
    local menu_items=()
    for repo in "${repos[@]}"; do
        local desc
        desc=$(get_repo_info "$repo" "desc")
        menu_items+=("$repo" "$desc")
    done

    # Add custom URL option
    menu_items+=("custom" "Enter custom repository URL")

    local choice
    choice=$(ui_menu "Select Kernel Repository" "${menu_items[@]}")

    case "$choice" in
        "CANCEL")
            return 1
            ;;
        "custom")
            local custom_url
            custom_url=$(ui_input "Custom Repository" "Enter repository URL:" "https://github.com/user/repo")
            if [[ "$custom_url" == "CANCEL" ]]; then
                return 1
            fi
            CTX[repo_url]="$custom_url"
            CTX[repo_name]="custom"
            ;;
        *)
            CTX[repo_url]=$(get_repo_info "$choice" "url")
            CTX[repo_name]="$choice"
            ;;
    esac

    log "Selected repository: ${CTX[repo_name]} (${CTX[repo_url]})" "INFO"
    return 0
}

# kernel_build_1_1__pick_branch_tag
# Step 1-1: Pick branch or tag from repository
kernel_build_1_1__pick_branch_tag() {
    log "Starting step 1-1: Pick branch/tag" "INFO"

    local repo_name="${CTX[repo_name]}"
    if [[ -z "$repo_name" ]]; then
        ui_msgbox "Error" "No repository selected"
        return 1
    fi

    # Get refs for this repository (mocked)
    local refs
    refs=$(mock_refs "$repo_name")

    if [[ -z "$refs" ]]; then
        ui_msgbox "Error" "No branches/tags found for repository $repo_name"
        return 1
    fi

    # Parse refs into menu items
    local menu_items=()
    while read -r ref; do
        [[ -z "$ref" ]] && continue
        local ref_type="${ref%%:*}"
        local ref_name="${ref#*:}"
        menu_items+=("$ref_name" "$ref_type")
    done <<< "$refs"

    local choice
    choice=$(ui_menu "Pick Branch or Tag" "${menu_items[@]}")

    if [[ "$choice" == "CANCEL" ]]; then
        return 1
    fi

    CTX[ref]="$choice"
    log "Selected ref: ${CTX[ref]}" "INFO"
    return 0
}

# kernel_build_1_1_1__repo_health_check
# Step 1-1-1: Repository health check (optional)
kernel_build_1_1_1__repo_health_check() {
    log "Starting step 1-1-1: Repository health check" "INFO"

    local repo_url="${CTX[repo_url]}"
    if [[ -z "$repo_url" ]]; then
        ui_msgbox "Error" "No repository URL available"
        return 1
    fi

    # Mock health check
    ui_msgbox "Repository Health" "Repository: $repo_url\nStatus: Healthy (mocked)\nLast commit: Recent\nStars: 150+"

    return 0
}

# kernel_build_1_2__apply_config_patch
# Step 1-2: Apply kernel config patch
kernel_build_1_2__apply_config_patch() {
    log "Starting step 1-2: Apply config patch" "INFO"

    local choice
    choice=$(ui_yesno "Kernel Config Patch" \
        "Apply a .config fragment to base defconfig, then olddefconfig?\n\nThis will merge custom kernel configuration." \
        "no")

    if [[ $? -eq 0 ]]; then
        # User wants to apply patch
        local patch_file
        patch_file=$(ui_select_file "Select Config Patch" "." "*.patch")

        if [[ "$patch_file" != "CANCEL" ]]; then
            CTX[apply_patch]="1"
            CTX[patch_path]="$patch_file"
            log "Config patch selected: $patch_file" "INFO"
        else
            CTX[apply_patch]="0"
        fi
    else
        CTX[apply_patch]="0"
        log "Config patch skipped" "INFO"
    fi

    return 0
}

# kernel_build_2_0__build_settings
# Step 2-0: Configure build settings
kernel_build_2_0__build_settings() {
    log "Starting step 2-0: Build settings" "INFO"

    # Default values
    local jobs="${CTX[jobs]:-4}"
    local arch="${CTX[arch]:-arm64}"
    local outdir="${CTX[outdir]:-builds/${CTX[repo_name]//\//-}/$(get_timestamp)}"

    # Architecture selection
    local arch_choice
    arch_choice=$(ui_menu "Target Architecture" "arm" "arm64")
    if [[ "$arch_choice" == "CANCEL" ]]; then
        return 1
    fi
    arch="$arch_choice"

    # Thread count input
    local jobs_input
    jobs_input=$(ui_input "Build Settings" "Number of threads (jobs):" "$jobs")
    if [[ "$jobs_input" == "CANCEL" ]]; then
        return 1
    fi
    jobs="$jobs_input"

    # Output directory
    local outdir_input
    outdir_input=$(ui_input "Build Settings" "Output directory:" "$outdir")
    if [[ "$outdir_input" == "CANCEL" ]]; then
        return 1
    fi
    outdir="$outdir_input"

    # Save settings
    CTX[jobs]="$jobs"
    CTX[arch]="$arch"
    CTX[outdir]="$outdir"

    log "Build settings: jobs=$jobs, arch=$arch, outdir=$outdir" "INFO"
    return 0
}

# kernel_build_2_1__build_progress
# Step 2-1: Build progress with mock operations
kernel_build_2_1__build_progress() {
    log "Starting step 2-1: Build progress" "INFO"

    local outdir="${CTX[outdir]}"
    if [[ -z "$outdir" ]]; then
        ui_msgbox "Error" "No output directory specified"
        return 1
    fi

    # Create log file
    local log_file
    log_file=$(mock_touch_log "kernel_build")

    # Show build progress with phases
    mock_progress_with_log "Building Kernel" "$log_file" 60

    # Create mock build artifacts
    mock_make_build "$outdir"

    ui_msgbox "Build Complete" "Kernel build completed successfully!\n\nArtifacts created in: $outdir\n\nLog: $log_file"

    return 0
}

# kernel_build_3_0__artifacts_summary
# Step 3-0: Show build artifacts and next steps
kernel_build_3_0__artifacts_summary() {
    log "Starting step 3-0: Artifacts summary" "INFO"

    local outdir="${CTX[outdir]}"
    if [[ -z "$outdir" ]]; then
        ui_msgbox "Error" "No output directory available"
        return 1
    fi

    # List artifacts
    local artifacts
    artifacts=$(find "$outdir" -type f -name "Image*" -o -name "*.dtb" -o -name "modules*" | head -10)

    local summary="Build artifacts in: $outdir\n\n"
    summary+="Files created:\n"
    while read -r file; do
        [[ -z "$file" ]] && continue
        summary+="$(basename "$file")\n"
    done <<< "$artifacts"

    summary+="\nWhat next?\n• Go to Flash Image\n• Return to Main Menu"

    ui_msgbox "Build Complete" "$summary"

    # Offer next steps
    local choice
    choice=$(ui_menu "Next Steps" "Go to Flash Image" "Return to Main Menu")

    case "$choice" in
        "Go to Flash Image")
            # Set context to trigger flash wizard
            CTX[next_wizard]="flash"
            ;;
        "Return to Main Menu")
            CTX[continue]="false"
            ;;
        "CANCEL")
            return 1
            ;;
    esac

    return 0
}

# Export step functions
export -f kernel_build_1_0__choose_kernel_from_gh
export -f kernel_build_1_1__pick_branch_tag
export -f kernel_build_1_1_1__repo_health_check
export -f kernel_build_1_2__apply_config_patch
export -f kernel_build_2_0__build_settings
export -f kernel_build_2_1__build_progress
export -f kernel_build_3_0__artifacts_summary
