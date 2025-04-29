#!/bin/bash
# Service management functions for sawlog

# Update the service cache for faster searches and autocompletion
update_service_cache() {
    echo -e "${BLUE}Updating service cache...${NC}"
    mkdir -p "$CONFIG_DIR"
    
    # Get system units
    echo -e "${CYAN}Collecting system units...${NC}"
    journalctl --field=_SYSTEMD_UNIT 2>/dev/null | sort -u > "$CONFIG_DIR/system_services.cache"
    
    # Get user units
    echo -e "${CYAN}Collecting user units...${NC}"
    journalctl --user --field=_SYSTEMD_UNIT 2>/dev/null | sort -u > "$CONFIG_DIR/user_services.cache"
    
    # Get common process names (COMM)
    echo -e "${CYAN}Collecting process names...${NC}"
    journalctl --field=_COMM 2>/dev/null | sort -u > "$CONFIG_DIR/comm_services.cache"
    
    # Collect systemd services from systemctl
    echo -e "${CYAN}Collecting additional systemd services...${NC}"
    if command -v systemctl &> /dev/null; then
        systemctl list-units --type=service --all | awk '{print $1}' | grep '\.service' > "$CONFIG_DIR/systemctl_services.cache"
        systemctl --user list-units --type=service --all | awk '{print $1}' | grep '\.service' > "$CONFIG_DIR/systemctl_user_services.cache"
    fi
    
    # Combine them all for autocomplete
    echo -e "${CYAN}Building combined service cache...${NC}"
    cat "$CONFIG_DIR/system_services.cache" "$CONFIG_DIR/user_services.cache" \
        "$CONFIG_DIR/systemctl_services.cache" "$CONFIG_DIR/systemctl_user_services.cache" 2>/dev/null | 
        grep -v '^$' | sort -u > "$CONFIG_DIR/services.cache"
    
    # Store metadata about the services
    echo -e "${CYAN}Building service metadata...${NC}"
    > "$CONFIG_DIR/metadata.cache"  # Create/clear the file
    for service in $(cat "$CONFIG_DIR/services.cache"); do
        # Check if it's a system or user service
        if grep -q "^$service$" "$CONFIG_DIR/system_services.cache" 2>/dev/null; then
            echo "system|$service" >> "$CONFIG_DIR/metadata.cache"
        elif grep -q "^$service$" "$CONFIG_DIR/user_services.cache" 2>/dev/null; then
            echo "user|$service" >> "$CONFIG_DIR/metadata.cache"
        else
            echo "unknown|$service" >> "$CONFIG_DIR/metadata.cache"
        fi
    done
    
    # Store the last update time
    date +%s > "$CONFIG_DIR/last_update"
    
    echo -e "${GREEN}Service cache updated. Found $(wc -l < "$CONFIG_DIR/services.cache") services.${NC}"
}

# Check if the service cache needs to be refreshed
check_cache_freshness() {
    if [[ ! -f "$CONFIG_DIR/last_update" ]]; then
        return 1 # Cache doesn't exist
    fi
    
    local last_update=$(cat "$CONFIG_DIR/last_update")
    local current_time=$(date +%s)
    local cache_age=$((current_time - last_update))
    
    # If cache is older than a day (86400 seconds), suggest update
    if [[ $cache_age -gt 86400 ]]; then
        echo -e "${YELLOW}Service cache is more than a day old. Consider refreshing with '$TOOL_NAME --refresh'${NC}"
    fi
    
    return 0
}

