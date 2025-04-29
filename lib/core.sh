#!/bin/bash
# Core constants and functionality for sawlog

# Tool information
TOOL_NAME="sawlog"
TOOL_VERSION="2.0"

# Directory structure
if [[ -z "$BASE_DIR" ]]; then
    # If not set by main script, determine it
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    BASE_DIR="$(dirname "$SCRIPT_DIR")"
fi

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

# Check for required dependencies
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

# Print version information
print_version() {
    echo -e "${BOLD}${TOOL_NAME} - Advanced journalctl log viewer and extractor${NC}"
    echo "Version: $TOOL_VERSION"
    echo "Author: Log Analysis Tools Team"
    echo "License: MIT"
    echo
    echo "System Information:"
    echo "  - $(uname -srmo)"
    echo "  - journalctl $(journalctl --version | head -n 1 | cut -d' ' -f2)"
    echo "  - bash ${BASH_VERSION}"
}

# Help function
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