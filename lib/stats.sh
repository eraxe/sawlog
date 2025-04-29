#!/bin/bash
# Statistics and health reporting functions for sawlog

# Show log statistics for a service
show_log_stats() {
    local service_type="$1"
    local service_name="$2"
    local time_filter="$3"
    local until_filter="$4"
    local category_filter="$5"
    
    echo -e "${BOLD}${BLUE}Log Statistics:${NC}"
    echo
    
    # Build the journalctl command for statistics
    local base_cmd=""
    
    case "$service_type" in
        "system")
            base_cmd="journalctl -u \"$service_name\""
            ;;
        "user")
            base_cmd="journalctl --user -u \"$service_name\""
            ;;
        "comm")
            base_cmd="journalctl _COMM=\"$service_name\""
            ;;
        "kernel")
            base_cmd="journalctl --dmesg"
            ;;
        "all")
            base_cmd="journalctl"
            ;;
        *)
            echo -e "${RED}Unknown service type: $service_type${NC}"
            return 1
            ;;
    esac
    
    # Add time filters if specified
    if [[ -n "$time_filter" ]]; then
        base_cmd="$base_cmd --since=\"$time_filter\""
    fi
    
    if [[ -n "$until_filter" ]]; then
        base_cmd="$base_cmd --until=\"$until_filter\""
    fi
    
    # Get total number of log entries
    local total_entries=$(eval "$base_cmd --no-pager | wc -l")
    echo -e "${BOLD}Total Entries:${NC} $total_entries"
    
    # Get priority distribution
    echo -e "\n${BOLD}Priority Distribution:${NC}"
    for priority in "${PRIORITIES[@]}"; do
        local count=$(eval "$base_cmd --priority=$priority --no-pager | wc -l")
        # Only show non-zero counts
        if [[ $count -gt 0 ]]; then
            # Color based on priority
            local color=$NC
            case "$priority" in
                emerg|alert|crit|err)
                    color=$RED
                    ;;
                warning)
                    color=$YELLOW
                    ;;
                info)
                    color=$GREEN
                    ;;
                debug)
                    color=$GRAY
                    ;;
            esac
            printf "  %-8s ${color}%4d${NC} entries (%2d%%)\n" "$priority:" "$count" "$((count * 100 / total_entries))"
        fi
    done
    
    # Get time distribution if time filter is set
    if [[ -n "$time_filter" ]]; then
        echo -e "\n${BOLD}Time Distribution:${NC}"
        
        # Determine the appropriate time interval based on the time filter
        local interval="1h"
        if [[ "$time_filter" == *"week"* || "$time_filter" == *"month"* ]]; then
            interval="1d"
        elif [[ "$time_filter" == *"day"* || "$time_filter" == *"24h"* ]]; then
            interval="6h"
        fi
        
        # Get entries by time interval
        local time_data=$(eval "$base_cmd --no-pager | grep -E '^[A-Za-z]{3} [0-9]{2} [0-9]{2}' | cut -d' ' -f1-3 | sort | uniq -c")
        
        # Show the time distribution
        echo "$time_data" | head -n 10 | awk '{printf "  %s %s %s: %4d entries\n", $2, $3, $4, $1}'
        
        if [[ $(echo "$time_data" | wc -l) -gt 10 ]]; then
            echo "  ... and more"
        fi
    fi
    
    # Show top message patterns
    echo -e "\n${BOLD}Common Message Patterns:${NC}"
    eval "$base_cmd --no-pager | grep -v '^--' | sed 's/^[A-Za-z]\{3\} [0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} [^ ]* //' | sed 's/[0-9]\+//g' | sort | uniq -c | sort -nr | head -n 5" | 
        awk '{printf "  %4d occurrences: %s\n", $1, substr($0, length($1)+1)}'
    
    # Show error message patterns specifically
    if [[ $total_entries -gt 0 ]]; then
        echo -e "\n${BOLD}${RED}Error Patterns:${NC}"
        # Fix: Use separate calls for each priority level and combine the results
        {
            eval "$base_cmd --priority=0 --no-pager"
            eval "$base_cmd --priority=1 --no-pager"
            eval "$base_cmd --priority=2 --no-pager"
            eval "$base_cmd --priority=3 --no-pager"
        } | grep -v '^--' | sed 's/^[A-Za-z]\{3\} [0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} [^ ]* //' | sort | uniq -c | sort -nr | head -n 5 | 
            awk '{printf "  %4d occurrences: \033[31m%s\033[0m\n", $1, substr($0, length($1)+1)}'
        
        # Show log spikes (unusual activity)
        echo -e "\n${BOLD}Activity Analysis:${NC}"
        
        # Get the time range for analysis
        local start_time=$(eval "$base_cmd --no-pager | head -n 1 | grep -oE '^[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'")
        local end_time=$(eval "$base_cmd --no-pager | tail -n 1 | grep -oE '^[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'")
        
        echo -e "  Time range: ${CYAN}$start_time${NC} to ${CYAN}$end_time${NC}"
        
        # Calculate average log rate
        if [[ $total_entries -gt 1 ]]; then
            # Get entries per hour
            local entries_per_hour=$(eval "$base_cmd --no-pager | grep -E '^[A-Za-z]{3} [0-9]{2} [0-9]{2}' | cut -d' ' -f1-3 | sort | uniq -c | sort -nr | head -n 24")
            
            # Calculate standard deviation of hourly rates to find spikes
            local hourly_rates=$(echo "$entries_per_hour" | awk '{print $1}')
            local avg_rate=$(echo "$hourly_rates" | awk '{ sum += $1 } END { if (NR > 0) print sum / NR; else print 0 }')
            
            echo -e "  Average rate: ${YELLOW}$avg_rate${NC} entries per hour"
            
            # List hours with unusually high activity
            echo -e "  ${BOLD}Activity Spikes:${NC}"
            echo "$entries_per_hour" | awk -v avg="$avg_rate" '{ 
                if ($1 > avg * 2 && $1 > 10) {
                    printf "    \033[33m%s %s %s\033[0m: %d entries (%.1fx average)\n", $2, $3, $4, $1, $1/avg 
                }
            }' | head -n 5
        fi
        
        # Identify log patterns that might indicate problems
        echo -e "\n${BOLD}Potential Issues:${NC}"
        
        # Look for common error indicators
        local errors=$(eval "$base_cmd --no-pager | grep -i -E 'fail|error|exception|crash|abort|segfault|killed|timeout' | wc -l")
        local warnings=$(eval "$base_cmd --no-pager | grep -i -E 'warning|warn|deprecated|not found' | wc -l")
        local resource_issues=$(eval "$base_cmd --no-pager | grep -i -E 'memory|cpu|full|space|load|overflow|leak|exhausted' | wc -l")
        local permission_issues=$(eval "$base_cmd --no-pager | grep -i -E 'permission|denied|unauthorized|access|forbidden' | wc -l")
        local security_issues=$(eval "$base_cmd --no-pager | grep -i -E 'attack|breach|vulnerable|exploit|injection|malicious|suspicious' | wc -l")
        
        # Only show non-zero counts
        if [[ $errors -gt 0 ]]; then
            echo -e "  ${RED}• Errors/Failures:${NC} $errors entries"
        fi
        if [[ $warnings -gt 0 ]]; then
            echo -e "  ${YELLOW}• Warnings:${NC} $warnings entries"
        fi
        if [[ $resource_issues -gt 0 ]]; then
            echo -e "  ${PURPLE}• Resource Issues:${NC} $resource_issues entries"
        fi
        if [[ $permission_issues -gt 0 ]]; then
            echo -e "  ${BLUE}• Permission Issues:${NC} $permission_issues entries"
        fi
        if [[ $security_issues -gt 0 ]]; then
            echo -e "  ${RED}${BOLD}• Security Concerns:${NC} $security_issues entries"
        fi
    fi
    
    # Show log file locations
    echo -e "\n${BOLD}Log Locations:${NC}"
    case "$service_type" in
        "system")
            echo -e "  • Journald: ${CYAN}journalctl -u $service_name${NC}"
            # Check for additional log files in common locations
            for log_path in "/var/log" "/var/log/syslog" "/var/log/messages"; do
                if [[ -d "$log_path" ]]; then
                    local log_files=$(find "$log_path" -type f -name "*$(echo "$service_name" | sed 's/\.service//')*" 2>/dev/null)
                    if [[ -n "$log_files" ]]; then
                        echo "$log_files" | while read -r log_file; do
                            echo -e "  • Log file: ${CYAN}$log_file${NC}"
                        done
                    fi
                fi
            done
            ;;
        "user")
            echo -e "  • Journald: ${CYAN}journalctl --user -u $service_name${NC}"
            # Check for user log files
            for log_path in "$HOME/.local/share/logs" "$HOME/.cache/logs" "$HOME/.local/state"; do
                if [[ -d "$log_path" ]]; then
                    local log_files=$(find "$log_path" -type f -name "*$(echo "$service_name" | sed 's/\.service//')*" 2>/dev/null)
                    if [[ -n "$log_files" ]]; then
                        echo "$log_files" | while read -r log_file; do
                            echo -e "  • Log file: ${CYAN}$log_file${NC}"
                        done
                    fi
                fi
            done
            ;;
        "kernel")
            echo -e "  • Journald: ${CYAN}journalctl --dmesg${NC}"
            echo -e "  • Kernel log: ${CYAN}/var/log/kern.log${NC}"
            echo -e "  • Kernel ring buffer: ${CYAN}dmesg${NC}"
            ;;
        "all")
            echo -e "  • Journald: ${CYAN}journalctl${NC}"
            echo -e "  • System logs: ${CYAN}/var/log/syslog, /var/log/messages${NC}"
            ;;
    esac
    
    echo
}

