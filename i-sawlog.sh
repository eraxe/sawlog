#!/bin/bash

# sawlog - Advanced journalctl log viewer and extractor
# Version: 2.0

# Constants
TOOL_NAME="sawlog"
INSTALL_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/sawlog"
COMPLETION_FILE="/etc/bash_completion.d/sawlog_completion"
ZSH_COMPLETION_FILE="${HOME}/.zsh/completions/_sawlog"
BOOKMARK_FILE="${CONFIG_DIR}/bookmarks.conf"
THEME_FILE="${CONFIG_DIR}/theme.conf"
MONITOR_CONFIG="${CONFIG_DIR}/monitor.conf"
NOTIFICATION_CONFIG="${CONFIG_DIR}/notification.conf"
SERVICE_FILE="/etc/systemd/system/sawlog-monitor.service"
USER_SERVICE_FILE="${HOME}/.config/systemd/user/sawlog-monitor.service"
MONITOR_SCRIPT="${INSTALL_DIR}/sawlog-monitor"
STATS_CACHE_DIR="${CONFIG_DIR}/stats_cache"
SYSTEM_HEALTH_FILE="${STATS_CACHE_DIR}/system_health.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# Default priorities for filtering
PRIORITIES=(emerg alert crit err warning notice info debug)

# Warning categories
WARNING_CATEGORIES=(
  "system:critical:System critical issues that require immediate attention"
  "system:error:System errors that may impact functionality"
  "system:warning:System warnings that should be monitored"
  "security:critical:Security critical issues (potential breaches, attacks)"
  "security:warning:Security warnings (failed logins, suspicious activity)"
  "performance:critical:Performance critical issues (resource exhaustion)"
  "performance:warning:Performance warnings (high load, slow response times)"
  "application:error:Application errors (crashes, exceptions)"
  "application:warning:Application warnings (deprecated calls, minor issues)"
  "network:error:Network errors (connection failures, timeouts)"
  "network:warning:Network warnings (packet loss, retransmissions)"
  "hardware:critical:Hardware critical issues (device failures)"
  "hardware:warning:Hardware warnings (temperature, SMART warnings)"
)

# Functions
show_help() {
    echo -e "${BOLD}${TOOL_NAME}${NC} - Advanced journalctl log viewer and extractor"
    echo
    echo "Usage:"
    echo "  $TOOL_NAME [OPTIONS] [SERVICE_PATTERN]"
    echo
    echo "Core Options:"
    echo "  -h, --help              Show this help message"
    echo "  -i, --install           Install the tool to $INSTALL_DIR"
    echo "  -u, --uninstall         Uninstall the tool"
    echo "  -v, --version           Show version information"
    echo
    echo "Search & Display Options:"
    echo "  -n, --lines NUMBER      Number of log lines to show (default: 50)"
    echo "  -f, --follow            Follow logs in real-time (like tail -f)"
    echo "  -p, --priority LEVEL    Filter by priority (emerg,alert,crit,err,warning,notice,info,debug)"
    echo "  -g, --grep PATTERN      Filter logs by pattern"
    echo "  -H, --highlight PATTERN Highlight pattern in logs without filtering"
    echo "  -o, --output FORMAT     Output format (short,short-precise,verbose,json,cat,pretty)"
    echo "  -s, --system            Force search in system services"
    echo "  -U, --user              Force search in user services"
    echo "  -m, --multi \"SVC1 SVC2\" View logs from multiple services"
    echo "  -a, --all               Show logs from all services"
    echo "  -k, --kernel            Show kernel messages only"
    echo "  -x, --expand            Show full message text (no wrapping/truncation)"
    echo
    echo "Time Options:"
    echo "  -t, --time STRING       Show entries since TIME (e.g. 'yesterday', '2h ago')"
    echo "  -T, --until STRING      Show entries until TIME"
    echo "  --today                 Show entries from today"
    echo "  --yesterday             Show entries from yesterday"
    echo
    echo "Output Options:"
    echo "  -c, --clipboard         Copy output to clipboard"
    echo "  -F, --file FILENAME     Save output to file"
    echo "  -j, --json              Output logs in JSON format (shortcut for -o json)"
    echo "  -E, --export FORMAT     Export as html, csv, or markdown"
    echo "  -r, --reverse           Show logs in reverse order (oldest first)"
    echo
    echo "Bookmark & Management:"
    echo "  --bookmark NAME         Add current service/query to bookmarks"
    echo "  --bookmarks             List saved bookmarks"
    echo "  --use BOOKMARK          Use a saved bookmark"
    echo "  --refresh               Refresh service cache"
    echo "  --status                Show service status alongside logs"
    echo "  -l, --list              List all available services"
    echo
    echo "Statistics & Monitoring:"
    echo "  --stats                 Show log statistics (service frequency, error rates)"
    echo "  --system-stats          Show system-wide process statistics and health metrics"
    echo "  --attention             Show areas that need attention, sorted by severity"
    echo "  --top-issues [N]        Show top N services with issues (default: 10)"
    echo "  --category TYPE         Filter by category (system, security, performance, etc.)"
    echo "  --setup-monitor         Setup the log monitoring service"
    echo "  --disable-monitor       Disable the log monitoring service"
    echo "  --configure-notifications Configure notification preferences"
    echo "  --health-report         Generate a system health report"
    echo "  --trends [days]         Show error and warning trends over time (default: 7 days)"
    echo
    echo "Examples:"
    echo "  $TOOL_NAME plasma                       # Interactive search for plasma services"
    echo "  $TOOL_NAME -n 100 sshd                  # Show last 100 lines of sshd logs"
    echo "  $TOOL_NAME -c -n 20 kwin                # Copy last 20 lines of kwin logs to clipboard"
    echo "  $TOOL_NAME -F kwin.log -t '1h ago' kwin_wayland    # Save kwin_wayland logs from last hour"
    echo "  $TOOL_NAME -f -p err,crit NetworkManager # Follow error logs for NetworkManager"
    echo "  $TOOL_NAME -m \"sshd NetworkManager\"     # View logs from multiple services"
    echo "  $TOOL_NAME --bookmark \"my-sshd\" -f -p err sshd  # Bookmark this query for later use"
    echo "  $TOOL_NAME --use my-sshd                # Use saved bookmark"
    echo "  $TOOL_NAME --stats -t \"1 day ago\"       # Show log statistics for the past day"
    echo "  $TOOL_NAME --system-stats               # Show system-wide process statistics"
    echo "  $TOOL_NAME --attention                  # Show areas that need attention"
    echo "  $TOOL_NAME --top-issues 5               # Show top 5 problematic services"
    echo "  $TOOL_NAME --setup-monitor              # Setup log monitoring service"
    echo "  $TOOL_NAME --health-report              # Generate a system health report"
}

check_dependencies() {
    local missing_deps=()
    
    # Check for journalctl
    if ! command -v journalctl &> /dev/null; then
        missing_deps+=("journalctl (systemd)")
    fi
    
    # Check for systemctl if status is requested
    if [[ -n "$show_status" ]] && ! command -v systemctl &> /dev/null; then
        missing_deps+=("systemctl (for service status)")
    fi
    
    # Check for clipboard tools
    CLIPBOARD_TOOL=""
    if command -v xclip &> /dev/null; then
        CLIPBOARD_TOOL="xclip"
    elif command -v wl-copy &> /dev/null; then
        CLIPBOARD_TOOL="wl-copy"
    elif command -v pbcopy &> /dev/null; then
        CLIPBOARD_TOOL="pbcopy"
    fi
    
    # If clipboard was requested but no tool is available
    if [[ -z "$CLIPBOARD_TOOL" && -n "$to_clipboard" ]]; then
        missing_deps+=("xclip, wl-copy, or pbcopy (for clipboard support)")
    fi
    
    # Check for notification tools
    NOTIFICATION_TOOL=""
    if command -v notify-send &> /dev/null; then
        NOTIFICATION_TOOL="notify-send"
    elif command -v zenity &> /dev/null; then
        NOTIFICATION_TOOL="zenity"
    elif command -v kdialog &> /dev/null; then
        NOTIFICATION_TOOL="kdialog"
    fi
    
    # Check for jq (JSON parsing) - required for enhanced stats
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq (for enhanced statistics)")
    fi
    
    # Check for bc (calculator) - required for trend analysis
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc (for trend calculations)")
    fi
    
    # Check for export tools
    if [[ -n "$export_format" ]]; then
        case "$export_format" in
            html)
                if ! command -v pandoc &> /dev/null; then
                    missing_deps+=("pandoc (for HTML export)")
                fi
                ;;
            csv)
                # No additional dependencies for CSV
                ;;
            markdown)
                # No additional dependencies for Markdown
                ;;
            *)
                echo -e "${RED}Error: Unsupported export format: $export_format${NC}"
                echo -e "Supported formats: html, csv, markdown"
                return 1
                ;;
        esac
    fi
    
    # Report missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Missing dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        return 1
    fi
    
    return 0
}

install_tool() {
    echo -e "${BLUE}Installing ${TOOL_NAME}...${NC}"
    
    # Check dependencies
    check_dependencies || return 1
    
    # Create directories if they don't exist
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$STATS_CACHE_DIR"
    
    # Copy this script to install directory
    cp "$0" "$INSTALL_DIR/$TOOL_NAME"
    chmod +x "$INSTALL_DIR/$TOOL_NAME"
    
    # Create cache of service names for faster suggestions
    update_service_cache
    
    # Create default bookmarks file if it doesn't exist
    if [[ ! -f "$BOOKMARK_FILE" ]]; then
        cat > "$BOOKMARK_FILE" << EOF
# sawlog bookmarks file
# Format: bookmark_name|service_type|service_name|options
# Example: ssh-errors|system|ssh.service|-p err,crit -f

# Some examples:
plasma-errors|user|plasma-plasmashell.service|-p err,warning -n 50
network-realtime|system|NetworkManager.service|-f -x
kernel-errors|kernel||--kernel -p err,crit,warning
EOF
        echo -e "${GREEN}Created default bookmarks file${NC}"
    fi
    
    # Create default theme file if it doesn't exist
    if [[ ! -f "$THEME_FILE" ]]; then
        cat > "$THEME_FILE" << EOF
# sawlog theme configuration
# You can customize colors and formatting

# Main colors
ERROR_COLOR='\033[1;31m'      # Bold Red
WARNING_COLOR='\033[1;33m'    # Bold Yellow
INFO_COLOR='\033[0;32m'       # Green
DEBUG_COLOR='\033[0;90m'      # Gray
TIMESTAMP_COLOR='\033[0;36m'  # Cyan
SERVICE_COLOR='\033[0;35m'    # Purple
HIGHLIGHT_COLOR='\033[1;43m'  # Yellow Background

# Enable/disable features
USE_PAGER=true                # Use less for output
COLORIZE_OUTPUT=true          # Use colors in output
HIGHLIGHT_ERRORS=true         # Highlight error lines
EOF
        echo -e "${GREEN}Created default theme configuration${NC}"
    fi
    
    # Create default monitor configuration
    if [[ ! -f "$MONITOR_CONFIG" ]]; then
        cat > "$MONITOR_CONFIG" << EOF
# sawlog monitor configuration
# This file configures which logs to monitor and thresholds for alerting

# Enable/disable monitoring
ENABLE_MONITORING=true

# Monitoring interval in seconds (default: 300 = 5 minutes)
MONITORING_INTERVAL=300

# Services to monitor (space-separated list)
# Format: "service_type:service_name"
# Examples: "system:sshd.service" "user:plasma-plasmashell.service" "kernel:"
MONITORED_SERVICES="system:systemd.service system:NetworkManager.service kernel:"

# Alert thresholds (number of events per monitoring interval)
CRITICAL_THRESHOLD=5          # Critical errors threshold
ERROR_THRESHOLD=20            # Errors threshold
WARNING_THRESHOLD=50          # Warnings threshold

# Health metrics monitoring
MONITOR_CPU_USAGE=true        # Monitor CPU usage
CPU_THRESHOLD=90              # Alert when CPU usage exceeds this percentage

MONITOR_MEMORY_USAGE=true     # Monitor memory usage
MEMORY_THRESHOLD=85           # Alert when memory usage exceeds this percentage

MONITOR_DISK_USAGE=true       # Monitor disk usage
DISK_THRESHOLD=90             # Alert when disk usage exceeds this percentage

MONITOR_FAILED_SERVICES=true  # Monitor failed systemd services

# Retention settings
STATS_RETENTION_DAYS=30       # How many days to keep statistics data
EOF
        echo -e "${GREEN}Created default monitor configuration${NC}"
    fi
    
    # Create default notification configuration
    if [[ ! -f "$NOTIFICATION_CONFIG" ]]; then
        cat > "$NOTIFICATION_CONFIG" << EOF
# sawlog notification configuration
# This file configures how notifications are delivered

# Enable/disable notifications
ENABLE_NOTIFICATIONS=true

# Notification methods
USE_DESKTOP_NOTIFICATIONS=true    # Use desktop notifications
USE_EMAIL_NOTIFICATIONS=false     # Send email notifications
USE_LOG_FILE=true                 # Log notifications to file

# Desktop notification settings
NOTIFICATION_TIMEOUT=10000        # Timeout in milliseconds (10 seconds)
NOTIFICATION_URGENCY_CRITICAL="critical"
NOTIFICATION_URGENCY_ERROR="normal"
NOTIFICATION_URGENCY_WARNING="low"

# Email notification settings
EMAIL_RECIPIENT=""
EMAIL_FROM="sawlog@$(hostname)"
EMAIL_SUBJECT_PREFIX="[SAWLOG]"
SMTP_SERVER=""
SMTP_PORT=25
SMTP_USER=""
SMTP_PASSWORD=""

# Log file settings
NOTIFICATION_LOG="${CONFIG_DIR}/notifications.log"

# Rate limiting to avoid notification storms
RATE_LIMIT_PERIOD=300             # Period in seconds (5 minutes)
MAX_NOTIFICATIONS_PER_PERIOD=5    # Maximum notifications per period
RATE_LIMIT_SIMILAR=true           # Rate limit similar notifications
SIMILAR_NOTIFICATION_TIMEOUT=1800 # 30 minutes between similar notifications

# Do not disturb settings
DO_NOT_DISTURB=false              # Enable/disable do not disturb mode
DND_START_TIME="23:00"            # Do not disturb start time
DND_END_TIME="07:00"              # Do not disturb end time
EOF
        echo -e "${GREEN}Created default notification configuration${NC}"
    fi
    
    # Install bash completion
    install_bash_completion
    
    # Install zsh completion if zsh is available
    if command -v zsh &> /dev/null; then
        install_zsh_completion
    fi
    
    # Create monitor script
    create_monitor_script
    
    # Check if install directory is in PATH
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH.${NC}"
        echo -e "${YELLOW}Add the following line to your .bashrc or .zshrc:${NC}"
        echo "export PATH=\"\$PATH:$INSTALL_DIR\""
    fi
    
    echo -e "${GREEN}${TOOL_NAME} has been installed successfully!${NC}"
    echo -e "Run '${CYAN}${TOOL_NAME} --help${NC}' for usage information."
    echo -e "To set up the monitoring service, run '${CYAN}${TOOL_NAME} --setup-monitor${NC}'."
}

