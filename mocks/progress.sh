#!/bin/bash
# mocks/progress.sh - Mock progress generators for MVP
# This file provides simulated progress bars and spinners for time-consuming operations
# All functions use whiptail for gauges and gum for spinners as fallbacks

# mock_gauge "Title" duration_secs
# Feeds 0..100 into whiptail --gauge over the specified duration
mock_gauge() {
    local title="$1"
    local secs="${2:-10}"
    local step_delay

    # Calculate delay per percentage point
    step_delay=$(awk "BEGIN { printf \"%.3f\", $secs / 100 }")

    # Generate progress from 0 to 100
    {
        for i in $(seq 0 100); do
            echo "$i"
            sleep "$step_delay"
        done
    } | whiptail --gauge "$title" 7 60 0 2>/dev/null

    # Fallback if whiptail not available
    if [[ $? -ne 0 ]]; then
        echo "Mock: $title completed (simulated ${secs}s)"
        sleep "$secs"
    fi
}

# mock_spinner "Message" duration_secs
# Shows a spinner with gum, falls back to simple echo
mock_spinner() {
    local message="$1"
    local secs="${2:-5}"

    # Try gum spinner first
    if command -v gum >/dev/null 2>&1; then
        gum spin --spinner dot --title "$message" -- sleep "$secs"
    else
        echo "Mock: $message (simulated ${secs}s)"
        sleep "$secs"
    fi
}

# mock_chunked_gauge "Title" "phase1:percent" "phase2:percent" ...
# Multi-phase progress bar with different phases
mock_chunked_gauge() {
    local title="$1"
    shift
    local phases=("$@")
    local total_percent=0
    local current_percent=0

    # Calculate total percentage and validate
    for phase in "${phases[@]}"; do
        local percent="${phase#*:}"
        total_percent=$((total_percent + percent))
    done

    if [[ $total_percent -ne 100 ]]; then
        echo "Warning: Phase percentages don't add up to 100% (total: $total_percent%)"
    fi

    # Generate chunked progress
    {
        for phase in "${phases[@]}"; do
            local phase_name="${phase%:*}"
            local phase_percent="${phase#*:}"
            local phase_steps=$((phase_percent * 100 / total_percent))

            echo "XXX" >&3
            echo "$phase_name" >&3
            echo "XXX" >&3

            for ((i = 0; i < phase_steps; i++)); do
                current_percent=$((current_percent + 1))
                echo "$current_percent"
                sleep 0.1
            done
        done

        # Ensure we reach 100%
        while [[ $current_percent -lt 100 ]]; do
            current_percent=$((current_percent + 1))
            echo "$current_percent"
            sleep 0.05
        done
    } 3>&1 | whiptail --gauge "$title" 8 60 0 2>/dev/null

    # Fallback
    if [[ $? -ne 0 ]]; then
        echo "Mock: $title completed with phases: ${phases[*]}"
        sleep 5
    fi
}

# mock_progress_with_log "Title" "log_file" duration_secs
# Shows progress and writes simulated log entries
mock_progress_with_log() {
    local title="$1"
    local log_file="$2"
    local secs="${3:-10}"
    local step_delay

    step_delay=$(awk "BEGIN { printf \"%.3f\", $secs / 100 }")

    # Start logging
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting: $title" >> "$log_file"

    # Generate progress with log entries
    {
        for i in $(seq 0 100); do
            echo "$i"
            if [[ $((i % 10)) -eq 0 ]]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') Progress: ${i}%" >> "$log_file"
            fi
            sleep "$step_delay"
        done
    } | whiptail --gauge "$title" 7 60 0 2>/dev/null

    # Final log entry
    echo "$(date '+%Y-%m-%d %H:%M:%S') Completed: $title" >> "$log_file"

    # Fallback
    if [[ $? -ne 0 ]]; then
        echo "Mock: $title completed (logged to $log_file)"
        sleep "$secs"
    fi
}