# Function to show system-wide statistics
show_system_stats() {
    echo -e "${BOLD}${BLUE}System-wide Process Statistics:${NC}"
    echo
    
    # Ensure stats cache directory exists
    mkdir -p "$STATS_CACHE_DIR"
    
    # Get current system load
    if [[ -f "/proc/loadavg" ]]; then
        local load=$(cat /proc/loadavg)
        echo -e "${BOLD}System Load:${NC} ${YELLOW}$load${NC}"
    fi
    
    # Get CPU usage
    echo -e "\n${BOLD}CPU Usage:${NC}"
    if command -v mpstat &> /dev/null; then
        # Use mpstat for detailed CPU stats if available
        mpstat -P ALL 1 1 | grep -v "^Linux\|^Average\|^$" | 
            awk '{printf "  CPU %-2s: %5.1f%% user, %5.1f%% system, %5.1f%% idle\n", $3, $4, $6, $12}'
    else
        # Fallback to top for basic CPU usage
        top -bn1 | grep "Cpu(s)" | 
            awk '{printf "  Usage: %5.1f%% user, %5.1f%% system, %5.1f%% idle\n", $2, $4, $8}'
    fi
    
    # Get memory usage
    echo -e "\n${BOLD}Memory Usage:${NC}"
    free -h | grep -v "^Swap" | 
        awk 'NR==1 {printf "  %s\n", $0} NR==2 {printf "  \033[36m%s\033[0m\n", $0}'
    
    # Get disk usage
    echo -e "\n${BOLD}Disk Usage:${NC}"
    df -h | grep -v "tmpfs\|udev\|loop" | head -n 10 | 
        awk 'NR==1 {print "  "$0} NR>1 {
            usage=substr($5, 1, length($5)-1) + 0;
            if (usage > 90) color="\033[31m";
            else if (usage > 75) color="\033[33m";
            else color="\033[32m";
            printf "  %s%s\033[0m\n", color, $0
        }'
    
    # Get systemd service status summary
    if command -v systemctl &> /dev/null; then
        echo -e "\n${BOLD}Systemd Services Status:${NC}"
        systemctl list-units --type=service --all --no-legend | 
            awk '{state=$3; sub(/\r$/, "", state); 
                 count[state]++} 
                 END {
                     printf "  Running: \033[32m%d\033[0m, Failed: \033[31m%d\033[0m, ", 
                            count["running"], count["failed"]; 
                     printf "Inactive: \033[90m%d\033[0m, Total: %d\n", 
                            count["inactive"], NR
                 }'
        
        # Show failed services
        local failed_services=$(systemctl list-units --state=failed --no-legend | wc -l)
        if [[ $failed_services -gt 0 ]]; then
            echo -e "\n${BOLD}${RED}Failed Services:${NC}"
            systemctl list-units --state=failed --no-legend | 
                awk '{printf "  \033[31m%s\033[0m - %s\n", $1, $2}'
        fi
    fi
    
    # Get process statistics
    echo -e "\n${BOLD}Process Statistics:${NC}"
    echo -e "  Total processes: $(ps aux | wc -l)"
    
    # Top processes by CPU
    echo -e "\n${BOLD}Top Processes by CPU:${NC}"
    ps aux --sort=-%cpu | head -n 6 | tail -n 5 | 
        awk '{printf "  %-10s %5.1f%% CPU, %5.1f%% MEM - %s\n", $1, $3, $4, $11}'
    
    # Top processes by memory
    echo -e "\n${BOLD}Top Processes by Memory:${NC}"
    ps aux --sort=-%mem | head -n 6 | tail -n 5 | 
        awk '{printf "  %-10s %5.1f%% MEM, %5.1f%% CPU - %s\n", $1, $4, $3, $11}'
    
    # Network connections
    if command -v ss &> /dev/null; then
        echo -e "\n${BOLD}Network Connections:${NC}"
        echo -e "  TCP connections: $(ss -t | grep -v "State" | wc -l)"
        echo -e "  UDP connections: $(ss -u | grep -v "State" | wc -l)"
        echo -e "  Listening ports: $(ss -l | grep -v "State" | wc -l)"
    fi
    
    # Collect log statistics by service type
    echo -e "\n${BOLD}Log Activity Summary:${NC}"
    
    # Collect today's error rates for system services
    local today=$(date +%Y-%m-%d)
    local errors_summary=""
    
    # Count system errors in the last hour
    # Fix: Using priority ranges for critical logs (0-3)
    local system_errors=$(journalctl --priority=0..3 --since="1 hour ago" | wc -l)
    local system_warnings=$(journalctl --priority=4 --since="1 hour ago" | wc -l)
    
    echo -e "  Last hour: ${RED}$system_errors${NC} errors, ${YELLOW}$system_warnings${NC} warnings"
    
    # Count errors by service category
    echo -e "\n${BOLD}Errors by Category (last 24h):${NC}"
    
    # Collect errors for common service categories
    local categories=("system" "network" "kernel" "security" "hardware" "application")
    
    for category in "${categories[@]}"; do
        local count=0
        case "$category" in
            "system")
                # System services (systemd, udev, etc.)
                # Fix: Using priority ranges for critical logs (0-3)
                count=$(journalctl -u systemd -u udev -u dbus -u polkit --priority=0..3 --since="24 hours ago" | wc -l)
                ;;
            "network")
                # Network services
                # Fix: Using priority ranges for critical logs (0-3)
                count=$(journalctl -u NetworkManager -u systemd-networkd -u ssh -u networking --priority=0..3 --since="24 hours ago" | wc -l)
                ;;
            "kernel")
                # Kernel messages
                # Fix: Using priority ranges for critical logs (0-3)
                count=$(journalctl --dmesg --priority=0..3 --since="24 hours ago" | wc -l)
                ;;
            "security")
                # Security-related logs
                # Fix: Using priority ranges for critical logs (0-3)
                count=$(journalctl -u apparmor -u audit -u sshd -u sudo --priority=0..3 --since="24 hours ago" | wc -l)
                ;;
            "hardware")
                # Hardware-related logs
                count=$(journalctl | grep -i -E "hardware|device|disk|cpu|memory|thermal|temperature|fan|power|battery" | grep -i -E "error|fail|critical" --since="24 hours ago" | wc -l)
                ;;
            "application")
                # Application logs
                # Fix: Using priority ranges for critical logs (0-3)
                count=$(journalctl -u apache2 -u nginx -u mysql -u docker -u snap -u flatpak --priority=0..3 --since="24 hours ago" | wc -l)
                ;;
        esac
        
        # Set color based on count
        local color=$GREEN
        if [[ $count -gt 50 ]]; then
            color=$RED
        elif [[ $count -gt 10 ]]; then
            color=$YELLOW
        fi
        
        printf "  %-12s ${color}%4d${NC} errors\n" "$category:" "$count"
    done
    
    echo
}