install_bash_completion() {
    if [[ -d "/etc/bash_completion.d" && -w "/etc/bash_completion.d" ]]; then
        create_bash_completion_script > "$COMPLETION_FILE"
        echo -e "${GREEN}Bash completion installed to $COMPLETION_FILE${NC}"
    elif [[ -d "$HOME/.bash_completion.d" ]]; then
        mkdir -p "$HOME/.bash_completion.d"
        create_bash_completion_script > "$HOME/.bash_completion.d/sawlog_completion"
        
        # Check if .bash_completion sources the directory
        if [[ -f "$HOME/.bash_completion" ]] && ! grep -q ".bash_completion.d/" "$HOME/.bash_completion" 2>/dev/null; then
            echo 'for file in ~/.bash_completion.d/*; do source "$file"; done' >> "$HOME/.bash_completion"
        fi
        echo -e "${GREEN}Bash completion installed to ~/.bash_completion.d/sawlog_completion${NC}"
    else
        mkdir -p "$HOME/.bash_completion.d"
        create_bash_completion_script > "$HOME/.bash_completion.d/sawlog_completion"
        
        # Add to .bashrc if .bash_completion doesn't exist
        if ! grep -q ".bash_completion.d/sawlog_completion" "$HOME/.bashrc" 2>/dev/null; then
            echo 'if [ -f ~/.bash_completion.d/sawlog_completion ]; then source ~/.bash_completion.d/sawlog_completion; fi' >> "$HOME/.bashrc"
        fi
        echo -e "${GREEN}Bash completion installed to ~/.bash_completion.d/sawlog_completion${NC}"
        echo -e "${YELLOW}You may need to restart your shell or source ~/.bashrc for completion to work${NC}"
    fi
}

install_zsh_completion() {
    mkdir -p "${HOME}/.zsh/completions"
    create_zsh_completion_script > "$ZSH_COMPLETION_FILE"
    
    # Check if the completions directory is in fpath
    if ! grep -q ".zsh/completions" "$HOME/.zshrc" 2>/dev/null; then
        echo 'fpath=(~/.zsh/completions $fpath)' >> "$HOME/.zshrc"
        echo 'autoload -Uz compinit && compinit' >> "$HOME/.zshrc"
    fi
    
    echo -e "${GREEN}ZSH completion installed to $ZSH_COMPLETION_FILE${NC}"
    echo -e "${YELLOW}You may need to restart your shell or run 'autoload -Uz compinit && compinit' for completion to work${NC}"
}

create_monitor_script() {
    cat > "$MONITOR_SCRIPT" << 'EOF'
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
EOF
    chmod +x "$MONITOR_SCRIPT"
}

uninstall_tool() {
    echo -e "${BLUE}Uninstalling ${TOOL_NAME}...${NC}"
    
    # Remove the executable
    if [[ -f "$INSTALL_DIR/$TOOL_NAME" ]]; then
        rm "$INSTALL_DIR/$TOOL_NAME"
        echo -e "${GREEN}Removed $INSTALL_DIR/$TOOL_NAME${NC}"
    fi
    
    # Remove the monitor script
    if [[ -f "$MONITOR_SCRIPT" ]]; then
        rm "$MONITOR_SCRIPT"
        echo -e "${GREEN}Removed $MONITOR_SCRIPT${NC}"
    fi
    
    # Stop and disable the monitoring service if it exists
    if systemctl is-active --quiet sawlog-monitor.service 2>/dev/null; then
        sudo systemctl stop sawlog-monitor.service
        sudo systemctl disable sawlog-monitor.service
        echo -e "${GREEN}Stopped and disabled system monitoring service${NC}"
    fi
    
    if systemctl --user is-active --quiet sawlog-monitor.service 2>/dev/null; then
        systemctl --user stop sawlog-monitor.service
        systemctl --user disable sawlog-monitor.service
        echo -e "${GREEN}Stopped and disabled user monitoring service${NC}"
    fi
    
    # Remove service files
    if [[ -f "$SERVICE_FILE" ]]; then
        sudo rm "$SERVICE_FILE"
        echo -e "${GREEN}Removed system service file${NC}"
    fi
    
    if [[ -f "$USER_SERVICE_FILE" ]]; then
        rm "$USER_SERVICE_FILE"
        echo -e "${GREEN}Removed user service file${NC}"
    fi
    
    # Ask if the user wants to keep configuration
    read -p "Do you want to keep your configuration, bookmarks, and statistics? [Y/n] " keep_config
    keep_config=${keep_config:-y}
    
    if [[ "${keep_config,,}" != "y" && "${keep_config,,}" != "yes" ]]; then
        # Remove the configuration directory
        if [[ -d "$CONFIG_DIR" ]]; then
            rm -rf "$CONFIG_DIR"
            echo -e "${GREEN}Removed configuration directory $CONFIG_DIR${NC}"
        fi
    else
        echo -e "${GREEN}Keeping configuration in $CONFIG_DIR${NC}"
    fi
    
    # Remove bash completion
    if [[ -f "$COMPLETION_FILE" ]]; then
        rm "$COMPLETION_FILE"
        echo -e "${GREEN}Removed bash completion from $COMPLETION_FILE${NC}"
    fi
    
    if [[ -f "$HOME/.bash_completion.d/sawlog_completion" ]]; then
        rm "$HOME/.bash_completion.d/sawlog_completion"
        echo -e "${GREEN}Removed bash completion from ~/.bash_completion.d/sawlog_completion${NC}"
    fi
    
    # Remove zsh completion
    if [[ -f "$ZSH_COMPLETION_FILE" ]]; then
        rm "$ZSH_COMPLETION_FILE"
        echo -e "${GREEN}Removed zsh completion from $ZSH_COMPLETION_FILE${NC}"
    fi
    
    echo -e "${GREEN}${TOOL_NAME} has been uninstalled.${NC}"
}

create_bash_completion_script() {
    cat << EOF
# Bash completion for sawlog
_sawlog_completions() {
    local cur prev opts services priorities bookmark_names categories
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    
    # Options
    opts="-h --help -i --install -u --uninstall -v --version -n --lines -f --follow -p --priority -g --grep -H --highlight -o --output -s --system -U --user -m --multi -a --all -k --kernel -x --expand -t --time -T --until --today --yesterday -c --clipboard -F --file -j --json -E --export -r --reverse --bookmark --bookmarks --use --refresh --status -l --list --stats --system-stats --attention --top-issues --category --setup-monitor --disable-monitor --configure-notifications --health-report --trends"
    
    # Handle option arguments
    case \$prev in
        -n|--lines|--top-issues)
            COMPREPLY=( \$(compgen -W "10 20 50 100 200 500 1000" -- "\$cur") )
            return 0
            ;;
        -p|--priority)
            priorities="emerg alert crit err warning notice info debug"
            COMPREPLY=( \$(compgen -W "\$priorities" -- "\$cur") )
            return 0
            ;;
        -o|--output)
            COMPREPLY=( \$(compgen -W "short short-precise verbose json cat pretty" -- "\$cur") )
            return 0
            ;;
        -F|--file)
            COMPREPLY=( \$(compgen -f "\$cur") )
            return 0
            ;;
        -t|--time|-T|--until|--trends)
            COMPREPLY=( \$(compgen -W "today yesterday '1h ago' '12h ago' '1d ago' '1 week ago' '7' '14' '30'" -- "\$cur") )
            return 0
            ;;
        -E|--export)
            COMPREPLY=( \$(compgen -W "html csv markdown" -- "\$cur") )
            return 0
            ;;
        --category)
            categories="system security performance application network hardware"
            COMPREPLY=( \$(compgen -W "\$categories" -- "\$cur") )
            return 0
            ;;
        --use)
            # Get bookmark names from the bookmark file
            if [[ -f "$CONFIG_DIR/bookmarks.conf" ]]; then
                bookmark_names=\$(grep -v '^#' "$CONFIG_DIR/bookmarks.conf" | cut -d '|' -f 1)
                COMPREPLY=( \$(compgen -W "\$bookmark_names" -- "\$cur") )
            fi
            return 0
            ;;
    esac
    
    # If starting with dash, suggest options
    if [[ \$cur == -* ]]; then
        COMPREPLY=( \$(compgen -W "\$opts" -- "\$cur") )
        return 0
    fi
    
    # Otherwise, suggest services from cache
    if [[ -f "$CONFIG_DIR/services.cache" ]]; then
        services=\$(cat "$CONFIG_DIR/services.cache")
        COMPREPLY=( \$(compgen -W "\$services" -- "\$cur") )
    fi
    
    return 0
}

complete -F _sawlog_completions sawlog
EOF
}

