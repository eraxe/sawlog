#!/bin/bash
# sawlog-monitor - Background log monitoring service for sawlog
# This script is intended to be run as a systemd service

# Get the path to the sawlog executable
SAWLOG_PATH=$(which sawlog)
if [[ -z "$SAWLOG_PATH" ]]; then
    SAWLOG_PATH="$HOME/.local/bin/sawlog"
    if [[ ! -x "$SAWLOG_PATH" ]]; then
        echo "Error: sawlog executable not found"
        exit 1
    fi
fi

# Configuration directories
CONFIG_DIR="${HOME}/.config/sawlog"
MONITOR_CONFIG="${CONFIG_DIR}/monitor.conf"
NOTIFICATION_CONFIG="${CONFIG_DIR}/notification.conf"
STATS_CACHE_DIR="${CONFIG_DIR}/stats_cache"
TEMP_DIR="/tmp/sawlog-monitor-$(id -u)"

# Create temporary and cache directories if they don't exist
mkdir -p "$STATS_CACHE_DIR"
mkdir -p "$TEMP_DIR"

# Load configurations
if [[ -f "$MONITOR_CONFIG" ]]; then
    source "$MONITOR_CONFIG"
else
    echo "Error: Monitor configuration file not found at $MONITOR_CONFIG"
    exit 1
fi

if [[ -f "$NOTIFICATION_CONFIG" ]]; then
    source "$NOTIFICATION_CONFIG"
else
    echo "Error: Notification configuration file not found at $NOTIFICATION_CONFIG"
    exit 1
fi

# Check if monitoring is enabled
if [[ "$ENABLE_MONITORING" != "true" ]]; then
    echo "Monitoring is disabled in $MONITOR_CONFIG"
    exit 0
fi

# Function to send notifications
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="$3"
    local category="$4"
    
    # Check if we're in do not disturb mode
    if [[ "$DO_NOT_DISTURB" == "true" ]]; then
        current_time=$(date +%H:%M)
        if is_time_between "$current_time" "$DND_START_TIME" "$DND_END_TIME"; then
            # In do not disturb period, only log, don't notify
            echo "$(date): [DND MODE] $title - $message" >> "$NOTIFICATION_LOG"
            return
        fi
    fi
    
    # Rate limiting check
    if ! check_rate_limit "$title" "$message"; then
        # Skipping due to rate limit
        return
    fi
    
    # Generate notification ID based on content for tracking similar notifications
    notification_id=$(echo "$title $message" | md5sum | cut -d' ' -f1)
    
    # Log to notification log if enabled
    if [[ "$USE_LOG_FILE" == "true" ]]; then
        echo "$(date): [$urgency] $title - $message" >> "$NOTIFICATION_LOG"
    fi
    
    # Send desktop notification if enabled
    if [[ "$USE_DESKTOP_NOTIFICATIONS" == "true" ]]; then
        if command -v notify-send &> /dev/null; then
            notify-send --app-name="Sawlog Monitor" \
                        --urgency="$urgency" \
                        --expire-time="$NOTIFICATION_TIMEOUT" \
                        --category="$category" \
                        --hint="string:desktop-entry:sawlog" \
                        "$title" "$message"
        elif command -v zenity &> /dev/null; then
            (zenity --notification --text="$title: $message" &) 
        elif command -v kdialog &> /dev/null; then
            kdialog --title "$title" --passivepopup "$message" "$((NOTIFICATION_TIMEOUT / 1000))"
        fi
    fi
    
    # Send email notification if enabled
    if [[ "$USE_EMAIL_NOTIFICATIONS" == "true" && -n "$EMAIL_RECIPIENT" ]]; then
        if command -v mail &> /dev/null; then
            echo "$message" | mail -s "$EMAIL_SUBJECT_PREFIX $title" "$EMAIL_RECIPIENT"
        fi
    fi
    
    # Store notification for rate limiting
    echo "$(date +%s)|$notification_id|$title|$message" >> "$TEMP_DIR/recent_notifications.log"
}