# Function to show areas of the system that need attention
show_attention_areas() {
    local time_filter="$1"
    local category_filter="$2"
    
    echo -e "${BOLD}${BLUE}Areas Needing Attention:${NC}"
    echo
    
    # Ensure stats cache directory exists
    mkdir -p "$STATS_CACHE_DIR"
    
    # Default to 24 hours if no time filter
    if [[ -z "$time_filter" ]]; then
        time_filter="24 hours ago"
    fi
    
    # Create a temporary file to store attention items
    local temp_file=$(mktemp)
    
    # === 1. Check for system service failures ===
    if [[ -z "$category_filter" || "$category_filter" == "system" ]]; then
        echo -e "${BOLD}System Service Failures:${NC}"
        
        # Get failed systemd services
        if command -v systemctl &> /dev/null; then
            local failed_services=$(systemctl list-units --state=failed --no-legend)
            local failed_count=$(echo "$failed_services" | grep -v "^$" | wc -l)
            
            if [[ $failed_count -gt 0 ]]; then
                echo "$failed_services" | 
                    awk '{printf "  \033[31m[HIGH]\033[0m %s - %s\n", $1, $2}' > "$temp_file"
                cat "$temp_file"
                echo "system:critical:Failed services|$failed_count|systemctl --failed" >> "$temp_file"
            else
                echo -e "  ${GREEN}No failed services found${NC}"
            fi
        fi
        
        echo
    fi
    
    # === 2. Check for high error rates in logs ===
    echo -e "${BOLD}Services with High Error Rates:${NC}"
    
    # Get top services by error count
    # Fix: Using priority ranges for critical logs (0-3)
    local error_prone_services=$(journalctl --priority=0..3 --since="$time_filter" --output=json | 
        jq -r '.SYSLOG_IDENTIFIER // ._COMM // "unknown"' 2>/dev/null | 
        sort | uniq -c | sort -nr | head -n 10)
    
    if [[ -n "$error_prone_services" ]]; then
        echo "$error_prone_services" | 
            awk '{
                severity = "LOW";
                color = "\033[32m";
                if ($1 > 100) {
                    severity = "HIGH";
                    color = "\033[31m";
                } else if ($1 > 20) {
                    severity = "MED";
                    color = "\033[33m";
                }
                printf "  %s[%s]\033[0m %s errors in %s\n", color, severity, $1, $2
            }'
        
        # Add top error-prone services to the attention file
        echo "$error_prone_services" | 
            awk '{
                severity = "warning";
                if ($1 > 100) {
                    severity = "critical";
                } else if ($1 > 20) {
                    severity = "error";
                }
                print "application:" severity ":" $2 " errors|" $1 "|journalctl _COMM=" $2 " --priority=0..3"
            }' >> "$temp_file"
    else
        echo -e "  ${GREEN}No significant error rates found${NC}"
    fi
    
    echo
    
    # === 3. Check for resource issues ===
    if [[ -z "$category_filter" || "$category_filter" == "performance" ]]; then
        echo -e "${BOLD}Resource Issues:${NC}"
        
        # Check disk space
        local disk_issues=$(df -h | grep -v "tmpfs\|udev\|loop" | awk '{ gsub(/%/,""); if($5 > 85) print $0 }')
        if [[ -n "$disk_issues" ]]; then
            echo "$disk_issues" | 
                awk '{
                    severity = "MED";
                    color = "\033[33m";
                    if ($5 > 95) {
                        severity = "HIGH";
                        color = "\033[31m";
                    }
                    printf "  %s[%s]\033[0m Disk %s is %s%% full (%s used of %s)\n", 
                           color, severity, $1, $5, $3, $2
                }'
            
            # Add disk space issues to the attention file
            echo "$disk_issues" | 
                awk '{
                    severity = "warning";
                    if ($5 > 95) {
                        severity = "critical";
                    } else if ($5 > 90) {
                        severity = "error";
                    }
                    print "hardware:" severity ":Disk " $1 " " $5 "% full|" $5 "|df -h"
                }' >> "$temp_file"
        else
            echo -e "  ${GREEN}Disk space usage is normal${NC}"
        fi
        
        # Check for memory issues in logs
        local memory_issues=$(journalctl --since="$time_filter" | grep -i -E "out of memory|cannot allocate|memory exhausted" | wc -l)
        if [[ $memory_issues -gt 0 ]]; then
            echo -e "  ${YELLOW}[MED]${NC} Found $memory_issues memory-related issues in logs"
            echo "performance:error:Memory issues|$memory_issues|journalctl | grep -i 'out of memory'" >> "$temp_file"
        fi
        
        # Check load average
        if [[ -f "/proc/loadavg" ]]; then
            local load=$(cat /proc/loadavg | awk '{print $1}')
            local cores=$(nproc)
            local load_per_core=$(echo "$load / $cores" | bc -l)
            
            if (( $(echo "$load_per_core > 1.5" | bc -l) )); then
                echo -e "  ${RED}[HIGH]${NC} Load average ($load) is high for $cores CPU cores"
                echo "performance:critical:High system load|$load|uptime" >> "$temp_file"
            elif (( $(echo "$load_per_core > 0.8" | bc -l) )); then
                echo -e "  ${YELLOW}[MED]${NC} Load average ($load) is elevated for $cores CPU cores"
                echo "performance:warning:Elevated system load|$load|uptime" >> "$temp_file"
            fi
        fi
        
        echo
    fi
    
    # === 4. Check for security issues ===
    if [[ -z "$category_filter" || "$category_filter" == "security" ]]; then
        echo -e "${BOLD}Security Concerns:${NC}"
        
        # Check for failed logins
        local failed_logins=$(journalctl --since="$time_filter" | grep -i -E "failed login|authentication failure|unauthorized|invalid user" | wc -l)
        if [[ $failed_logins -gt 10 ]]; then
            echo -e "  ${RED}[HIGH]${NC} Found $failed_logins failed login attempts"
            echo "security:critical:Failed login attempts|$failed_logins|journalctl | grep -i 'failed login'" >> "$temp_file"
        elif [[ $failed_logins -gt 0 ]]; then
            echo -e "  ${YELLOW}[MED]${NC} Found $failed_logins failed login attempts"
            echo "security:warning:Failed login attempts|$failed_logins|journalctl | grep -i 'failed login'" >> "$temp_file"
        else
            echo -e "  ${GREEN}No failed login attempts detected${NC}"
        fi
        
        # Check for permission issues
        local permission_issues=$(journalctl --since="$time_filter" | grep -i -E "permission denied|not authorized|operation not permitted" | wc -l)
        if [[ $permission_issues -gt 20 ]]; then
            echo -e "  ${YELLOW}[MED]${NC} Found $permission_issues permission issues"
            echo "security:warning:Permission denied issues|$permission_issues|journalctl | grep -i 'permission denied'" >> "$temp_file"
        fi
        
        # Check for potential intrusion attempts
        local intrusion_attempts=$(journalctl --since="$time_filter" | grep -i -E "possible break-in|intrusion|attack|exploit|malicious" | wc -l)
        if [[ $intrusion_attempts -gt 0 ]]; then
            echo -e "  ${RED}[HIGH]${NC} Found $intrusion_attempts potential intrusion attempts"
            echo "security:critical:Potential intrusion attempts|$intrusion_attempts|journalctl | grep -i 'attack\\|exploit'" >> "$temp_file"
        fi
        
        echo
    fi
    
    # === 5. Check for hardware issues ===
    if [[ -z "$category_filter" || "$category_filter" == "hardware" ]]; then
        echo -e "${BOLD}Hardware Issues:${NC}"
        
        # Check for hardware errors in kernel logs
        local hw_errors=$(journalctl --dmesg --since="$time_filter" | grep -i -E "hardware error|i/o error|bad sector|temperature|overheating|fan failure" | wc -l)
        if [[ $hw_errors -gt 0 ]]; then
            echo -e "  ${RED}[HIGH]${NC} Found $hw_errors hardware-related errors in kernel logs"
            
            # List the top hardware issues
            journalctl --dmesg --since="$time_filter" | grep -i -E "hardware error|i/o error|bad sector|temperature|overheating|fan failure" | 
                sort | uniq -c | sort -nr | head -n 3 | 
                awk '{printf "    - %d occurrences: %s\n", $1, substr($0, length($1) + 2)}'
            
            echo "hardware:critical:Hardware errors|$hw_errors|journalctl --dmesg | grep -i 'hardware error'" >> "$temp_file"
        else
            echo -e "  ${GREEN}No hardware issues detected${NC}"
        fi
        
        # Check for SMART errors if smartctl is available
        if command -v smartctl &> /dev/null; then
            echo -e "\n  ${CYAN}Disk SMART status:${NC}"
            # This requires root or sudo, so we'll just suggest it
            echo -e "    To check disk SMART status: ${CYAN}sudo smartctl -H /dev/sdX${NC}"
        fi
        
        echo
    fi
    
    # === 6. Check for application crashes ===
    if [[ -z "$category_filter" || "$category_filter" == "application" ]]; then
        echo -e "${BOLD}Application Crashes:${NC}"
        
        # Check for segfaults and crashes
        local crashes=$(journalctl --since="$time_filter" | grep -i -E "segfault|crash|core dumped|aborted|killed|terminated" | wc -l)
        if [[ $crashes -gt 5 ]]; then
            echo -e "  ${RED}[HIGH]${NC} Found $crashes application crashes"
            
            # List the applications that crashed most frequently
            journalctl --since="$time_filter" | grep -i -E "segfault|crash|core dumped|aborted|killed|terminated" | 
                grep -o -E '[a-zA-Z0-9_-]+\[[0-9]+\]' | sort | uniq -c | sort -nr | head -n 5 | 
                awk '{printf "    - %d crashes in %s\n", $1, $2}'
            
            echo "application:critical:Application crashes|$crashes|journalctl | grep -i 'segfault\\|crash'" >> "$temp_file"
        elif [[ $crashes -gt 0 ]]; then
            echo -e "  ${YELLOW}[MED]${NC} Found $crashes application crashes"
            echo "application:warning:Application crashes|$crashes|journalctl | grep -i 'segfault\\|crash'" >> "$temp_file"
        else
            echo -e "  ${GREEN}No application crashes detected${NC}"
        fi
        
        echo
    fi
    
    # === 7. Rank all issues by severity ===
    echo -e "${BOLD}${PURPLE}Overall Attention Priority:${NC}"
    
    # Sort the issues by severity
    if [[ -s "$temp_file" ]]; then
        # Extract and categorize issues
        grep -E "^[a-z]+:(critical|error|warning):" "$temp_file" | sort -t: -k2,2r -k3,3 | 
            awk -F'|' '{
                # Extract category, severity, and description
                split($1, parts, ":");
                category = parts[1];
                severity = parts[2];
                description = parts[3];
                count = $2;
                command = $3;
                
                # Set colors based on severity
                if (severity == "critical") {
                    color = "\033[31m";  # Red
                    sev_display = "CRITICAL";
                } else if (severity == "error") {
                    color = "\033[33m";  # Yellow
                    sev_display = "ERROR";
                } else {
                    color = "\033[36m";  # Cyan
                    sev_display = "WARNING";
                }
                
                # Set category color
                if (category == "system") cat_color = "\033[35m";      # Purple
                else if (category == "security") cat_color = "\033[31m"; # Red
                else if (category == "performance") cat_color = "\033[33m"; # Yellow
                else if (category == "hardware") cat_color = "\033[36m";   # Cyan
                else if (category == "application") cat_color = "\033[32m"; # Green
                else if (category == "network") cat_color = "\033[34m";   # Blue
                else cat_color = "\033[37m";  # White
                
                # Print formatted output
                printf "  %s[%s]\033[0m %s[%s]\033[0m %s (%s occurrences)\n", 
                       color, sev_display, cat_color, category, description, count;
                
                # Print command to investigate
                printf "    → \033[90mTo investigate: %s\033[0m\n", command;
            }'
    else
        echo -e "  ${GREEN}No critical issues detected${NC}"
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    echo
}