# Search for services matching a pattern
search_services() {
    local pattern="$1"
    local scope="$2" # "system", "user", "both", or "all"
    local results=()
    
    # Make sure cache exists
    if [[ ! -f "$CONFIG_DIR/system_services.cache" || ! -f "$CONFIG_DIR/user_services.cache" ]]; then
        update_service_cache
    else
        check_cache_freshness
    fi
    
    if [[ "$scope" == "system" || "$scope" == "both" ]]; then
        mapfile -t system_results < <(grep -i "$pattern" "$CONFIG_DIR/system_services.cache" 2>/dev/null)
        for service in "${system_results[@]}"; do
            if [[ -n "$service" ]]; then
                results+=("system:$service")
            fi
        done
    fi
    
    if [[ "$scope" == "user" || "$scope" == "both" ]]; then
        mapfile -t user_results < <(grep -i "$pattern" "$CONFIG_DIR/user_services.cache" 2>/dev/null)
        for service in "${user_results[@]}"; do
            if [[ -n "$service" ]]; then
                results+=("user:$service")
            fi
        done
    fi
    
    # Add results for process names (_COMM)
    if [[ "$scope" != "system" && "$scope" != "user" || "$scope" == "all" ]]; then
        mapfile -t comm_results < <(grep -i "$pattern" "$CONFIG_DIR/comm_services.cache" 2>/dev/null)
        for comm in "${comm_results[@]}"; do
            if [[ -n "$comm" ]]; then
                results+=("comm:$comm")
            fi
        done
    fi
    
    # Additional systemctl services that might not have journal entries yet
    if [[ "$scope" == "system" || "$scope" == "both" || "$scope" == "all" ]]; then
        mapfile -t systemctl_results < <(grep -i "$pattern" "$CONFIG_DIR/systemctl_services.cache" 2>/dev/null)
        for service in "${systemctl_results[@]}"; do
            if [[ -n "$service" ]]; then
                # Check if this service is already added
                local already_added=false
                for existing in "${results[@]}"; do
                    if [[ "$existing" == *"$service" ]]; then
                        already_added=true
                        break
                    fi
                done
                if [[ "$already_added" == false ]]; then
                    results+=("system:$service")
                fi
            fi
        done
    fi
    
    if [[ "$scope" == "user" || "$scope" == "both" || "$scope" == "all" ]]; then
        mapfile -t systemctl_user_results < <(grep -i "$pattern" "$CONFIG_DIR/systemctl_user_services.cache" 2>/dev/null)
        for service in "${systemctl_user_results[@]}"; do
            if [[ -n "$service" ]]; then
                # Check if this service is already added
                local already_added=false
                for existing in "${results[@]}"; do
                    if [[ "$existing" == *"$service" ]]; then
                        already_added=true
                        break
                    fi
                done
                if [[ "$already_added" == false ]]; then
                    results+=("user:$service")
                fi
            fi
        done
    fi
    
    echo "${results[@]}"
}

# List available services
list_services() {
    local scope="$1" # "system", "user", "both", or "all"
    
    echo -e "${CYAN}${BOLD}Available Services:${NC}"
    echo
    
    if [[ "$scope" == "system" || "$scope" == "both" || "$scope" == "all" ]]; then
        echo -e "${BOLD}System Services:${NC} (top 20 by log volume)"
        journalctl --field=_SYSTEMD_UNIT 2>/dev/null | sort | uniq -c | sort -nr | head -n 20 | 
            awk '{printf "  %4d entries: \033[36m%s\033[0m\n", $1, $2}'
        echo
    fi
    
    if [[ "$scope" == "user" || "$scope" == "both" || "$scope" == "all" ]]; then
        echo -e "${BOLD}User Services:${NC} (top 20 by log volume)"
        journalctl --user --field=_SYSTEMD_UNIT 2>/dev/null | sort | uniq -c | sort -nr | head -n 20 | 
            awk '{printf "  %4d entries: \033[36m%s\033[0m\n", $1, $2}'
        echo
    fi
    
    if [[ "$scope" == "both" || "$scope" == "all" || "$scope" != "system" && "$scope" != "user" ]]; then
        echo -e "${BOLD}Common Process Names:${NC} (top 20 by log volume)"
        journalctl --field=_COMM 2>/dev/null | sort | uniq -c | sort -nr | head -n 20 | 
            awk '{printf "  %4d entries: \033[36m%s\033[0m\n", $1, $2}'
    fi
}

# Show service status
show_service_status() {
    local service_type="$1"
    local service_name="$2"
    
    case "$service_type" in
        "system")
            echo -e "${BOLD}${BLUE}Service Status:${NC}"
            systemctl status "$service_name" | head -n 3
            echo
            ;;
        "user")
            echo -e "${BOLD}${BLUE}User Service Status:${NC}"
            systemctl --user status "$service_name" | head -n 3
            echo
            ;;
        *)
            # For comm or other types, just show it's a process
            echo -e "${BOLD}${BLUE}Process:${NC} $service_name"
            echo
            ;;
    esac
}