# Function to check rate limiting
check_rate_limit() {
    local title="$1"
    local message="$2"
    
    # Create rate limit file if it doesn't exist
    if [[ ! -f "$TEMP_DIR/recent_notifications.log" ]]; then
        touch "$TEMP_DIR/recent_notifications.log"
    fi
    
    # Clear old entries from the rate limit file
    local current_time=$(date +%s)
    local threshold=$((current_time - RATE_LIMIT_PERIOD))
    
    # Create a temporary file with only recent notifications
    grep -v "^[0-9]\+|" "$TEMP_DIR/recent_notifications.log" > "$TEMP_DIR/recent_notifications.tmp" || true
    awk -F"|" -v threshold="$threshold" '$1 >= threshold' "$TEMP_DIR/recent_notifications.log" >> "$TEMP_DIR/recent_notifications.tmp" 2>/dev/null || true
    mv "$TEMP_DIR/recent_notifications.tmp" "$TEMP_DIR/recent_notifications.log"
    
    # Count recent notifications
    local recent_count=$(wc -l < "$TEMP_DIR/recent_notifications.log")
    
    # Check if we've exceeded the maximum notifications per period
    if [[ "$recent_count" -ge "$MAX_NOTIFICATIONS_PER_PERIOD" ]]; then
        # Log that we're rate limiting
        echo "$(date): [RATE LIMITED] $title - $message" >> "$NOTIFICATION_LOG"
        return 1
    fi
    
    # Check for similar notifications if enabled
    if [[ "$RATE_LIMIT_SIMILAR" == "true" ]]; then
        local notification_id=$(echo "$title $message" | md5sum | cut -d' ' -f1)
        local similar_threshold=$((current_time - SIMILAR_NOTIFICATION_TIMEOUT))
        
        # Look for similar notifications within the timeout period
        while IFS="|" read -r timestamp id title_old message_old; do
            if [[ "$timestamp" -ge "$similar_threshold" && "$id" == "$notification_id" ]]; then
                # Similar notification found within timeout period
                echo "$(date): [SIMILAR RATE LIMITED] $title - $message" >> "$NOTIFICATION_LOG"
                return 1
            fi
        done < "$TEMP_DIR/recent_notifications.log"
    fi
    
    return 0
}