# Function to show top issues in the system
show_top_issues() {
    local num_issues="${1:-10}"
    local time_filter="${2:-24 hours ago}"
    local category_filter="$3"
    
    echo -e "${BOLD}${BLUE}Top $num_issues System Issues:${NC}"
    echo -e "${GRAY}Time range: since $time_filter${NC}"
    echo
    
    # Create a temporary file for storing issues
    local temp_file=$(mktemp)
    
    # === 1. Collect all errors from journal ===
    echo -e "${CYAN}Collecting error logs...${NC}"
    
    # Build the journalctl base command
    # Fix: Using priority ranges for critical logs (0-3)
    local base_cmd="journalctl --priority=0..3 --since=\"$time_filter\" --output=json"
    
    # Add category filter if specified
    if [[ -n "$category_filter" ]]; then
        case "$category_filter" in
            "system")
                base_cmd="$base_cmd -u systemd -u udev -u dbus -u polkit"
                ;;
            "security")
                base_cmd="$base_cmd -u apparmor -u audit -u sshd -u sudo"
                ;;
            "network")
                base_cmd="$base_cmd -u NetworkManager -u systemd-networkd -u ssh -u networking"
                ;;
            "hardware")
                base_cmd="$base_cmd --dmesg | grep -i -E 'hardware|device|disk|cpu|memory|thermal'"
                ;;
        esac
    fi
    
    # Extract error messages and group by frequency
    eval "$base_cmd" | 
        jq -r '._COMM + ": " + (.MESSAGE // "unknown")' 2>/dev/null | 
        sort | uniq -c | sort -nr | head -n "$num_issues" > "$temp_file"
    
    # Display the errors if found
    if [[ -s "$temp_file" ]]; then
        echo -e "${BOLD}Most Frequent Errors:${NC}"
        
        # Set counters for severity distribution
        local critical_count=0
        local error_count=0
        local warning_count=0
        
        # Process and categorize each error
        cat "$temp_file" | 
            awk -v n="$num_issues" '{
                # Determine severity based on message content and frequency
                severity = "ERROR";
                color = "\033[33m";  # Yellow for errors
                
                count = $1;
                
                # Extract service name and message
                service = substr($0, length($1) + 2);
                service_name = substr(service, 1, index(service, ":") - 1);
                message = substr(service, index(service, ":") + 2);
                
                # Determine severity based on count and content
                if (count > 50 || 
                    tolower(message) ~ /critical|emergency|fatal|kernel|panic|crash/) {
                    severity = "CRITICAL";
                    color = "\033[31m";  # Red for critical
                } else if (count < 5 && 
                          tolower(message) ~ /warning|deprecated|note/) {
                    severity = "WARNING";
                    color = "\033[36m";  # Cyan for warnings
                }
                
                # Truncate message if too long
                if (length(message) > 80) {
                    message = substr(message, 1, 77) "...";
                }
                
                # Print formatted output
                printf "  %s[%s]\033[0m %-15s (%d occurrences)\n", 
                       color, severity, service_name, count;
                printf "    → %s\n", message;
                
                # Track issue number
                issue_num++;
                
                # Add a separator if not the last item and more than one item
                if (issue_num < n && issue_num < NR) {
                    print "    --------";
                }
            }'
        
        # Additional info - show log file locations
        echo -e "\n${BOLD}Log File Locations:${NC}"
        
        # Extract unique service names from the error list
        cat "$temp_file" | 
            awk '{
                service = substr($0, length($1) + 2);
                service_name = substr(service, 1, index(service, ":") - 1);
                print service_name;
            }' | sort -u | head -n 5 > "$temp_file.services"
        
        # For each service, find the log files
        while read -r service; do
            echo -e "  ${YELLOW}${service}${NC}:"
            
            # Look in journald
            echo -e "    • Journald: ${GRAY}journalctl _COMM=\"$service\" --priority=0..3${NC}"
            
            # Check for log files in various locations
            local log_files=""
            
            # System logs
            for path in "/var/log" "/var/log/syslog" "/var/log/messages"; do
                if [[ -e "$path" ]]; then
                    local found_logs=$(find "$path" -type f -name "*${service}*" 2>/dev/null | head -n 3)
                    if [[ -n "$found_logs" ]]; then
                        log_files="${log_files}${found_logs}\n"
                    fi
                fi
            done
            
            # User logs
            for path in "$HOME/.local/share/logs" "$HOME/.cache/logs"; do
                if [[ -e "$path" ]]; then
                    local found_logs=$(find "$path" -type f -name "*${service}*" 2>/dev/null | head -n 2)
                    if [[ -n "$found_logs" ]]; then
                        log_files="${log_files}${found_logs}\n"
                    fi
                fi
            done
            
            # Print the log files if found
            if [[ -n "$log_files" ]]; then
                echo -e "$log_files" | awk '{printf "    • Log file: \033[36m%s\033[0m\n", $0}'
            fi
        done < "$temp_file.services"
    else
        echo -e "${GREEN}No critical issues found in the specified time range.${NC}"
    fi
    
    # Clean up
    rm -f "$temp_file" "$temp_file.services"
    
    echo
}

