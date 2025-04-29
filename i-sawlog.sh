#!/bin/bash

# sawlog - Advanced journalctl log viewer and extractor
# Version: 1.0

# Constants
TOOL_NAME="sawlog"
INSTALL_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/sawlog"
COMPLETION_FILE="/etc/bash_completion.d/sawlog_completion"
ZSH_COMPLETION_FILE="${HOME}/.zsh/completions/_sawlog"
BOOKMARK_FILE="${CONFIG_DIR}/bookmarks.conf"
THEME_FILE="${CONFIG_DIR}/theme.conf"

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
    echo "  --stats                 Show log statistics (service frequency, error rates)"
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
    
    # Install bash completion
    install_bash_completion
    
    # Install zsh completion if zsh is available
    if command -v zsh &> /dev/null; then
        install_zsh_completion
    fi
    
    # Check if install directory is in PATH
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH.${NC}"
        echo -e "${YELLOW}Add the following line to your .bashrc or .zshrc:${NC}"
        echo "export PATH=\"\$PATH:$INSTALL_DIR\""
    fi
    
    echo -e "${GREEN}${TOOL_NAME} has been installed successfully!${NC}"
    echo -e "Run '${CYAN}${TOOL_NAME} --help${NC}' for usage information."
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

uninstall_tool() {
    echo -e "${BLUE}Uninstalling ${TOOL_NAME}...${NC}"
    
    # Remove the executable
    if [[ -f "$INSTALL_DIR/$TOOL_NAME" ]]; then
        rm "$INSTALL_DIR/$TOOL_NAME"
        echo -e "${GREEN}Removed $INSTALL_DIR/$TOOL_NAME${NC}"
    fi
    
    # Ask if the user wants to keep configuration
    read -p "Do you want to keep your configuration and bookmarks? [Y/n] " keep_config
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
    local cur prev opts services priorities bookmark_names
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    
    # Options
    opts="-h --help -i --install -u --uninstall -v --version -n --lines -f --follow -p --priority -g --grep -H --highlight -o --output -s --system -U --user -m --multi -a --all -k --kernel -x --expand -t --time -T --until --today --yesterday -c --clipboard -F --file -j --json -E --export -r --reverse --bookmark --bookmarks --use --refresh --status -l --list --stats"
    
    # Handle option arguments
    case \$prev in
        -n|--lines)
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
        -t|--time|-T|--until)
            COMPREPLY=( \$(compgen -W "today yesterday '1h ago' '12h ago' '1d ago' '1 week ago'" -- "\$cur") )
            return 0
            ;;
        -E|--export)
            COMPREPLY=( \$(compgen -W "html csv markdown" -- "\$cur") )
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
    local -a options time_options lines_options priority_options output_options export_options bookmark_options
    
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

show_log_stats() {
    local service_type="$1"
    local service_name="$2"
    local time_filter="$3"
    local until_filter="$4"
    
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
    
    echo
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
    echo "Version: 1.0"
    echo "Author: Your Name"
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
            --create-bash-completion)
                create_bash_completion_script
                exit 0
                ;;
            --create-zsh-completion)
                create_zsh_completion_script
                exit 0
                ;;
            -r|--refresh|--refresh)
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
    
    # If stats were requested, show them
    if [[ -n "$show_stats" ]]; then
        # If no service was specified, show stats for all
        if [[ -z "$service_pattern" && -z "$kernel_only" ]]; then
            show_log_stats "all" "" "$time_filter" "$until_filter"
        elif [[ -n "$kernel_only" ]]; then
            show_log_stats "kernel" "" "$time_filter" "$until_filter"
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
            
            show_log_stats "$service_type" "$service_name" "$time_filter" "$until_filter"
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