# Function to check if current time is between start and end times
is_time_between() {
    local current="$1"
    local start="$2"
    local end="$3"
    
    # Convert times to minutes since midnight for easier comparison
    local curr_minutes=$((10#${current%:*} * 60 + 10#${current#*:}))
    local start_minutes=$((10#${start%:*} * 60 + 10#${start#*:}))
    local end_minutes=$((10#${end%:*} * 60 + 10#${end#*:}))
    
    # Handle times that cross midnight
    if [[ "$start_minutes" -gt "$end_minutes" ]]; then
        # Time range crosses midnight
        if [[ "$curr_minutes" -ge "$start_minutes" || "$curr_minutes" -le "$end_minutes" ]]; then
            return 0
        else
            return 1
        fi
    else
        # Normal time range
        if [[ "$curr_minutes" -ge "$start_minutes" && "$curr_minutes" -le "$end_minutes" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to collect system statistics
collect_system_stats() {
    # Create daily stats directory if it doesn't exist
    local today=$(date +%Y-%m-%d)
    local stats_dir="$STATS_CACHE_DIR/$today"
    mkdir -p "$stats_dir"
    
    # Collect log statistics for monitored services
    for service_spec in $MONITORED_SERVICES; do
        IFS=':' read -r service_type service_name <<< "$service_spec"
        
        # Determine the correct journalctl command
        case "$service_type" in
            "system")
                if [[ -n "$service_name" ]]; then
                    cmd="journalctl -u \"$service_name\" --since=\"$MONITORING_INTERVAL seconds ago\" --no-pager"
                else
                    continue
                fi
                ;;
            "user")
                if [[ -n "$service_name" ]]; then
                    cmd="journalctl --user -u \"$service_name\" --since=\"$MONITORING_INTERVAL seconds ago\" --no-pager"
                else
                    continue
                fi
                ;;
            "kernel")
                cmd="journalctl --dmesg --since=\"$MONITORING_INTERVAL seconds ago\" --no-pager"
                service_name="kernel"
                ;;
            *)
                continue
                ;;
        esac
        
        # Skip if service name is still empty
        if [[ -z "$service_name" ]]; then
            continue
        fi
        
        # Count entries by priority
        service_file="$stats_dir/${service_type}_${service_name//\//_}.json"
        
        # Initialize counts
        critical_count=0
        error_count=0
        warning_count=0
        
        # Count entries for critical priorities
        critical_count=$(eval "$cmd --priority=emerg,alert,crit" | wc -l)
        
        # Count entries for error priority
        error_count=$(eval "$cmd --priority=err" | wc -l)
        
        # Count entries for warning priority
        warning_count=$(eval "$cmd --priority=warning" | wc -l)
        
        # Get total entries
        total_count=$(eval "$cmd" | wc -l)
        
        # Get the current hour
        local hour=$(date +%H)
        
        # Create or update the service stats file
        if [[ -f "$service_file" ]]; then
            # Update existing stats
            jq --arg hour "$hour" \
               --arg critical "$critical_count" \
               --arg error "$error_count" \
               --arg warning "$warning_count" \
               --arg total "$total_count" \
               --arg type "$service_type" \
               --arg name "$service_name" \
               '.service_type = $type | 
                .service_name = $name | 
                .hourly_stats[$hour].critical_count = ($critical | tonumber) | 
                .hourly_stats[$hour].error_count = ($error | tonumber) | 
                .hourly_stats[$hour].warning_count = ($warning | tonumber) | 
                .hourly_stats[$hour].total_count = ($total | tonumber) | 
                .total_critical = ((.total_critical // 0) + ($critical | tonumber)) | 
                .total_errors = ((.total_errors // 0) + ($error | tonumber)) | 
                .total_warnings = ((.total_warnings // 0) + ($warning | tonumber)) | 
                .total_entries = ((.total_entries // 0) + ($total | tonumber))' \
               "$service_file" > "$service_file.tmp" && mv "$service_file.tmp" "$service_file"
        else
            # Create new stats file
            cat > "$service_file" << EOF
{
  "service_type": "$service_type",
  "service_name": "$service_name",
  "date": "$(date +%Y-%m-%d)",
  "hourly_stats": {
    "$hour": {
      "critical_count": $critical_count,
      "error_count": $error_count,
      "warning_count": $warning_count,
      "total_count": $total_count
    }
  },
  "total_critical": $critical_count,
  "total_errors": $error_count,
  "total_warnings": $warning_count,
  "total_entries": $total_count
}
EOF
        fi
        
        # Check thresholds and alert if necessary
        if [[ "$critical_count" -ge "$CRITICAL_THRESHOLD" ]]; then
            send_notification "Critical Alert: $service_name" \
                              "Detected $critical_count critical messages in the last monitoring interval" \
                              "$NOTIFICATION_URGENCY_CRITICAL" \
                              "system.alert"
        elif [[ "$error_count" -ge "$ERROR_THRESHOLD" ]]; then
            send_notification "Error Alert: $service_name" \
                              "Detected $error_count error messages in the last monitoring interval" \
                              "$NOTIFICATION_URGENCY_ERROR" \
                              "system.alert"
        elif [[ "$warning_count" -ge "$WARNING_THRESHOLD" ]]; then
            send_notification "Warning Alert: $service_name" \
                              "Detected $warning_count warning messages in the last monitoring interval" \
                              "$NOTIFICATION_URGENCY_WARNING" \
                              "system.alert"
        fi
    done
    
    # Collect system health metrics if enabled
    if [[ "$MONITOR_CPU_USAGE" == "true" || "$MONITOR_MEMORY_USAGE" == "true" || 
          "$MONITOR_DISK_USAGE" == "true" || "$MONITOR_FAILED_SERVICES" == "true" ]]; then
        
        local health_file="$stats_dir/system_health.json"
        local hour=$(date +%H)
        
        # Initialize the health data structure
        local health_data='{"date":"'$(date +%Y-%m-%d)'","timestamp":'$(date +%s)',"hourly_metrics":{}}'
        
        # CPU usage
        if [[ "$MONITOR_CPU_USAGE" == "true" ]]; then
            local cpu_usage=0
            if command -v mpstat &> /dev/null; then
                # Use mpstat if available for accurate CPU usage
                cpu_usage=$(mpstat 1 1 | awk '/^Average:/ {print 100 - $NF}')
            else
                # Fallback to top for CPU usage
                cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
            fi
            
            health_data=$(echo "$health_data" | jq --arg hour "$hour" \
                                              --arg cpu "$cpu_usage" \
                                              '.hourly_metrics[$hour].cpu_usage = ($cpu | tonumber)')
            
            # Alert if CPU usage exceeds threshold
            if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
                send_notification "High CPU Usage" \
                                  "CPU usage at ${cpu_usage}% exceeds threshold of ${CPU_THRESHOLD}%" \
                                  "$NOTIFICATION_URGENCY_WARNING" \
                                  "system.resource"
            fi
        fi
        
        # Memory usage
        if [[ "$MONITOR_MEMORY_USAGE" == "true" ]]; then
            local mem_total=$(free | grep Mem | awk '{print $2}')
            local mem_used=$(free | grep Mem | awk '{print $3}')
            local mem_usage=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc)
            
            health_data=$(echo "$health_data" | jq --arg hour "$hour" \
                                              --arg mem "$mem_usage" \
                                              '.hourly_metrics[$hour].memory_usage = ($mem | tonumber)')
            
            # Alert if memory usage exceeds threshold
            if (( $(echo "$mem_usage > $MEMORY_THRESHOLD" | bc -l) )); then
                send_notification "High Memory Usage" \
                                  "Memory usage at ${mem_usage}% exceeds threshold of ${MEMORY_THRESHOLD}%" \
                                  "$NOTIFICATION_URGENCY_WARNING" \
                                  "system.resource"
            fi
        fi
        
        # Disk usage
        if [[ "$MONITOR_DISK_USAGE" == "true" ]]; then
            # Get disk usage for all mounted filesystems
            local disk_data=$(df -h | grep -v "Filesystem" | awk '{print $1 "," $5}' | sed 's/%//g')
            
            local disk_json='{'
            local first=true
            
            while IFS=',' read -r fs usage; do
                # Skip if filesystem name is empty
                if [[ -z "$fs" ]]; then
                    continue
                fi
                
                # Add comma for all but the first entry
                if ! $first; then
                    disk_json+=', '
                else
                    first=false
                fi
                
                # Clean the filesystem name for use as a JSON key
                local fs_clean=$(echo "$fs" | sed 's/[^a-zA-Z0-9]/_/g')
                disk_json+="\"$fs_clean\": $usage"
                
                # Alert if disk usage exceeds threshold
                if (( $(echo "$usage > $DISK_THRESHOLD" | bc -l) )); then
                    send_notification "High Disk Usage: $fs" \
                                      "Disk usage at ${usage}% exceeds threshold of ${DISK_THRESHOLD}%" \
                                      "$NOTIFICATION_URGENCY_WARNING" \
                                      "system.resource"
                fi
            done <<< "$disk_data"
            
            disk_json+='}'
            
            health_data=$(echo "$health_data" | jq --arg hour "$hour" \
                                              --argjson disk "$disk_json" \
                                              '.hourly_metrics[$hour].disk_usage = $disk')
        fi
        
        # Failed services
        if [[ "$MONITOR_FAILED_SERVICES" == "true" ]]; then
            # Get list of failed systemd services
            local failed_services=$(systemctl --failed --no-legend | awk '{print $1}')
            local failed_count=$(echo "$failed_services" | grep -v '^$' | wc -l)
            
            health_data=$(echo "$health_data" | jq --arg hour "$hour" \
                                              --arg count "$failed_count" \
                                              '.hourly_metrics[$hour].failed_services = ($count | tonumber)')
            
            if [[ "$failed_count" -gt 0 ]]; then
                local service_list=$(echo "$failed_services" | tr '\n' ' ')
                send_notification "Failed Services Detected" \
                                  "$failed_count services failed: $service_list" \
                                  "$NOTIFICATION_URGENCY_ERROR" \
                                  "system.service"
            fi
        fi
        
        # Save health data
        echo "$health_data" > "$health_file"
        
        # Create a symlink to the latest health data for easy access
        ln -sf "$health_file" "$STATS_CACHE_DIR/latest_health.json"
    fi
    
    # Clean up old stats files if retention period is set
    if [[ -n "$STATS_RETENTION_DAYS" && "$STATS_RETENTION_DAYS" -gt 0 ]]; then
        find "$STATS_CACHE_DIR" -type d -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" -mtime +"$STATS_RETENTION_DAYS" -exec rm -rf {} \; 2>/dev/null || true
    fi
}

# Main monitoring loop
while true; do
    # Collect system statistics
    collect_system_stats
    
    # Sleep until next monitoring interval
    sleep "$MONITORING_INTERVAL"
done