# Function to show error and warning trends over time
show_trends() {
    local days="${1:-7}"
    
    echo -e "${BOLD}${BLUE}System Error and Warning Trends:${NC}"
    echo -e "${GRAY}Past $days days${NC}"
    echo
    
    # Create an array of dates to analyze
    local -a dates=()
    for ((i=0; i<days; i++)); do
        dates+=($(date -d "$i days ago" +%Y-%m-%d))
    done
    
    # Prepare data collection
    local temp_file=$(mktemp)
    
    # Track error counts for each day by priority
    echo -e "${BOLD}Daily Error Counts:${NC}"
    echo -e "  ${GRAY}Date       Critical   Error     Warning   Info      ${NC}"
    echo -e "  ${GRAY}--------------------------------------------------${NC}"
    
    for date in "${dates[@]}"; do
        # Get error counts for each priority
        # Fix: Using priority ranges for critical logs (0-2 for critical, 3 for error, 4 for warning)
        local critical=$(journalctl --since="$date 00:00:00" --until="$date 23:59:59" --priority=0..2 | wc -l)
        local error=$(journalctl --since="$date 00:00:00" --until="$date 23:59:59" --priority=3 | wc -l)
        local warning=$(journalctl --since="$date 00:00:00" --until="$date 23:59:59" --priority=4 | wc -l)
        local info=$(journalctl --since="$date 00:00:00" --until="$date 23:59:59" --priority=6 | wc -l)
        
        # Store data for later ASCII visualization
        echo "$date $critical $error $warning $info" >> "$temp_file"
        
        # Determine colors based on counts
        local crit_color=$GREEN
        local err_color=$GREEN
        local warn_color=$GREEN
        
        if [[ $critical -gt 20 ]]; then crit_color=$RED
        elif [[ $critical -gt 5 ]]; then crit_color=$YELLOW
        fi
        
        if [[ $error -gt 100 ]]; then err_color=$RED
        elif [[ $error -gt 30 ]]; then err_color=$YELLOW
        fi
        
        if [[ $warning -gt 200 ]]; then warn_color=$YELLOW
        fi
        
        # Format the display date to be more readable
        local display_date=$(date -d "$date" +"%a %m-%d")
        
        # Print the data row with colors
        printf "  %-10s ${crit_color}%-10d${NC} ${err_color}%-10d${NC} ${warn_color}%-10d${NC} %-10d\n" \
               "$display_date" "$critical" "$error" "$warning" "$info"
    done
    
    # Create a simple ASCII bar chart for critical and error trends
    echo -e "\n${BOLD}Error Trend Visualization:${NC}"
    echo -e "  ${GRAY}(Each █ represents significant errors)${NC}\n"
    
    # Process the data for visualization
    local max_critical=0
    local max_error=0
    
    # Find the maximum values for scaling
    while read -r date critical error warning info; do
        if [[ $critical -gt $max_critical ]]; then
            max_critical=$critical
        fi
        if [[ $error -gt $max_error ]]; then
            max_error=$error
        fi
    done < "$temp_file"
    
    # Ensure we don't divide by zero
    if [[ $max_critical -eq 0 ]]; then max_critical=1; fi
    if [[ $max_error -eq 0 ]]; then max_error=1; fi
    
    # Create the ASCII chart
    while read -r date critical error warning info; do
        # Scale values to a maximum of 20 characters
        local crit_bars=$(( critical * 20 / max_critical ))
        local err_bars=$(( error * 20 / max_error ))
        
        # Ensure at least one bar for non-zero values
        if [[ $critical -gt 0 && $crit_bars -eq 0 ]]; then crit_bars=1; fi
        if [[ $error -gt 0 && $err_bars -eq 0 ]]; then err_bars=1; fi
        
        # Format the display date to be more readable
        local display_date=$(date -d "$date" +"%a %m-%d")
        
        # Critical errors (red)
        printf "  %-10s ${RED}" "$display_date"
        for ((i=0; i<crit_bars; i++)); do
            printf "█"
        done
        printf "${NC} $critical critical\n"
        
        # Regular errors (yellow)
        printf "  %-10s ${YELLOW}" "          "
        for ((i=0; i<err_bars; i++)); do
            printf "█"
        done
        printf "${NC} $error errors\n"
    done < "$temp_file"
    
    # Show most affected services over the time period
    echo -e "\n${BOLD}Most Affected Services:${NC}"
    
    # Fix: Using priority ranges for critical logs (0-3)
    journalctl --priority=0..3 --since="$days days ago" --output=json | 
        jq -r '.SYSLOG_IDENTIFIER // ._COMM // "unknown"' 2>/dev/null | 
        sort | uniq -c | sort -nr | head -n 5 | 
        awk '{
            count = $1;
            service = substr($0, length($1) + 2);
            
            # Set color based on count
            if (count > 100) color = "\033[31m";
            else if (count > 30) color = "\033[33m";
            else color = "\033[32m";
            
            printf "  %s%-20s\033[0m %5d errors\n", color, service, count;
        }'
    
    # Clean up
    rm -f "$temp_file"
    
    echo
}