create_zsh_completion_script() {
    cat << EOF
#compdef sawlog

_sawlog() {
    local -a options time_options lines_options priority_options output_options export_options bookmark_options category_options
    
    options=(
        '(-h --help)'{-h,--help}'[Show help message]'
        '(-i --install)'{-i,--install}'[Install the tool]'
        '(-u --uninstall)'{-u,--uninstall}'[Uninstall the tool]'
        '(-v --version)'{-v,--version}'[Show version information]'
        '(-n --lines)'{-n,--lines}'[Number of log lines to show]:lines:(10 20 50 100 200 500 1000)'
        '(-f --follow)'{-f,--follow}'[Follow logs in real-time]'
        '(-p --priority)'{-p,--priority}'[Filter by priority]:priority:(emerg alert crit err warning notice info debug)'
        '(-g --grep)'{-g,--grep}'[Filter logs by pattern]:pattern:'
        '(-H --highlight)'{-H,--highlight}'[Highlight pattern in logs]:pattern:'
        '(-o --output)'{-o,--output}'[Output format]:format:(short short-precise verbose json cat pretty)'
        '(-s --system)'{-s,--system}'[Force search in system services]'
        '(-U --user)'{-U,--user}'[Force search in user services]'
        '(-m --multi)'{-m,--multi}'[View logs from multiple services]:services:'
        '(-a --all)'{-a,--all}'[Show logs from all services]'
        '(-k --kernel)'{-k,--kernel}'[Show kernel messages only]'
        '(-x --expand)'{-x,--expand}'[Show full message text]'
        '(-t --time)'{-t,--time}'[Show entries since TIME]:time:(today yesterday "1h ago" "12h ago" "1d ago" "1 week ago")'
        '(-T --until)'{-T,--until}'[Show entries until TIME]:time:(today yesterday "1h ago" "12h ago" "1d ago" "1 week ago")'
        '--today[Show entries from today]'
        '--yesterday[Show entries from yesterday]'
        '(-c --clipboard)'{-c,--clipboard}'[Copy output to clipboard]'
        '(-F --file)'{-F,--file}'[Save output to file]:filename:_files'
        '(-j --json)'{-j,--json}'[Output logs in JSON format]'
        '(-E --export)'{-E,--export}'[Export as format]:format:(html csv markdown)'
        '(-r --reverse)'{-r,--reverse}'[Show logs in reverse order]'
        '--bookmark[Add current service/query to bookmarks]:name:'
        '--bookmarks[List saved bookmarks]'
        '--use[Use a saved bookmark]:bookmark:->bookmarks'
        '--refresh[Refresh service cache]'
        '--status[Show service status alongside logs]'
        '(-l --list)'{-l,--list}'[List all available services]'
        '--stats[Show log statistics]'
        '--system-stats[Show system-wide process statistics]'
        '--attention[Show areas that need attention]'
        '--top-issues[Show top N services with issues]:count:(5 10 20 50)'
        '--category[Filter by category]:category:(system security performance application network hardware)'
        '--setup-monitor[Setup the log monitoring service]'
        '--disable-monitor[Disable the log monitoring service]'
        '--configure-notifications[Configure notification preferences]'
        '--health-report[Generate a system health report]'
        '--trends[Show trends over time]:days:(7 14 30)'
    )
    
    case \$state in
        bookmarks)
            if [[ -f "$CONFIG_DIR/bookmarks.conf" ]]; then
                local -a bookmarks
                bookmarks=(\$(grep -v '^#' "$CONFIG_DIR/bookmarks.conf" | cut -d '|' -f 1))
                _describe 'bookmarks' bookmarks
            fi
            ;;
    esac
    
    if [[ -f "$CONFIG_DIR/services.cache" ]]; then
        local -a services
        services=(\$(cat "$CONFIG_DIR/services.cache"))
        _describe 'services' services
    fi
    
    _arguments -s \$options
}

_sawlog
EOF
}

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

copy_to_clipboard() {
    case "$CLIPBOARD_TOOL" in
        "xclip")
            xclip -selection clipboard
            ;;
        "wl-copy")
            wl-copy
            ;;
        "pbcopy")
            pbcopy
            ;;
        *)
            echo -e "${RED}No clipboard tool available.${NC}"
            return 1
            ;;
    esac
    return 0
}

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

format_log_output() {
    local input="$1"
    local format="$2"
    local highlight_pattern="$3"
    local priority_filter="$4"
    
    # Load theme settings
    if [[ -f "$THEME_FILE" ]]; then
        source "$THEME_FILE"
    fi
    
    # If no format specified, default to regular journalctl output
    if [[ -z "$format" ]]; then
        if [[ -n "$highlight_pattern" ]]; then
            # Apply highlighting if pattern is provided
            echo "$input" | GREP_COLOR="1;33" grep --color=always -E "$highlight_pattern|$"
        else
            echo "$input"
        fi
        return
    fi
    
    case "$format" in
        "pretty")
            # Enhanced output with colorization based on priority
            echo "$input" | awk -v error_color="$ERROR_COLOR" -v warning_color="$WARNING_COLOR" \
                -v info_color="$INFO_COLOR" -v debug_color="$DEBUG_COLOR" -v reset="$NC" \
                -v timestamp_color="$TIMESTAMP_COLOR" -v service_color="$SERVICE_COLOR" \
                -v highlight="$HIGHLIGHT_COLOR" -v highlight_pattern="$highlight_pattern" \
                '
                function highlight_match(line, pattern) {
                    if (pattern == "") return line;
                    return gensub(pattern, highlight "&" reset, "g", line);
                }
                
                {
                    # Extract the priority if available
                    priority = "";
                    if ($0 ~ /<[0-9]>/) {
                        priority = substr($0, index($0, "<"), 3);
                    }
                    
                    # Color based on priority or content
                    color = info_color;
                    if (priority == "<0>" || priority == "<1>" || priority == "<2>" || priority == "<3>" || 
                        $0 ~ /error|fail/i) {
                        color = error_color;
                    } else if (priority == "<4>" || $0 ~ /warn/i) {
                        color = warning_color;
                    } else if (priority == "<7>" || $0 ~ /debug/i) {
                        color = debug_color;
                    }
                    
                    # Format timestamp and service name if available
                    timestamp = "";
                    service = "";
                    message = $0;
                    
                    # Try to extract timestamp
                    if ($0 ~ /^[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/) {
                        timestamp = substr($0, 1, 15);
                        message = substr($0, 16);
                    }
                    
                    # Try to extract service name
                    if (message ~ /[a-zA-Z0-9._-]+\[[0-9]+\]:/) {
                        service_start = match(message, /[a-zA-Z0-9._-]+\[[0-9]+\]:/);
                        service_end = RLENGTH;
                        service = substr(message, service_start, service_end);
                        message = substr(message, service_start + service_end);
                    }
                    
                    # Format the output
                    output = "";
                    if (timestamp != "") {
                        output = timestamp_color timestamp reset " ";
                    }
                    if (service != "") {
                        output = output service_color service reset " ";
                    }
                    output = output color message reset;
                    
                    # Apply highlighting if pattern is provided
                    if (highlight_pattern != "") {
                        output = highlight_match(output, highlight_pattern);
                    }
                    
                    print output;
                }
                '
            ;;
        *)
            # For other formats, pass through
            if [[ -n "$highlight_pattern" ]]; then
                echo "$input" | GREP_COLOR="1;33" grep --color=always -E "$highlight_pattern|$"
            else
                echo "$input"
            fi
            ;;
    esac
}

export_logs() {
    local logs="$1"
    local format="$2"
    local output_file="$3"
    
    case "$format" in
        "html")
            if command -v pandoc &> /dev/null; then
                echo "$logs" | pandoc -f markdown -t html -o "$output_file" --metadata title="Log Export"
                echo -e "${GREEN}Logs exported to HTML file: $output_file${NC}"
            else
                echo -e "${RED}Error: pandoc is required for HTML export${NC}"
                return 1
            fi
            ;;
        "csv")
            # Simple CSV conversion - timestamp, service, message
            echo "timestamp,service,message" > "$output_file"
            echo "$logs" | awk '
                {
                    timestamp = "";
                    service = "";
                    message = $0;
                    
                    # Try to extract timestamp
                    if ($0 ~ /^[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/) {
                        timestamp = substr($0, 1, 15);
                        message = substr($0, 16);
                    }
                    
                    # Try to extract service name
                    if (message ~ /[a-zA-Z0-9._-]+\[[0-9]+\]:/) {
                        service_start = match(message, /[a-zA-Z0-9._-]+\[[0-9]+\]:/);
                        service_end = RLENGTH;
                        service = substr(message, service_start, service_end);
                        service = substr(service, 1, length(service)-1);  # Remove the colon
                        message = substr(message, service_start + service_end);
                    }
                    
                    # Escape quotes in message
                    gsub(/"/, "\"\"", message);
                    
                    print "\"" timestamp "\",\"" service "\",\"" message "\""
                }
            ' >> "$output_file"
            echo -e "${GREEN}Logs exported to CSV file: $output_file${NC}"
            ;;
        "markdown")
            # Create a markdown document
            cat > "$output_file" << EOF
# Log Export
Generated on $(date)

