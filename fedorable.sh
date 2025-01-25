#!/bin/bash

# Fedora System Optimizer Script
# Version: 2.3
# Description: User-friendly system maintenance with visual feedback
# Author: Your Name
# License: MIT

#------------------------------#
#         Configuration         #
#------------------------------#
KEEP_KERNELS=2
LOG_FILE="$HOME/fedora-optimizer.log"
TEMP_DIRS=("/tmp" "/var/tmp")
DAYS_TO_KEEP=3
SPINNER_DELAY=0.1
BRAILLE_SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

#------------------------------#
#          UI Settings          #
#------------------------------#
BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)
CHECK="${GREEN}✓${RESET}"
CROSS="${RED}✗${RESET}"
INFO="${BLUE}ℹ${RESET}"

#------------------------------#
#       Function Library       #
#------------------------------#
init() {
    echo -e "\n${BOLD}${BLUE}=== Fedora System Optimizer ===${RESET}\n"
    trap cleanup EXIT TERM INT
    check_sudo
    setup_logging
    parse_args "$@"
}

execute_with_spinner() {
    local msg="$1"
    shift
    
    ($@) &
    local pid=$!
    
    trap "kill -9 $pid 2>/dev/null" EXIT
    
    while kill -0 $pid 2>/dev/null; do
        for frame in "${BRAILLE_SPINNER[@]}"; do
            printf "\r  ${BLUE}${frame}${RESET} ${msg}..."
            sleep $SPINNER_DELAY
        done
    done
    
    wait $pid
    local success=$?
    
    printf "\r\033[K"  # Clear spinner line
    if [ $success -eq 0 ]; then
        printf "  ${CHECK} ${msg}\n"
    else
        printf "  ${CROSS} ${msg} (Error: $success)\n"
    fi
    return $success
}

check_sudo() {
    if ! sudo -nv 2>/dev/null; then
        echo -e "\n${BOLD}${YELLOW}Authentication required${RESET}"
        sudo -v || exit 1
    fi
}

setup_logging() {
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            *) echo -e "${CROSS} ${RED}Unknown option: $1${RESET}"; exit 1 ;;
        esac
        shift
    done
}

show_help() {
    echo -e "${BOLD}Usage:${RESET} $0"
    echo -e "\n${BOLD}Description:${RESET}"
    echo -e "  Automated system optimization and maintenance for Fedora"
    echo -e "\n${BOLD}Options:${RESET}"
    echo -e "  -h, --help    Show this help message"
}

cleanup() {
    sudo -k  # Revoke sudo privileges
}

#------------------------------#
#      Core Functionality       #
#------------------------------#
system_updates() {
    execute_with_spinner "Checking for updates" \
        sudo dnf check-update
    
    execute_with_spinner "Applying system updates" \
        sudo dnf upgrade -y
    
    execute_with_spinner "Cleaning package cache" \
        sudo dnf clean all
    
    execute_with_spinner "Updating repository metadata" \
        sudo dnf makecache
}

clean_kernels() {
    current_kernel=$(uname -r)
    installed_kernels=$(rpm -q kernel | grep -v "$current_kernel" | sort -V)
    
    if [ "$(wc -l <<< "$installed_kernels")" -gt $KEEP_KERNELS ]; then
        remove_kernels=$(head -n -$KEEP_KERNELS <<< "$installed_kernels")
        execute_with_spinner "Removing old kernels" \
            sudo dnf remove -y $remove_kernels
    fi
}

clean_temporary_files() {
    for dir in "${TEMP_DIRS[@]}"; do
        execute_with_spinner "Cleaning $dir" \
            sudo find "$dir" -type f -atime +$DAYS_TO_KEEP -delete
    done
}

optimize_packages() {
    if command -v flatpak &> /dev/null; then
        execute_with_spinner "Optimizing Flatpak" \
            sudo flatpak uninstall --unused -y
    fi
    
    execute_with_spinner "Rebuilding package database" \
        sudo rpm --rebuilddb
}

system_health_check() {
    execute_with_spinner "Rotating journal logs" \
        sudo journalctl --vacuum-time=7d
    
    execute_with_spinner "Resetting failed services" \
        sudo systemctl reset-failed
    
    execute_with_spinner "Updating font cache" \
        sudo fc-cache -f -v
    
    execute_with_spinner "Updating manual pages" \
        sudo mandb
}

#------------------------------#
#         Main Execution        #
#------------------------------#
main() {
    init "$@"
    
    system_updates
    clean_kernels
    clean_temporary_files
    optimize_packages
    system_health_check
    
    echo -e "\n${BOLD}${GREEN}Optimization complete!${RESET}"
    df -h /
}

#------------------------------#
#       Script Execution        #
#------------------------------#
main "$@"