# Function to generate a comprehensive system health report
generate_health_report() {
    local output_file="${1:-${CONFIG_DIR}/health_report_$(date +%Y-%m-%d).txt}"
    
    echo -e "${BOLD}${BLUE}Generating System Health Report:${NC}"
    echo -e "  Output file: ${CYAN}$output_file${NC}"
    echo
    
    # Start capturing output
    exec > >(tee "$output_file") 2>&1
    
    echo "============================================="
    echo "          SYSTEM HEALTH REPORT"
    echo "          Generated: $(date)"
    echo "============================================="
    echo
    
    # System Overview
    echo "SYSTEM OVERVIEW"
    echo "--------------------------------------------"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)"
    echo "Uptime: $(uptime -p)"
    echo
    
    # System Resources
    echo "SYSTEM RESOURCES"
    echo "--------------------------------------------"
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)" | sed 's/,/\n        /g'
    echo
    echo "Memory Usage:"
    free -h
    echo
    echo "Disk Usage:"
    df -h | grep -v "tmpfs\|udev\|loop"
    echo
    
    # Service Status
    echo "SERVICE STATUS"
    echo "--------------------------------------------"
    if command -v systemctl &> /dev/null; then
        echo "Failed Services:"
        systemctl list-units --state=failed --no-legend || echo "None"
        echo
    fi
    
    # Error Analysis
    echo "ERROR ANALYSIS (Last 24 Hours)"
    echo "--------------------------------------------"
    echo "Priority Distribution:"
    
    # Count errors by priority
    for priority in "${PRIORITIES[@]}"; do
        local count=$(journalctl --priority=$priority --since="24 hours ago" | wc -l)
        echo "  $priority: $count entries"
    done
    echo
    
    echo "Top Error Sources:"
    # Fix: Using priority ranges for critical logs (0-3)
    journalctl --priority=0..3 --since="24 hours ago" --output=json | 
        jq -r '.SYSLOG_IDENTIFIER // ._COMM // "unknown"' 2>/dev/null | 
        sort | uniq -c | sort -nr | head -n 10 | 
        awk '{printf "  %4d errors from %s\n", $1, substr($0, length($1) + 2)}'
    echo
    
    # Areas Needing Attention
    echo "AREAS NEEDING ATTENTION"
    echo "--------------------------------------------"
    show_attention_areas "24 hours ago" | grep -v "^Areas Needing Attention"
    echo
    
    # Security Analysis
    echo "SECURITY ANALYSIS"
    echo "--------------------------------------------"
    echo "Failed Login Attempts (Last 24 Hours):"
    journalctl --since="24 hours ago" | grep -i -E "failed login|authentication failure|invalid user" | wc -l
    echo
    
    echo "Recent SSH Activity:"
    journalctl _COMM=sshd --since="24 hours ago" | grep -i -E "session opened|session closed|accepted|connection closed" | tail -n 10
    echo
    
    # System Performance
    echo "PERFORMANCE ANALYSIS"
    echo "--------------------------------------------"
    echo "Process Count: $(ps aux | wc -l)"
    echo
    echo "Top CPU Consumers:"
    ps aux --sort=-%cpu | head -n 6 | awk '{printf "  %-10s %5.1f%% CPU, %5.1f%% MEM - %s\n", $1, $3, $4, $11}'
    echo
    echo "Top Memory Consumers:"
    ps aux --sort=-%mem | head -n 6 | awk '{printf "  %-10s %5.1f%% MEM, %5.1f%% CPU - %s\n", $1, $4, $3, $11}'
    echo
    
    # Recommendations
    echo "RECOMMENDATIONS"
    echo "--------------------------------------------"
    
    # Generate recommendations based on findings
    local recs=0
    
    # Check for failed services
    if systemctl list-units --state=failed --no-legend | grep -q .; then
        echo "  • Investigate and restart failed services"
        recs=$((recs+1))
    fi
    
    # Check disk space
    if df -h | grep -v "tmpfs\|udev\|loop" | awk '{ gsub(/%/,""); if($5 > 85) exit 0; exit 1 }'; then
        echo "  • Free up disk space on volumes that are >85% full"
        recs=$((recs+1))
    fi
    
    # Check for high error rates
    # Fix: Using priority ranges for critical logs (0-3)
    if [[ $(journalctl --priority=0..3 --since="24 hours ago" | wc -l) -gt 50 ]]; then
        echo "  • Investigate high error rates in logs"
        recs=$((recs+1))
    fi
    
    # Check for security issues
    if [[ $(journalctl --since="24 hours ago" | grep -i -E "failed login|authentication failure|invalid user" | wc -l) -gt 10 ]]; then
        echo "  • Review failed login attempts for potential security issues"
        recs=$((recs+1))
    fi
    
    # Add a general recommendation if none specific were found
    if [[ $recs -eq 0 ]]; then
        echo "  • System appears to be functioning normally, continue regular monitoring"
    fi
    
    echo
    
    # End of report
    echo "============================================="
    echo "END OF REPORT"
    echo "Generated with sawlog version $TOOL_VERSION"
    echo "Run '$TOOL_NAME --setup-monitor' to enable continuous monitoring"
    echo "============================================="
    
    # Restore output
    exec >&- 2>&-
    exec > /dev/tty 2>&1
    
    echo -e "${GREEN}Health report generated successfully at:${NC}"
    echo -e "${CYAN}$output_file${NC}"
    echo
}