\`\`\`
$logs
\`\`\`
EOF
            echo -e "${GREEN}Logs exported to Markdown file: $output_file${NC}"
            ;;
        *)
            echo -e "${RED}Error: Unsupported export format: $format${NC}"
            echo -e "Supported formats: html, csv, markdown"
            return 1
            ;;
    esac
}

# Enhanced show_log_stats function with more detailed analysis
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
        eval "$base_cmd --priority=emerg,alert,crit,err --no-pager | grep -v '^--' | sed 's/^[A-Za-z]\{3\} [0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} [^ ]* //' | sort | uniq -c | sort -nr | head -n 5" | 
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
    local system_errors=$(journalctl --priority=emerg,alert,crit,err --since="1 hour ago" | wc -l)
    local system_warnings=$(journalctl --priority=warning --since="1 hour ago" | wc -l)
    
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
                count=$(journalctl -u systemd -u udev -u dbus -u polkit --priority=emerg,alert,crit,err --since="24 hours ago" | wc -l)
                ;;
            "network")
                # Network services
                count=$(journalctl -u NetworkManager -u systemd-networkd -u ssh -u networking --priority=emerg,alert,crit,err --since="24 hours ago" | wc -l)
                ;;
            "kernel")
                # Kernel messages
                count=$(journalctl --dmesg --priority=emerg,alert,crit,err --since="24 hours ago" | wc -l)
                ;;
            "security")
                # Security-related logs
                count=$(journalctl -u apparmor -u audit -u sshd -u sudo --priority=emerg,alert,crit,err --since="24 hours ago" | wc -l)
                ;;
            "hardware")
                # Hardware-related logs
                count=$(journalctl | grep -i -E "hardware|device|disk|cpu|memory|thermal|temperature|fan|power|battery" | grep -i -E "error|fail|critical" --since="24 hours ago" | wc -l)
                ;;
            "application")
                # Application logs
                count=$(journalctl -u apache2 -u nginx -u mysql -u docker -u snap -u flatpak --priority=emerg,alert,crit,err --since="24 hours ago" | wc -l)
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
    local error_prone_services=$(journalctl --priority=emerg,alert,crit,err --since="$time_filter" --output=json | 
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
                print "application:" severity ":" $2 " errors|" $1 "|journalctl _COMM=" $2 " --priority=emerg,alert,crit,err"
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
    local base_cmd="journalctl --priority=emerg,alert,crit,err --since=\"$time_filter\" --output=json"
    
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
            echo -e "    • Journald: ${GRAY}journalctl _COMM=\"$service\" --priority=err${NC}"
            
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
        local critical=$(journalctl --since="$date 00:00:00" --until="$date 23:59:59" --priority=emerg,alert,crit | wc -l)
        local error=$(journalctl --since="$date 00:00:00" --until="$date 23:59:59" --priority=err | wc -l)
        local warning=$(journalctl --since="$date 00:00:00" --until="$date 23:59:59" --priority=warning | wc -l)
        local info=$(journalctl --since="$date 00:00:00" --until="$date 23:59:59" --priority=info | wc -l)
        
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
    
    journalctl --priority=emerg,alert,crit,err --since="$days days ago" --output=json | 
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
    journalctl --priority=emerg,alert,crit,err --since="24 hours ago" --output=json | 
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
    if [[ $(journalctl --priority=emerg,alert,crit,err --since="24 hours ago" | wc -l) -gt 50 ]]; then
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
    echo "Generated with sawlog version 2.0"
    echo "Run '$TOOL_NAME --setup-monitor' to enable continuous monitoring"
    echo "============================================="
    
    # Restore output
    exec >&- 2>&-
    exec > /dev/tty 2>&1
    
    echo -e "${GREEN}Health report generated successfully at:${NC}"
    echo -e "${CYAN}$output_file${NC}"
    echo
}

# Function to setup the monitoring service
setup_monitoring_service() {
    echo -e "${BOLD}${BLUE}Setting up Sawlog Monitoring Service:${NC}"
    echo
    
    # Make sure monitor script exists
    if [[ ! -f "$MONITOR_SCRIPT" ]]; then
        echo -e "${RED}Monitor script not found. Please reinstall sawlog.${NC}"
        return 1
    fi
    
    # Create the monitor configuration if it doesn't exist
    if [[ ! -f "$MONITOR_CONFIG" ]]; then
        echo -e "${CYAN}Creating default monitor configuration...${NC}"
        mkdir -p "$CONFIG_DIR"
        cat > "$MONITOR_CONFIG" << EOF
# sawlog monitor configuration
# This file configures which logs to monitor and thresholds for alerting

# Enable/disable monitoring
ENABLE_MONITORING=true

# Monitoring interval in seconds (default: 300 = 5 minutes)
MONITORING_INTERVAL=300

# Services to monitor (space-separated list)
# Format: "service_type:service_name"
# Examples: "system:sshd.service" "user:plasma-plasmashell.service" "kernel:"
MONITORED_SERVICES="system:systemd.service system:NetworkManager.service kernel:"

# Alert thresholds (number of events per monitoring interval)
CRITICAL_THRESHOLD=5          # Critical errors threshold
ERROR_THRESHOLD=20            # Errors threshold
WARNING_THRESHOLD=50          # Warnings threshold

# Health metrics monitoring
MONITOR_CPU_USAGE=true        # Monitor CPU usage
CPU_THRESHOLD=90              # Alert when CPU usage exceeds this percentage

MONITOR_MEMORY_USAGE=true     # Monitor memory usage
MEMORY_THRESHOLD=85           # Alert when memory usage exceeds this percentage

MONITOR_DISK_USAGE=true       # Monitor disk usage
DISK_THRESHOLD=90             # Alert when disk usage exceeds this percentage

MONITOR_FAILED_SERVICES=true  # Monitor failed systemd services

# Retention settings
STATS_RETENTION_DAYS=30       # How many days to keep statistics data
EOF
    fi
    
    # Create the notification configuration if it doesn't exist
    if [[ ! -f "$NOTIFICATION_CONFIG" ]]; then
        echo -e "${CYAN}Creating default notification configuration...${NC}"
        mkdir -p "$CONFIG_DIR"
        cat > "$NOTIFICATION_CONFIG" << EOF
# sawlog notification configuration
# This file configures how notifications are delivered

# Enable/disable notifications
ENABLE_NOTIFICATIONS=true

# Notification methods
USE_DESKTOP_NOTIFICATIONS=true    # Use desktop notifications
USE_EMAIL_NOTIFICATIONS=false     # Send email notifications
USE_LOG_FILE=true                 # Log notifications to file

# Desktop notification settings
NOTIFICATION_TIMEOUT=10000        # Timeout in milliseconds (10 seconds)
NOTIFICATION_URGENCY_CRITICAL="critical"
NOTIFICATION_URGENCY_ERROR="normal"
NOTIFICATION_URGENCY_WARNING="low"

# Email notification settings
EMAIL_RECIPIENT=""
EMAIL_FROM="sawlog@$(hostname)"
EMAIL_SUBJECT_PREFIX="[SAWLOG]"
SMTP_SERVER=""
SMTP_PORT=25
SMTP_USER=""
SMTP_PASSWORD=""

# Log file settings
NOTIFICATION_LOG="${CONFIG_DIR}/notifications.log"

# Rate limiting to avoid notification storms
RATE_LIMIT_PERIOD=300             # Period in seconds (5 minutes)
MAX_NOTIFICATIONS_PER_PERIOD=5    # Maximum notifications per period
RATE_LIMIT_SIMILAR=true           # Rate limit similar notifications
SIMILAR_NOTIFICATION_TIMEOUT=1800 # 30 minutes between similar notifications

# Do not disturb settings
DO_NOT_DISTURB=false              # Enable/disable do not disturb mode
DND_START_TIME="23:00"            # Do not disturb start time
DND_END_TIME="07:00"              # Do not disturb end time
EOF
    fi
    
    # Ask if user wants to install as system service or user service
    echo -e "${CYAN}How would you like to install the monitoring service?${NC}"
    echo "  1) System service (requires sudo, runs at boot time, more comprehensive monitoring)"
    echo "  2) User service (runs when you log in, limited to user context)"
    read -p "Select an option [1-2]: " service_option
    
    case "$service_option" in
        1)
            # Create systemd system service
            echo -e "${CYAN}Creating system service...${NC}"
            cat > /tmp/sawlog-monitor.service << EOF
[Unit]
Description=Sawlog Log Monitoring Service
After=network.target

[Service]
Type=simple
ExecStart=${MONITOR_SCRIPT}
Restart=on-failure
RestartSec=10
User=$(whoami)
Group=$(id -gn)

[Install]
WantedBy=multi-user.target
EOF
            
            # Install the service with sudo
            sudo mv /tmp/sawlog-monitor.service "$SERVICE_FILE"
            sudo systemctl daemon-reload
            sudo systemctl enable sawlog-monitor.service
            sudo systemctl start sawlog-monitor.service
            
            echo -e "${GREEN}System monitoring service installed and started.${NC}"
            echo -e "Check status with: ${CYAN}sudo systemctl status sawlog-monitor.service${NC}"
            ;;
        2)
            # Create systemd user service
            echo -e "${CYAN}Creating user service...${NC}"
            mkdir -p "$(dirname "$USER_SERVICE_FILE")"
            cat > "$USER_SERVICE_FILE" << EOF
[Unit]
Description=Sawlog Log Monitoring Service (User)
After=default.target

[Service]
Type=simple
ExecStart=${MONITOR_SCRIPT}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
            
            # Enable and start the user service
            systemctl --user daemon-reload
            systemctl --user enable sawlog-monitor.service
            systemctl --user start sawlog-monitor.service
            
            echo -e "${GREEN}User monitoring service installed and started.${NC}"
            echo -e "Check status with: ${CYAN}systemctl --user status sawlog-monitor.service${NC}"
            ;;
        *)
            echo -e "${RED}Invalid option. Monitoring service not installed.${NC}"
            return 1
            ;;
    esac
    
    echo -e "\n${GREEN}Monitoring service setup complete!${NC}"
    echo -e "Configuration files:"
    echo -e "  • Monitor config: ${CYAN}$MONITOR_CONFIG${NC}"
    echo -e "  • Notification config: ${CYAN}$NOTIFICATION_CONFIG${NC}"
    echo
    echo -e "You can edit these files to customize monitoring behavior."
    echo -e "To disable the service, run: ${CYAN}$TOOL_NAME --disable-monitor${NC}"
}

# Function to disable the monitoring service
disable_monitoring_service() {
    echo -e "${BOLD}${BLUE}Disabling Sawlog Monitoring Service:${NC}"
    echo
    
    local system_running=false
    local user_running=false
    
    # Check if system service is running
    if systemctl is-active --quiet sawlog-monitor.service 2>/dev/null; then
        system_running=true
    fi
    
    # Check if user service is running
    if systemctl --user is-active --quiet sawlog-monitor.service 2>/dev/null; then
        user_running=true
    fi
    
    if [[ "$system_running" == "false" && "$user_running" == "false" ]]; then
        echo -e "${YELLOW}No monitoring service is currently running.${NC}"
        return 0
    fi
    
    if [[ "$system_running" == "true" ]]; then
        echo -e "${CYAN}Stopping and disabling system monitoring service...${NC}"
        sudo systemctl stop sawlog-monitor.service
        sudo systemctl disable sawlog-monitor.service
        echo -e "${GREEN}System monitoring service disabled.${NC}"
    fi
    
    if [[ "$user_running" == "true" ]]; then
        echo -e "${CYAN}Stopping and disabling user monitoring service...${NC}"
        systemctl --user stop sawlog-monitor.service
        systemctl --user disable sawlog-monitor.service
        echo -e "${GREEN}User monitoring service disabled.${NC}"
    fi
    
    # Ask if user wants to remove service files
    read -p "Do you want to remove the service files as well? [y/N] " remove_files
    if [[ "${remove_files,,}" == "y" || "${remove_files,,}" == "yes" ]]; then
        if [[ "$system_running" == "true" && -f "$SERVICE_FILE" ]]; then
            sudo rm -f "$SERVICE_FILE"
            sudo systemctl daemon-reload
            echo -e "${GREEN}Removed system service file.${NC}"
        fi
        
        if [[ "$user_running" == "true" && -f "$USER_SERVICE_FILE" ]]; then
            rm -f "$USER_SERVICE_FILE"
            systemctl --user daemon-reload
            echo -e "${GREEN}Removed user service file.${NC}"
        fi
    fi
    
    echo -e "\n${GREEN}Monitoring service has been disabled.${NC}"
    echo -e "To re-enable it in the future, run: ${CYAN}$TOOL_NAME --setup-monitor${NC}"
}

# Function to configure notification preferences
configure_notifications() {
    echo -e "${BOLD}${BLUE}Configure Monitoring Notifications:${NC}"
    echo
    
    # Create default notification config if it doesn't exist
    if [[ ! -f "$NOTIFICATION_CONFIG" ]]; then
        mkdir -p "$CONFIG_DIR"
        cat > "$NOTIFICATION_CONFIG" << EOF
# sawlog notification configuration
# This file configures how notifications are delivered

# Enable/disable notifications
ENABLE_NOTIFICATIONS=true

# Notification methods
USE_DESKTOP_NOTIFICATIONS=true    # Use desktop notifications
USE_EMAIL_NOTIFICATIONS=false     # Send email notifications
USE_LOG_FILE=true                 # Log notifications to file

# Desktop notification settings
NOTIFICATION_TIMEOUT=10000        # Timeout in milliseconds (10 seconds)
NOTIFICATION_URGENCY_CRITICAL="critical"
NOTIFICATION_URGENCY_ERROR="normal"
NOTIFICATION_URGENCY_WARNING="low"

# Email notification settings
EMAIL_RECIPIENT=""
EMAIL_FROM="sawlog@$(hostname)"
EMAIL_SUBJECT_PREFIX="[SAWLOG]"
SMTP_SERVER=""
SMTP_PORT=25
SMTP_USER=""
SMTP_PASSWORD=""

# Log file settings
NOTIFICATION_LOG="${CONFIG_DIR}/notifications.log"

# Rate limiting to avoid notification storms
RATE_LIMIT_PERIOD=300             # Period in seconds (5 minutes)
MAX_NOTIFICATIONS_PER_PERIOD=5    # Maximum notifications per period
RATE_LIMIT_SIMILAR=true           # Rate limit similar notifications
SIMILAR_NOTIFICATION_TIMEOUT=1800 # 30 minutes between similar notifications

# Do not disturb settings
DO_NOT_DISTURB=false              # Enable/disable do not disturb mode
DND_START_TIME="23:00"            # Do not disturb start time
DND_END_TIME="07:00"              # Do not disturb end time
EOF
    fi
    
    # Source the current configuration
    source "$NOTIFICATION_CONFIG"
    
    # Interactive configuration menu
    while true; do
        echo -e "\n${CYAN}Notification Configuration Menu:${NC}"
        echo "  1) Enable/disable notifications"
        echo "  2) Configure notification methods"
        echo "  3) Configure desktop notifications"
        echo "  4) Configure email notifications"
        echo "  5) Configure notification rate limiting"
        echo "  6) Configure do not disturb settings"
        echo "  7) Test notifications"
        echo "  8) Save and exit"
        echo "  9) Exit without saving"
        echo
        
        read -p "Select an option [1-9]: " config_option
        
        case "$config_option" in
            1)
                # Toggle notifications
                echo
                echo -e "Current setting: Notifications are ${BOLD}$(if [[ "$ENABLE_NOTIFICATIONS" == "true" ]]; then echo -e "${GREEN}enabled${NC}"; else echo -e "${RED}disabled${NC}"; fi)${NC}"
                read -p "Enable notifications? [Y/n]: " toggle_notifications
                
                if [[ "${toggle_notifications,,}" == "n" || "${toggle_notifications,,}" == "no" ]]; then
                    ENABLE_NOTIFICATIONS="false"
                    echo -e "${YELLOW}Notifications disabled.${NC}"
                else
                    ENABLE_NOTIFICATIONS="true"
                    echo -e "${GREEN}Notifications enabled.${NC}"
                fi
                ;;
            2)
                # Configure notification methods
                echo
                echo "Configure notification methods:"
                
                read -p "Enable desktop notifications? [Y/n]: " desktop_notifications
                if [[ "${desktop_notifications,,}" == "n" || "${desktop_notifications,,}" == "no" ]]; then
                    USE_DESKTOP_NOTIFICATIONS="false"
                    echo -e "${YELLOW}Desktop notifications disabled.${NC}"
                else
                    USE_DESKTOP_NOTIFICATIONS="true"
                    echo -e "${GREEN}Desktop notifications enabled.${NC}"
                fi
                
                read -p "Enable email notifications? [y/N]: " email_notifications
                if [[ "${email_notifications,,}" == "y" || "${email_notifications,,}" == "yes" ]]; then
                    USE_EMAIL_NOTIFICATIONS="true"
                    echo -e "${GREEN}Email notifications enabled.${NC}"
                else
                    USE_EMAIL_NOTIFICATIONS="false"
                    echo -e "${YELLOW}Email notifications disabled.${NC}"
                fi
                
                read -p "Log notifications to file? [Y/n]: " log_notifications
                if [[ "${log_notifications,,}" == "n" || "${log_notifications,,}" == "no" ]]; then
                    USE_LOG_FILE="false"
                    echo -e "${YELLOW}Notification logging disabled.${NC}"
                else
                    USE_LOG_FILE="true"
                    echo -e "${GREEN}Notification logging enabled.${NC}"
                    
                    # Configure log file location
                    read -p "Notification log file [$NOTIFICATION_LOG]: " new_log_file
                    if [[ -n "$new_log_file" ]]; then
                        NOTIFICATION_LOG="$new_log_file"
                        echo -e "${CYAN}Notification log set to: $NOTIFICATION_LOG${NC}"
                    fi
                fi
                ;;
            3)
                # Configure desktop notifications
                echo
                echo "Configure desktop notification settings:"
                
                read -p "Notification timeout in milliseconds [$NOTIFICATION_TIMEOUT]: " new_timeout
                if [[ -n "$new_timeout" && "$new_timeout" =~ ^[0-9]+$ ]]; then
                    NOTIFICATION_TIMEOUT="$new_timeout"
                    echo -e "${CYAN}Notification timeout set to: $NOTIFICATION_TIMEOUT ms${NC}"
                fi
                
                echo "Notification urgency levels:"
                echo "  Available options: low, normal, critical"
                
                read -p "Critical notifications urgency [$NOTIFICATION_URGENCY_CRITICAL]: " crit_urgency
                if [[ -n "$crit_urgency" ]]; then
                    NOTIFICATION_URGENCY_CRITICAL="$crit_urgency"
                    echo -e "${CYAN}Critical urgency set to: $NOTIFICATION_URGENCY_CRITICAL${NC}"
                fi
                
                read -p "Error notifications urgency [$NOTIFICATION_URGENCY_ERROR]: " err_urgency
                if [[ -n "$err_urgency" ]]; then
                    NOTIFICATION_URGENCY_ERROR="$err_urgency"
                    echo -e "${CYAN}Error urgency set to: $NOTIFICATION_URGENCY_ERROR${NC}"
                fi
                
                read -p "Warning notifications urgency [$NOTIFICATION_URGENCY_WARNING]: " warn_urgency
                if [[ -n "$warn_urgency" ]]; then
                    NOTIFICATION_URGENCY_WARNING="$warn_urgency"
                    echo -e "${CYAN}Warning urgency set to: $NOTIFICATION_URGENCY_WARNING${NC}"
                fi
                ;;
            4)
                # Configure email notifications
                if [[ "$USE_EMAIL_NOTIFICATIONS" != "true" ]]; then
                    echo -e "${YELLOW}Email notifications are disabled. Enable them first.${NC}"
                    continue
                fi
                
                echo
                echo "Configure email notification settings:"
                
                read -p "Email recipient [$EMAIL_RECIPIENT]: " new_recipient
                if [[ -n "$new_recipient" ]]; then
                    EMAIL_RECIPIENT="$new_recipient"
                    echo -e "${CYAN}Email recipient set to: $EMAIL_RECIPIENT${NC}"
                fi
                
                read -p "Email sender [$EMAIL_FROM]: " new_sender
                if [[ -n "$new_sender" ]]; then
                    EMAIL_FROM="$new_sender"
                    echo -e "${CYAN}Email sender set to: $EMAIL_FROM${NC}"
                fi
                
                read -p "Email subject prefix [$EMAIL_SUBJECT_PREFIX]: " new_prefix
                if [[ -n "$new_prefix" ]]; then
                    EMAIL_SUBJECT_PREFIX="$new_prefix"
                    echo -e "${CYAN}Email subject prefix set to: $EMAIL_SUBJECT_PREFIX${NC}"
                fi
                
                read -p "SMTP server [$SMTP_SERVER]: " new_server
                if [[ -n "$new_server" ]]; then
                    SMTP_SERVER="$new_server"
                    echo -e "${CYAN}SMTP server set to: $SMTP_SERVER${NC}"
                fi
                
                read -p "SMTP port [$SMTP_PORT]: " new_port
                if [[ -n "$new_port" && "$new_port" =~ ^[0-9]+$ ]]; then
                    SMTP_PORT="$new_port"
                    echo -e "${CYAN}SMTP port set to: $SMTP_PORT${NC}"
                fi
                
                read -p "SMTP username [$SMTP_USER]: " new_user
                if [[ -n "$new_user" ]]; then
                    SMTP_USER="$new_user"
                    echo -e "${CYAN}SMTP username set.${NC}"
                fi
                
                read -s -p "SMTP password (hidden): " new_password
                echo
                if [[ -n "$new_password" ]]; then
                    SMTP_PASSWORD="$new_password"
                    echo -e "${CYAN}SMTP password set.${NC}"
                fi
                ;;
            5)
                # Configure rate limiting
                echo
                echo "Configure notification rate limiting:"
                
                read -p "Rate limit period in seconds [$RATE_LIMIT_PERIOD]: " new_period
                if [[ -n "$new_period" && "$new_period" =~ ^[0-9]+$ ]]; then
                    RATE_LIMIT_PERIOD="$new_period"
                    echo -e "${CYAN}Rate limit period set to: $RATE_LIMIT_PERIOD seconds${NC}"
                fi
                
                read -p "Maximum notifications per period [$MAX_NOTIFICATIONS_PER_PERIOD]: " new_max
                if [[ -n "$new_max" && "$new_max" =~ ^[0-9]+$ ]]; then
                    MAX_NOTIFICATIONS_PER_PERIOD="$new_max"
                    echo -e "${CYAN}Max notifications set to: $MAX_NOTIFICATIONS_PER_PERIOD per period${NC}"
                fi
                
                read -p "Rate limit similar notifications? [Y/n]: " rate_similar
                if [[ "${rate_similar,,}" == "n" || "${rate_similar,,}" == "no" ]]; then
                    RATE_LIMIT_SIMILAR="false"
                    echo -e "${YELLOW}Similar notification rate limiting disabled.${NC}"
                else
                    RATE_LIMIT_SIMILAR="true"
                    echo -e "${GREEN}Similar notification rate limiting enabled.${NC}"
                    
                    read -p "Similar notification timeout in seconds [$SIMILAR_NOTIFICATION_TIMEOUT]: " new_similar_timeout
                    if [[ -n "$new_similar_timeout" && "$new_similar_timeout" =~ ^[0-9]+$ ]]; then
                        SIMILAR_NOTIFICATION_TIMEOUT="$new_similar_timeout"
                        echo -e "${CYAN}Similar notification timeout set to: $SIMILAR_NOTIFICATION_TIMEOUT seconds${NC}"
                    fi
                fi
                ;;
            6)
                # Configure do not disturb settings
                echo
                echo "Configure do not disturb settings:"
                
                read -p "Enable do not disturb mode? [y/N]: " enable_dnd
                if [[ "${enable_dnd,,}" == "y" || "${enable_dnd,,}" == "yes" ]]; then
                    DO_NOT_DISTURB="true"
                    echo -e "${GREEN}Do not disturb mode enabled.${NC}"
                    
                    read -p "Do not disturb start time (24h format, e.g. 23:00) [$DND_START_TIME]: " new_start
                    if [[ -n "$new_start" && "$new_start" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
                        DND_START_TIME="$new_start"
                        echo -e "${CYAN}DND start time set to: $DND_START_TIME${NC}"
                    fi
                    
                    read -p "Do not disturb end time (24h format, e.g. 07:00) [$DND_END_TIME]: " new_end
                    if [[ -n "$new_end" && "$new_end" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
                        DND_END_TIME="$new_end"
                        echo -e "${CYAN}DND end time set to: $DND_END_TIME${NC}"
                    fi
                else
                    DO_NOT_DISTURB="false"
                    echo -e "${YELLOW}Do not disturb mode disabled.${NC}"
                fi
                ;;
            7)
                # Test notifications
                echo
                echo -e "${CYAN}Sending test notifications...${NC}"
                
                if [[ "$ENABLE_NOTIFICATIONS" != "true" ]]; then
                    echo -e "${YELLOW}Notifications are disabled. Enable them first.${NC}"
                    continue
                fi
                
                # Test desktop notification
                if [[ "$USE_DESKTOP_NOTIFICATIONS" == "true" ]]; then
                    echo -e "Sending desktop notification..."
                    if command -v notify-send &> /dev/null; then
                        notify-send --app-name="Sawlog Monitor" \
                                   --urgency="normal" \
                                   --expire-time="5000" \
                                   --category="system.test" \
                                   "Test Notification" "This is a test notification from Sawlog"
                        echo -e "${GREEN}Desktop notification sent.${NC}"
                    else
                        echo -e "${RED}Desktop notification failed. notify-send not found.${NC}"
                    fi
                fi
                
                # Test log file
                if [[ "$USE_LOG_FILE" == "true" ]]; then
                    echo "$(date): [TEST] Test notification message" >> "$NOTIFICATION_LOG"
                    echo -e "${GREEN}Log entry added to $NOTIFICATION_LOG${NC}"
                fi
                
                # Test email notification
                if [[ "$USE_EMAIL_NOTIFICATIONS" == "true" && -n "$EMAIL_RECIPIENT" && -n "$SMTP_SERVER" ]]; then
                    echo -e "${YELLOW}Email notification test: This would send an email to $EMAIL_RECIPIENT${NC}"
                    echo -e "${YELLOW}(Actual sending not implemented in this test)${NC}"
                fi
                ;;
            8)
                # Save and exit
                echo
                echo -e "${CYAN}Saving notification configuration...${NC}"
                
                # Write the updated configuration file
                cat > "$NOTIFICATION_CONFIG" << EOF
# sawlog notification configuration
# This file configures how notifications are delivered

# Enable/disable notifications
ENABLE_NOTIFICATIONS=$ENABLE_NOTIFICATIONS

# Notification methods
USE_DESKTOP_NOTIFICATIONS=$USE_DESKTOP_NOTIFICATIONS
USE_EMAIL_NOTIFICATIONS=$USE_EMAIL_NOTIFICATIONS
USE_LOG_FILE=$USE_LOG_FILE

# Desktop notification settings
NOTIFICATION_TIMEOUT=$NOTIFICATION_TIMEOUT
NOTIFICATION_URGENCY_CRITICAL="$NOTIFICATION_URGENCY_CRITICAL"
NOTIFICATION_URGENCY_ERROR="$NOTIFICATION_URGENCY_ERROR"
NOTIFICATION_URGENCY_WARNING="$NOTIFICATION_URGENCY_WARNING"

# Email notification settings
EMAIL_RECIPIENT="$EMAIL_RECIPIENT"
EMAIL_FROM="$EMAIL_FROM"
EMAIL_SUBJECT_PREFIX="$EMAIL_SUBJECT_PREFIX"
SMTP_SERVER="$SMTP_SERVER"
SMTP_PORT=$SMTP_PORT
SMTP_USER="$SMTP_USER"
SMTP_PASSWORD="$SMTP_PASSWORD"

# Log file settings
NOTIFICATION_LOG="$NOTIFICATION_LOG"

# Rate limiting to avoid notification storms
RATE_LIMIT_PERIOD=$RATE_LIMIT_PERIOD
MAX_NOTIFICATIONS_PER_PERIOD=$MAX_NOTIFICATIONS_PER_PERIOD
RATE_LIMIT_SIMILAR=$RATE_LIMIT_SIMILAR
SIMILAR_NOTIFICATION_TIMEOUT=$SIMILAR_NOTIFICATION_TIMEOUT

# Do not disturb settings
DO_NOT_DISTURB=$DO_NOT_DISTURB
DND_START_TIME="$DND_START_TIME"
DND_END_TIME="$DND_END_TIME"
EOF
                
                echo -e "${GREEN}Notification configuration saved to $NOTIFICATION_CONFIG${NC}"
                
                # Check if monitoring service is running and suggest restart
                if systemctl is-active --quiet sawlog-monitor.service 2>/dev/null || \
                   systemctl --user is-active --quiet sawlog-monitor.service 2>/dev/null; then
                    echo -e "${YELLOW}Monitoring service is running. You should restart it to apply changes:${NC}"
                    echo -e "  ${CYAN}sudo systemctl restart sawlog-monitor.service${NC} (for system service)"
                    echo -e "  ${CYAN}systemctl --user restart sawlog-monitor.service${NC} (for user service)"
                fi
                
                break
                ;;
            9)
                # Exit without saving
                echo
                echo -e "${YELLOW}Exiting without saving changes.${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
    done
    
    return 0
}

manage_bookmarks() {
    local action="$1"
    local bookmark_name="$2"
    local service_type="$3"
    local service_name="$4"
    local options="$5"
    
    # Make sure the bookmark file exists
    if [[ ! -f "$BOOKMARK_FILE" ]]; then
        mkdir -p "$CONFIG_DIR"
        touch "$BOOKMARK_FILE"
    fi
    
    case "$action" in
        "add")
            # Remove any existing bookmark with the same name
            sed -i "/^$bookmark_name|/d" "$BOOKMARK_FILE"
            
            # Add the new bookmark
            echo "$bookmark_name|$service_type|$service_name|$options" >> "$BOOKMARK_FILE"
            echo -e "${GREEN}Bookmark '$bookmark_name' added.${NC}"
            ;;
        "list")
            if [[ ! -s "$BOOKMARK_FILE" || $(grep -v '^#' "$BOOKMARK_FILE" | wc -l) -eq 0 ]]; then
                echo -e "${YELLOW}No bookmarks found.${NC}"
                return 1
            fi
            
            echo -e "${CYAN}${BOLD}Saved Bookmarks:${NC}"
            grep -v '^#' "$BOOKMARK_FILE" | while IFS='|' read -r name type service opts; do
                if [[ -n "$name" ]]; then
                    echo -e "  ${BOLD}$name${NC}:"
                    echo -e "    ${CYAN}Service:${NC} $service ${GRAY}($type)${NC}"
                    echo -e "    ${CYAN}Options:${NC} ${GRAY}$opts${NC}"
                    echo
                fi
            done
            ;;
        "use")
            local bookmark_line=$(grep "^$bookmark_name|" "$BOOKMARK_FILE")
            if [[ -z "$bookmark_line" ]]; then
                echo -e "${RED}Bookmark '$bookmark_name' not found.${NC}"
                echo -e "${YELLOW}Available bookmarks:${NC}"
                manage_bookmarks "list"
                return 1
            fi
            
            IFS='|' read -r name type service opts <<< "$bookmark_line"
            echo -e "${GREEN}Using bookmark '$name':${NC}"
            echo -e "  ${CYAN}Service:${NC} $service ${GRAY}($type)${NC}"
            echo -e "  ${CYAN}Options:${NC} ${GRAY}$opts${NC}"
            
            # Parse the options
            local opt_array=()
            # Split the options string into an array
            read -ra opt_array <<< "$opts"
            
            # Return the bookmark data to be used by the caller
            echo "$type|$service|${opt_array[*]}"
            ;;
        *)
            echo -e "${RED}Unknown bookmark action: $action${NC}"
            return 1
            ;;
    esac
}

copy_logs() {
    local service_type="$1"      # system, user, comm, kernel, or all
    local service_name="$2"
    local lines="$3"
    local output_file="$4"
    local to_clipboard="$5"
    local time_filter="$6"
    local until_filter="$7"
    local priority_filter="$8"
    local grep_pattern="$9"
    local highlight_pattern="${10}"
    local output_format="${11}"
    local follow_mode="${12}"
    local reverse_order="${13}"
    local export_format="${14}"
    local kernel_only="${15}"
    local show_all="${16}"
    local expand_output="${17}"
    local show_status="${18}"
    local multi_services="${19}"
    
    # Build the journalctl command
    local cmd=""
    local format_opt=""
    
    # Determine output format
    if [[ "$output_format" == "json" ]]; then
        format_opt="--output=json"
    elif [[ -n "$output_format" ]]; then
        format_opt="--output=$output_format"
    else
        format_opt="--output=short-precise"
    fi
    
    # Build the base command depending on service type
    case "$service_type" in
        "system")
            cmd="journalctl -u \"$service_name\" $format_opt"
            ;;
        "user")
            cmd="journalctl --user -u \"$service_name\" $format_opt"
            ;;
        "comm")
            cmd="journalctl _COMM=\"$service_name\" $format_opt"
            ;;
        "kernel")
            cmd="journalctl --dmesg $format_opt"
            ;;
        "all")
            cmd="journalctl $format_opt"
            ;;
        "multi")
            # For multiple services, build a complex command
            cmd="journalctl $format_opt"
            # Add each service to the command
            IFS=' ' read -ra services <<< "$multi_services"
            for svc in "${services[@]}"; do
                # Determine if it's a system or user service
                if grep -q "system|$svc" "$CONFIG_DIR/metadata.cache" 2>/dev/null; then
                    cmd="$cmd -u \"$svc\""
                elif grep -q "user|$svc" "$CONFIG_DIR/metadata.cache" 2>/dev/null; then
                    # For user services, we need a different approach
                    # We'll handle this later since we can't mix --user and system in one command
                    echo -e "${YELLOW}Warning: Can't mix system and user services in multi-service mode.${NC}"
                    echo -e "${YELLOW}Only showing system service: $svc${NC}"
                    cmd="$cmd -u \"$svc\""
                else
                    # For process names or unknown services
                    cmd="$cmd _COMM=\"$svc\""
                fi
            done
            ;;
        *)
            echo -e "${RED}Unknown service type: $service_type${NC}"
            return 1
            ;;
    esac
    
    # Add filters
    if [[ -n "$time_filter" ]]; then
        cmd="$cmd --since=\"$time_filter\""
    fi
    
    if [[ -n "$until_filter" ]]; then
        cmd="$cmd --until=\"$until_filter\""
    fi
    
    if [[ -n "$priority_filter" ]]; then
        cmd="$cmd --priority=\"$priority_filter\""
    fi
    
    if [[ -n "$grep_pattern" ]]; then
        cmd="$cmd | grep -i \"$grep_pattern\""
    fi
    
    if [[ -n "$reverse_order" ]]; then
        cmd="$cmd --reverse"
    fi
    
    if [[ -n "$kernel_only" ]]; then
        cmd="journalctl --dmesg $format_opt"
        # Add other filters
        if [[ -n "$time_filter" ]]; then
            cmd="$cmd --since=\"$time_filter\""
        fi
        if [[ -n "$until_filter" ]]; then
            cmd="$cmd --until=\"$until_filter\""
        fi
        if [[ -n "$priority_filter" ]]; then
            cmd="$cmd --priority=\"$priority_filter\""
        fi
        if [[ -n "$grep_pattern" ]]; then
            cmd="$cmd | grep -i \"$grep_pattern\""
        fi
        if [[ -n "$reverse_order" ]]; then
            cmd="$cmd --reverse"
        fi
    fi
    
    if [[ -n "$show_all" ]]; then
        cmd="journalctl $format_opt"
        # Add other filters
        if [[ -n "$time_filter" ]]; then
            cmd="$cmd --since=\"$time_filter\""
        fi
        if [[ -n "$until_filter" ]]; then
            cmd="$cmd --until=\"$until_filter\""
        fi
        if [[ -n "$priority_filter" ]]; then
            cmd="$cmd --priority=\"$priority_filter\""
        fi
        if [[ -n "$grep_pattern" ]]; then
            cmd="$cmd | grep -i \"$grep_pattern\""
        fi
        if [[ -n "$reverse_order" ]]; then
            cmd="$cmd --reverse"
        fi
    fi
    
    if [[ -n "$expand_output" ]]; then
        cmd="$cmd --no-full --no-pager"
    fi
    
    # Use pager or follow if needed
    if [[ -n "$follow_mode" ]]; then
        cmd="$cmd --follow"
    else
        # Add line count if not using time filter or follow mode
        if [[ -z "$time_filter" && -z "$until_filter" && "$service_type" != "all" && -z "$show_all" ]]; then
            cmd="$cmd -n $lines"
        fi
    fi
    
    # Show service status if requested
    if [[ -n "$show_status" && "$service_type" != "all" && "$service_type" != "kernel" && -z "$show_all" && "$service_type" != "multi" ]]; then
        # This will be displayed before log output
        show_service_status "$service_type" "$service_name"
    fi
    
    # Run the command with appropriate output handling
    if [[ -n "$export_format" && -n "$output_file" ]]; then
        # Export to specified format
        local log_output=$(eval "$cmd")
        export_logs "$log_output" "$export_format" "$output_file"
    elif [[ -n "$to_clipboard" && -n "$output_file" ]]; then
        # Both clipboard and file
        eval "$cmd" | tee >(format_log_output - "pretty" "$highlight_pattern" "$priority_filter" > "$output_file") | 
            format_log_output - "pretty" "$highlight_pattern" "$priority_filter" | copy_to_clipboard
        echo -e "${GREEN}Copied logs to clipboard and saved to $output_file${NC}"
    elif [[ -n "$to_clipboard" ]]; then
        # Clipboard only
        eval "$cmd" | format_log_output - "pretty" "$highlight_pattern" "$priority_filter" | copy_to_clipboard
        echo -e "${GREEN}Copied logs to clipboard${NC}"
    elif [[ -n "$output_file" ]]; then
        # File only
        eval "$cmd" | format_log_output - "pretty" "$highlight_pattern" "$priority_filter" > "$output_file"
        echo -e "${GREEN}Saved logs to $output_file${NC}"
    else
        # Output to terminal with formatting
        if [[ -n "$follow_mode" ]]; then
            # For follow mode, we need to use a real-time formatter
            eval "$cmd" | while read -r line; do
                echo "$line" | format_log_output - "pretty" "$highlight_pattern" "$priority_filter"
            done
        else
            # For normal display, pipe through formatter and pager if available
            if command -v less &> /dev/null && [[ -z "$expand_output" ]]; then
                eval "$cmd" | format_log_output - "pretty" "$highlight_pattern" "$priority_filter" | less -R
            else
                eval "$cmd" | format_log_output - "pretty" "$highlight_pattern" "$priority_filter"
            fi
        fi
    fi
}

interactive_search() {
    local pattern="$1"
    local scope="$2"
    local lines="$3"
    local output_file="$4"
    local to_clipboard="$5"
    local time_filter="$6"
    local until_filter="$7"
    local priority_filter="$8"
    local grep_pattern="$9"
    local highlight_pattern="${10}"
    local output_format="${11}"
    local follow_mode="${12}"
    local reverse_order="${13}"
    local export_format="${14}"
    local kernel_only="${15}"
    local show_all="${16}"
    local expand_output="${17}"
    local show_status="${18}"
    local multi_services="${19}"
    
    # Check for special modes first
    if [[ -n "$kernel_only" ]]; then
        copy_logs "kernel" "" "$lines" "$output_file" "$to_clipboard" "$time_filter" \
            "$until_filter" "$priority_filter" "$grep_pattern" "$highlight_pattern" \
            "$output_format" "$follow_mode" "$reverse_order" "$export_format" \
            "$kernel_only" "$show_all" "$expand_output" "$show_status" "$multi_services"
        return
    fi
    
    if [[ -n "$show_all" ]]; then
        copy_logs "all" "" "$lines" "$output_file" "$to_clipboard" "$time_filter" \
            "$until_filter" "$priority_filter" "$grep_pattern" "$highlight_pattern" \
            "$output_format" "$follow_mode" "$reverse_order" "$export_format" \
            "$kernel_only" "$show_all" "$expand_output" "$show_status" "$multi_services"
        return
    fi
    
    if [[ -n "$multi_services" ]]; then
        copy_logs "multi" "" "$lines" "$output_file" "$to_clipboard" "$time_filter" \
            "$until_filter" "$priority_filter" "$grep_pattern" "$highlight_pattern" \
            "$output_format" "$follow_mode" "$reverse_order" "$export_format" \
            "$kernel_only" "$show_all" "$expand_output" "$show_status" "$multi_services"
        return
    fi
    
    # Search for matching services
    IFS=' ' read -ra found_services <<< "$(search_services "$pattern" "$scope")"
    
    if [[ ${#found_services[@]} -eq 0 ]]; then
        echo -e "${RED}No services matching '$pattern' found.${NC}"
        
        # Suggest similar services
        local suggestions=()
        if [[ -f "$CONFIG_DIR/services.cache" ]]; then
            # Get all service names for fuzzy matching
            mapfile -t all_services < "$CONFIG_DIR/services.cache"
            
            # Find services that might be similar (simple approximate match)
            for service in "${all_services[@]}"; do
                if [[ "$service" =~ ${pattern:0:2} ]]; then
                    suggestions+=("$service")
                fi
            done
            
            # Display up to 5 suggestions
            if [[ ${#suggestions[@]} -gt 0 ]]; then
                echo -e "${YELLOW}Did you mean one of these?${NC}"
                for ((i=0; i<5 && i<${#suggestions[@]}; i++)); do
                    echo "  - ${suggestions[$i]}"
                done
            fi
        fi
        
        return 1
    fi
    
    if [[ ${#found_services[@]} -eq 1 ]]; then
        # Only one result, use it directly
        IFS=':' read -ra service_parts <<< "${found_services[0]}"
        local service_type="${service_parts[0]}"
        local service_name="${service_parts[1]}"
        
        echo -e "${BLUE}Found service: ${CYAN}$service_name${NC} (${YELLOW}$service_type${NC})"
        
        if [[ -z "$time_filter" && -z "$until_filter" && -z "$follow_mode" ]]; then
            # Ask for number of lines if no time filter or follow mode
            read -p "How many lines to show? [$lines]: " new_lines
            lines=${new_lines:-$lines}
        fi
        
        # Ask for output preferences if not specified
        if [[ -z "$output_file" && -z "$to_clipboard" && -z "$follow_mode" && -z "$export_format" ]]; then
            echo -e "Output options:"
            echo "  1) Display in terminal (default)"
            echo "  2) Copy to clipboard"
            echo "  3) Save to file"
            echo "  4) Both clipboard and file"
            echo "  5) Export as HTML, CSV, or Markdown"
            read -p "Choose output option [1-5]: " output_option
            
            case "$output_option" in
                2)
                    to_clipboard="yes"
                    ;;
                3)
                    read -p "Enter filename: " output_file
                    ;;
                4)
                    to_clipboard="yes"
                    read -p "Enter filename: " output_file
                    ;;
                5)
                    echo "Export formats:"
                    echo "  1) HTML (requires pandoc)"
                    echo "  2) CSV"
                    echo "  3) Markdown"
                    read -p "Choose export format [1-3]: " export_option
                    
                    case "$export_option" in
                        1) export_format="html" ;;
                        2) export_format="csv" ;;
                        3) export_format="markdown" ;;
                        *) export_format="markdown" ;;
                    esac
                    
                    read -p "Enter export filename: " output_file
                    ;;
            esac
        fi
        
        copy_logs "$service_type" "$service_name" "$lines" "$output_file" "$to_clipboard" \
            "$time_filter" "$until_filter" "$priority_filter" "$grep_pattern" "$highlight_pattern" \
            "$output_format" "$follow_mode" "$reverse_order" "$export_format" \
            "$kernel_only" "$show_all" "$expand_output" "$show_status" "$multi_services"
    else
        # Multiple results, let user choose
        echo -e "${BLUE}Found ${#found_services[@]} services matching '$pattern':${NC}"
        
        local i=1
        for service in "${found_services[@]}"; do
            IFS=':' read -ra service_parts <<< "$service"
            local service_type="${service_parts[0]}"
            local service_name="${service_parts[1]}"
            echo -e "$i) ${CYAN}$service_name${NC} (${YELLOW}$service_type${NC})"
            ((i++))
        done
        
        read -p "Select a service [1-${#found_services[@]}]: " selection
        
        # Validate selection
        if [[ ! "$selection" =~ ^[0-9]+$ || $selection -lt 1 || $selection -gt ${#found_services[@]} ]]; then
            echo -e "${RED}Invalid selection.${NC}"
            return 1
        fi
        
        # Get the selected service
        IFS=':' read -ra service_parts <<< "${found_services[selection-1]}"
        local service_type="${service_parts[0]}"
        local service_name="${service_parts[1]}"
        
        # Ask for number of lines if no time filter or follow mode
        if [[ -z "$time_filter" && -z "$until_filter" && -z "$follow_mode" ]]; then
            read -p "How many lines to show? [$lines]: " new_lines
            lines=${new_lines:-$lines}
        fi
        
        # Ask for output preferences if not specified
        if [[ -z "$output_file" && -z "$to_clipboard" && -z "$follow_mode" && -z "$export_format" ]]; then
            echo -e "Output options:"
            echo "  1) Display in terminal (default)"
            echo "  2) Copy to clipboard"
            echo "  3) Save to file"
            echo "  4) Both clipboard and file"
            echo "  5) Export as HTML, CSV, or Markdown"
            read -p "Choose output option [1-5]: " output_option
            
            case "$output_option" in
                2)
                    to_clipboard="yes"
                    ;;
                3)
                    read -p "Enter filename: " output_file
                    ;;
                4)
                    to_clipboard="yes"
                    read -p "Enter filename: " output_file
                    ;;
                5)
                    echo "Export formats:"
                    echo "  1) HTML (requires pandoc)"
                    echo "  2) CSV"
                    echo "  3) Markdown"
                    read -p "Choose export format [1-3]: " export_option
                    
                    case "$export_option" in
                        1) export_format="html" ;;
                        2) export_format="csv" ;;
                        3) export_format="markdown" ;;
                        *) export_format="markdown" ;;
                    esac
                    
                    read -p "Enter export filename: " output_file
                    ;;
            esac
        fi
        
        copy_logs "$service_type" "$service_name" "$lines" "$output_file" "$to_clipboard" \
            "$time_filter" "$until_filter" "$priority_filter" "$grep_pattern" "$highlight_pattern" \
            "$output_format" "$follow_mode" "$reverse_order" "$export_format" \
            "$kernel_only" "$show_all" "$expand_output" "$show_status" "$multi_services"
    fi
}

print_version() {
    echo -e "${BOLD}${TOOL_NAME} - Advanced journalctl log viewer and extractor${NC}"
    echo "Version: 2.0"
    echo "Author: Log Analysis Tools Team"
    echo "License: MIT"
    echo
    echo "System Information:"
    echo "  - $(uname -srmo)"
    echo "  - journalctl $(journalctl --version | head -n 1 | cut -d' ' -f2)"
    echo "  - bash ${BASH_VERSION}"
}

# Main script execution
if [[ "$0" == "$BASH_SOURCE" ]]; then
    # Default settings
    lines=50
    output_file=""
    to_clipboard=""
    scope="both"
    service_pattern=""
    time_filter=""
    until_filter=""
    priority_filter=""
    grep_pattern=""
    highlight_pattern=""
    output_format=""
    follow_mode=""
    reverse_order=""
    export_format=""
    kernel_only=""
    show_all=""
    expand_output=""
    show_status=""
    multi_services=""
    show_stats=""
    system_stats=""
    attention_areas=""
    top_issues=""
    num_issues=10
    health_report=""
    trend_days=7
    category_filter=""
    bookmark_name=""
    
    # Check for clipboard tools
    if command -v xclip &> /dev/null; then
        CLIPBOARD_TOOL="xclip"
    elif command -v wl-copy &> /dev/null; then
        CLIPBOARD_TOOL="wl-copy"
    elif command -v pbcopy &> /dev/null; then
        CLIPBOARD_TOOL="pbcopy"
    fi
    
    # If no arguments provided, show help
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    # Parse all arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--install)
                install_tool
                exit $?
                ;;
            -u|--uninstall)
                uninstall_tool
                exit 0
                ;;
            -v|--version)
                print_version
                exit 0
                ;;
            --refresh)
                update_service_cache
                exit 0
                ;;
            -n|--lines)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    lines="$2"
                    shift
                else
                    echo -e "${RED}Error: --lines requires a number.${NC}"
                    exit 1
                fi
                ;;
            -F|--file)
                if [[ -n "$2" ]]; then
                    output_file="$2"
                    shift
                else
                    echo -e "${RED}Error: --file requires a filename.${NC}"
                    exit 1
                fi
                ;;
            -c|--clipboard)
                if [[ -z "$CLIPBOARD_TOOL" ]]; then
                    echo -e "${RED}Error: No clipboard tool found. Please install xclip, wl-copy, or pbcopy.${NC}"
                    exit 1
                fi
                to_clipboard="yes"
                ;;
            -s|--system)
                scope="system"
                ;;
            -U|--user)
                scope="user"
                ;;
            -l|--list)
                list_services "$scope"
                exit 0
                ;;
            -j|--json)
                output_format="json"
                ;;
            -t|--time)
                if [[ -n "$2" ]]; then
                    time_filter="$2"
                    shift
                else
                    echo -e "${RED}Error: --time requires a time string.${NC}"
                    exit 1
                fi
                ;;
            -T|--until)
                if [[ -n "$2" ]]; then
                    until_filter="$2"
                    shift
                else
                    echo -e "${RED}Error: --until requires a time string.${NC}"
                    exit 1
                fi
                ;;
            --today)
                time_filter="today"
                ;;
            --yesterday)
                time_filter="yesterday"
                ;;
            -p|--priority)
                if [[ -n "$2" ]]; then
                    priority_filter="$2"
                    shift
                else
                    echo -e "${RED}Error: --priority requires a level (emerg,alert,crit,err,warning,notice,info,debug).${NC}"
                    exit 1
                fi
                ;;
            -g|--grep)
                if [[ -n "$2" ]]; then
                    grep_pattern="$2"
                    shift
                else
                    echo -e "${RED}Error: --grep requires a pattern.${NC}"
                    exit 1
                fi
                ;;
            -H|--highlight)
                if [[ -n "$2" ]]; then
                    highlight_pattern="$2"
                    shift
                else
                    echo -e "${RED}Error: --highlight requires a pattern.${NC}"
                    exit 1
                fi
                ;;
            -o|--output)
                if [[ -n "$2" ]]; then
                    output_format="$2"
                    shift
                else
                    echo -e "${RED}Error: --output requires a format (short,short-precise,verbose,json,cat).${NC}"
                    exit 1
                fi
                ;;
            -f|--follow)
                follow_mode="yes"
                ;;
            -r|--reverse)
                reverse_order="yes"
                ;;
            -E|--export)
                if [[ -n "$2" ]]; then
                    export_format="$2"
                    shift
                else
                    echo -e "${RED}Error: --export requires a format (html,csv,markdown).${NC}"
                    exit 1
                fi
                ;;
            -k|--kernel)
                kernel_only="yes"
                ;;
            -a|--all)
                show_all="yes"
                ;;
            -x|--expand)
                expand_output="yes"
                ;;
            --status)
                show_status="yes"
                ;;
            -m|--multi)
                if [[ -n "$2" ]]; then
                    multi_services="$2"
                    shift
                else
                    echo -e "${RED}Error: --multi requires service names.${NC}"
                    exit 1
                fi
                ;;
            --stats)
                show_stats="yes"
                ;;
            --system-stats)
                system_stats="yes"
                ;;
            --attention)
                attention_areas="yes"
                ;;
            --top-issues)
                top_issues="yes"
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    num_issues="$2"
                    shift
                fi
                ;;
            --health-report)
                health_report="yes"
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    output_file="$2"
                    shift
                fi
                ;;
            --trends)
                trend_analysis="yes"
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    trend_days="$2"
                    shift
                fi
                ;;
            --category)
                if [[ -n "$2" ]]; then
                    category_filter="$2"
                    shift
                else
                    echo -e "${RED}Error: --category requires a type (system, security, performance, etc.).${NC}"
                    exit 1
                fi
                ;;
            --setup-monitor)
                setup_monitoring_service
                exit $?
                ;;
            --disable-monitor)
                disable_monitoring_service
                exit $?
                ;;
            --configure-notifications)
                configure_notifications
                exit $?
                ;;
            --bookmark)
                if [[ -n "$2" ]]; then
                    bookmark_name="$2"
                    shift
                else
                    echo -e "${RED}Error: --bookmark requires a name.${NC}"
                    exit 1
                fi
                ;;
            --bookmarks)
                manage_bookmarks "list"
                exit 0
                ;;
            --use)
                if [[ -n "$2" ]]; then
                    # Use a saved bookmark
                    bookmark_data=$(manage_bookmarks "use" "$2")
                    if [[ $? -eq 0 && -n "$bookmark_data" ]]; then
                        IFS='|' read -r bookmark_type bookmark_service bookmark_opts <<< "$bookmark_data"
                        
                        # Parse the options from the bookmark
                        read -ra bookmark_opt_array <<< "$bookmark_opts"
                        
                        # Process the options
                        service_pattern="$bookmark_service"
                        scope="both"
                        if [[ "$bookmark_type" == "system" ]]; then
                            scope="system"
                        elif [[ "$bookmark_type" == "user" ]]; then
                            scope="user"
                        elif [[ "$bookmark_type" == "kernel" ]]; then
                            kernel_only="yes"
                        elif [[ "$bookmark_type" == "all" ]]; then
                            show_all="yes"
                        fi
                        
                        # Process options from the bookmark
                        for ((i=0; i<${#bookmark_opt_array[@]}; i++)); do
                            opt="${bookmark_opt_array[$i]}"
                            
                            case "$opt" in
                                -n|--lines)
                                    lines="${bookmark_opt_array[$((i+1))]}"
                                    ((i++))
                                    ;;
                                -f|--follow)
                                    follow_mode="yes"
                                    ;;
                                -p|--priority)
                                    priority_filter="${bookmark_opt_array[$((i+1))]}"
                                    ((i++))
                                    ;;
                                -g|--grep)
                                    grep_pattern="${bookmark_opt_array[$((i+1))]}"
                                    ((i++))
                                    ;;
                                -H|--highlight)
                                    highlight_pattern="${bookmark_opt_array[$((i+1))]}"
                                    ((i++))
                                    ;;
                                -o|--output)
                                    output_format="${bookmark_opt_array[$((i+1))]}"
                                    ((i++))
                                    ;;
                                -t|--time)
                                    time_filter="${bookmark_opt_array[$((i+1))]}"
                                    ((i++))
                                    ;;
                                -T|--until)
                                    until_filter="${bookmark_opt_array[$((i+1))]}"
                                    ((i++))
                                    ;;
                                -r|--reverse)
                                    reverse_order="yes"
                                    ;;
                                -x|--expand)
                                    expand_output="yes"
                                    ;;
                                --status)
                                    show_status="yes"
                                    ;;
                            esac
                        done
                    else
                        exit 1
                    fi
                    shift
                else
                    echo -e "${RED}Error: --use requires a bookmark name.${NC}"
                    exit 1
                fi
                ;;
            *)
                # Anything else is treated as a service pattern
                service_pattern="$1"
                ;;
        esac
        shift
    done
    
    # Quick check for dependencies
    check_dependencies || exit 1
    
    # Execute specific commands based on options
    if [[ -n "$system_stats" ]]; then
        show_system_stats
        exit 0
    fi
    
    if [[ -n "$attention_areas" ]]; then
        show_attention_areas "$time_filter" "$category_filter"
        exit 0
    fi
    
    if [[ -n "$top_issues" ]]; then
        show_top_issues "$num_issues" "$time_filter" "$category_filter"
        exit 0
    fi
    
    if [[ -n "$health_report" ]]; then
        generate_health_report "$output_file"
        exit 0
    fi
    
    if [[ -n "$trend_analysis" ]]; then
        show_trends "$trend_days"
        exit 0
    fi
    
    # If stats were requested, show them
    if [[ -n "$show_stats" ]]; then
        # If no service was specified, show stats for all
        if [[ -z "$service_pattern" && -z "$kernel_only" ]]; then
            show_log_stats "all" "" "$time_filter" "$until_filter" "$category_filter"
        elif [[ -n "$kernel_only" ]]; then
            show_log_stats "kernel" "" "$time_filter" "$until_filter" "$category_filter"
        else
            # Search for the service
            IFS=' ' read -ra found_services <<< "$(search_services "$service_pattern" "$scope")"
            
            if [[ ${#found_services[@]} -eq 0 ]]; then
                echo -e "${RED}No services matching '$service_pattern' found.${NC}"
                exit 1
            fi
            
            # Use the first match
            IFS=':' read -ra service_parts <<< "${found_services[0]}"
            local service_type="${service_parts[0]}"
            local service_name="${service_parts[1]}"
            
            show_log_stats "$service_type" "$service_name" "$time_filter" "$until_filter" "$category_filter"
        fi
        exit 0
    fi
    
    # If a bookmark was specified, save the current command
    if [[ -n "$bookmark_name" ]]; then
        # Determine the service type and name
        if [[ -n "$kernel_only" ]]; then
            manage_bookmarks "add" "$bookmark_name" "kernel" "" "$*"
        elif [[ -n "$show_all" ]]; then
            manage_bookmarks "add" "$bookmark_name" "all" "" "$*"
        elif [[ -n "$multi_services" ]]; then
            manage_bookmarks "add" "$bookmark_name" "multi" "$multi_services" "$*"
        else
            # Find the service first
            IFS=' ' read -ra found_services <<< "$(search_services "$service_pattern" "$scope")"
            
            if [[ ${#found_services[@]} -eq 0 ]]; then
                echo -e "${RED}No services matching '$service_pattern' found. Cannot create bookmark.${NC}"
                exit 1
            fi
            
            # Use the first match
            IFS=':' read -ra service_parts <<< "${found_services[0]}"
            local service_type="${service_parts[0]}"
            local service_name="${service_parts[1]}"
            
            # Save the bookmark
            manage_bookmarks "add" "$bookmark_name" "$service_type" "$service_name" "$*"
        fi
    fi
    
    # If a service pattern was provided, do an interactive search
    if [[ -n "$service_pattern" || -n "$kernel_only" || -n "$show_all" || -n "$multi_services" ]]; then
        interactive_search "$service_pattern" "$scope" "$lines" "$output_file" "$to_clipboard" \
            "$time_filter" "$until_filter" "$priority_filter" "$grep_pattern" "$highlight_pattern" \
            "$output_format" "$follow_mode" "$reverse_order" "$export_format" \
            "$kernel_only" "$show_all" "$expand_output" "$show_status" "$multi_services"
    else
        # No service pattern provided, but not showing help either
        echo -e "${YELLOW}No service pattern provided. Use -h or --help for usage information.${NC}"
        echo -e "${YELLOW}Or try one of these commands:${NC}"
        echo -e "  ${CYAN}$TOOL_NAME --list${NC}            # List all available services"
        echo -e "  ${CYAN}$TOOL_NAME --stats${NC}           # Show log statistics"
        echo -e "  ${CYAN}$TOOL_NAME --system-stats${NC}    # Show system-wide statistics"
        echo -e "  ${CYAN}$TOOL_NAME --attention${NC}       # Show areas that need attention"
        echo -e "  ${CYAN}$TOOL_NAME --top-issues${NC}      # Show top system issues"
        echo -e "  ${CYAN}$TOOL_NAME -a${NC}                # Show logs from all services"
        echo -e "  ${CYAN}$TOOL_NAME -k${NC}                # Show kernel logs"
        echo -e "  ${CYAN}$TOOL_NAME --bookmarks${NC}       # Show saved bookmarks"
        
        # Suggest some common services
        echo -e "\n${YELLOW}Common services you might want to check:${NC}"
        echo -e "  ${CYAN}$TOOL_NAME systemd${NC}           # System daemon logs"
        echo -e "  ${CYAN}$TOOL_NAME NetworkManager${NC}    # Network manager logs"
        echo -e "  ${CYAN}$TOOL_NAME sshd${NC}              # SSH daemon logs"
        echo -e "  ${CYAN}$TOOL_NAME plasma${NC}            # KDE Plasma logs"
        
        exit 1
    fi
ficategory_filter"
        exit 0
    fi
    
    if [[ -n "$health_report" ]]; then
        generate_health_report "$output_file"
        exit 0
    fi
    
    if [[ -n "$trend_analysis" ]]; then
        show_trends "$trend_days"
        exit 0
    fi
    
    # If stats were requested, show them
    if [[ -n "$show_stats" ]]; then
        # If no service was specified, show stats for all
        if [[ -z "$service_pattern" && -z "$kernel_only" ]]; then
            show_log_stats "all" "" "$time_filter" "$until_filter" "$category_filter"
        elif [[ -n "$kernel_only" ]]; then
            show_log_stats "kernel" "" "$time_filter" "$until_filter" "$category_filter"
        else
            # Search for the service
            IFS=' ' read -ra found_services <<< "$(search_services "$service_pattern" "$scope")"
            
            if [[ ${#found_services[@]} -eq 0 ]]; then
                echo -e "${RED}No services matching '$service_pattern' found.${NC}"
                exit 1
            fi
            
            # Use the first match
            IFS=':' read -ra service_parts <<< "${found_services[0]}"
            local service_type="${service_parts[0]}"
            local service_name="${service_parts[1]}"
            
            show_log_stats "$service_type" "$service_name" "$time_filter" "$until_filter" "$category_filter"
        fi
        exit 0
    fi
    
    # If a bookmark was specified, save the current command
    if [[ -n "$bookmark_name" ]]; then
        # Determine the service type and name
        if [[ -n "$kernel_only" ]]; then
            manage_bookmarks "add" "$bookmark_name" "kernel" "" "$*"
        elif [[ -n "$show_all" ]]; then
            manage_bookmarks "add" "$bookmark_name" "all" "" "$*"
        elif [[ -n "$multi_services" ]]; then
            manage_bookmarks "add" "$bookmark_name" "multi" "$multi_services" "$*"
        else
            # Find the service first
            IFS=' ' read -ra found_services <<< "$(search_services "$service_pattern" "$scope")"
            
            if [[ ${#found_services[@]} -eq 0 ]]; then
                echo -e "${RED}No services matching '$service_pattern' found. Cannot create bookmark.${NC}"
                exit 1
            fi
            
            # Use the first match
            IFS=':' read -ra service_parts <<< "${found_services[0]}"
            local service_type="${service_parts[0]}"
            local service_name="${service_parts[1]}"
            
            # Save the bookmark
            manage_bookmarks "add" "$bookmark_name" "$service_type" "$service_name" "$*"
        fi
    fi
    
    # If a service pattern was provided, do an interactive search
    if [[ -n "$service_pattern" || -n "$kernel_only" || -n "$show_all" || -n "$multi_services" ]]; then
        interactive_search "$service_pattern" "$scope" "$lines" "$output_file" "$to_clipboard" \
            "$time_filter" "$until_filter" "$priority_filter" "$grep_pattern" "$highlight_pattern" \
            "$output_format" "$follow_mode" "$reverse_order" "$export_format" \
            "$kernel_only" "$show_all" "$expand_output" "$show_status" "$multi_services"
    else
        # No service pattern provided, but not showing help either
        echo -e "${YELLOW}No service pattern provided. Use -h or --help for usage information.${NC}"
        echo -e "${YELLOW}Or try one of these commands:${NC}"
        echo -e "  ${CYAN}$TOOL_NAME --list${NC}            # List all available services"
        echo -e "  ${CYAN}$TOOL_NAME --stats${NC}           # Show log statistics"
        echo -e "  ${CYAN}$TOOL_NAME --system-stats${NC}    # Show system-wide statistics"
        echo -e "  ${CYAN}$TOOL_NAME --attention${NC}       # Show areas that need attention"
        echo -e "  ${CYAN}$TOOL_NAME --top-issues${NC}      # Show top system issues"
        echo -e "  ${CYAN}$TOOL_NAME -a${NC}                # Show logs from all services"
        echo -e "  ${CYAN}$TOOL_NAME -k${NC}                # Show kernel logs"
        echo -e "  ${CYAN}$TOOL_NAME --bookmarks${NC}       # Show saved bookmarks"
        
        # Suggest some common services
        echo -e "\n${YELLOW}Common services you might want to check:${NC}"
        echo -e "  ${CYAN}$TOOL_NAME systemd${NC}           # System daemon logs"
        echo -e "  ${CYAN}$TOOL_NAME NetworkManager${NC}    # Network manager logs"
        echo -e "  ${CYAN}$TOOL_NAME sshd${NC}              # SSH daemon logs"
        echo -e "  ${CYAN}$TOOL_NAME plasma${NC}            # KDE Plasma logs"
        
        exit 1
    fi
fi