#!/bin/bash
# Installation functions for sawlog

# Install the tool
install_tool() {
    echo -e "${BLUE}Installing ${TOOL_NAME}...${NC}"
    
    # Check dependencies
    check_dependencies || return 1
    
    # Create directories if they don't exist
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$STATS_CACHE_DIR"
    mkdir -p "${HOME}/.local/lib/sawlog"
    mkdir -p "${HOME}/.local/share/sawlog"
    
    # Copy files to install directory
    local sawlog_bin="$INSTALL_DIR/$TOOL_NAME"
    
    # Get the path to the bin script in the current package
    local bin_script="${BASE_DIR}/bin/sawlog"
    if [[ -f "$bin_script" ]]; then
        cp "$bin_script" "$sawlog_bin"
        chmod +x "$sawlog_bin"
    else
        # Fallback to copying the script that was used to execute this command
        cp "$0" "$sawlog_bin"
        chmod +x "$sawlog_bin"
    fi
    
    # Copy all lib files to proper location
    for lib_file in "${BASE_DIR}"/lib/*.sh; do
        if [[ -f "$lib_file" ]]; then
            cp "$lib_file" "${HOME}/.local/lib/sawlog/"
            chmod +x "${HOME}/.local/lib/sawlog/$(basename "$lib_file")"
        fi
    done
    
    # Copy completion files
    mkdir -p "${HOME}/.local/lib/sawlog/completion"
    for comp_file in "${BASE_DIR}"/lib/completion/*.sh; do
        if [[ -f "$comp_file" ]]; then
            cp "$comp_file" "${HOME}/.local/lib/sawlog/completion/"
        fi
    done
    
    # Copy monitor service script and templates
    mkdir -p "${HOME}/.local/share/sawlog/templates"
    cp "${BASE_DIR}/share/sawlog/monitor-service.sh" "${HOME}/.local/share/sawlog/"
    chmod +x "${HOME}/.local/share/sawlog/monitor-service.sh"
    cp "${BASE_DIR}/share/sawlog/templates/"*.template "${HOME}/.local/share/sawlog/templates/"
    
    # Copy monitor service script to the expected location
    cp "${BASE_DIR}/share/sawlog/monitor-service.sh" "$MONITOR_SCRIPT"
    chmod +x "$MONITOR_SCRIPT"
    
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
        cp "${HOME}/.local/share/sawlog/templates/monitor.conf.template" "$MONITOR_CONFIG"
        echo -e "${GREEN}Created default monitor configuration${NC}"
    fi
    
    # Create default notification configuration
    if [[ ! -f "$NOTIFICATION_CONFIG" ]]; then
        cp "${HOME}/.local/share/sawlog/templates/notification.conf.template" "$NOTIFICATION_CONFIG"
        echo -e "${GREEN}Created default notification configuration${NC}"
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
    
    # Update and reload systemd services if they exist
    update_systemd_services
    
    echo -e "${GREEN}${TOOL_NAME} has been installed successfully!${NC}"
    echo -e "Run '${CYAN}${TOOL_NAME} --help${NC}' for usage information."
    echo -e "To set up the monitoring service, run '${CYAN}${TOOL_NAME} --setup-monitor${NC}'."
}

# Update and reload systemd services
update_systemd_services() {
    local service_updated=false
    
    # Check if system service exists and update it
    if [[ -f "$SERVICE_FILE" ]]; then
        echo -e "${CYAN}Updating system service file...${NC}"
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
        
        # Check if there are differences
        if ! diff -q /tmp/sawlog-monitor.service "$SERVICE_FILE" &>/dev/null; then
            sudo mv /tmp/sawlog-monitor.service "$SERVICE_FILE"
            service_updated=true
            echo -e "${GREEN}System service file updated.${NC}"
        else
            rm /tmp/sawlog-monitor.service
        fi
        
        # Reload and restart the service if it's active
        if [[ "$service_updated" == "true" || -n "$1" ]]; then
            echo -e "${CYAN}Reloading systemd daemon...${NC}"
            sudo systemctl daemon-reload
            
            if systemctl is-active --quiet sawlog-monitor.service; then
                echo -e "${CYAN}Restarting system monitoring service...${NC}"
                sudo systemctl restart sawlog-monitor.service
                echo -e "${GREEN}System monitoring service restarted.${NC}"
            fi
        fi
    fi
    
    # Check if user service exists and update it
    if [[ -f "$USER_SERVICE_FILE" ]]; then
        echo -e "${CYAN}Updating user service file...${NC}"
        
        mkdir -p "$(dirname "$USER_SERVICE_FILE")"
        cat > /tmp/sawlog-monitor-user.service << EOF
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
        
        # Check if there are differences
        if ! diff -q /tmp/sawlog-monitor-user.service "$USER_SERVICE_FILE" &>/dev/null; then
            mv /tmp/sawlog-monitor-user.service "$USER_SERVICE_FILE"
            service_updated=true
            echo -e "${GREEN}User service file updated.${NC}"
        else
            rm /tmp/sawlog-monitor-user.service
        fi
        
        # Reload and restart the service if it's active
        if [[ "$service_updated" == "true" || -n "$1" ]]; then
            echo -e "${CYAN}Reloading user systemd daemon...${NC}"
            systemctl --user daemon-reload
            
            if systemctl --user is-active --quiet sawlog-monitor.service; then
                echo -e "${CYAN}Restarting user monitoring service...${NC}"
                systemctl --user restart sawlog-monitor.service
                echo -e "${GREEN}User monitoring service restarted.${NC}"
            fi
        fi
    fi
}

# Install bash completion
install_bash_completion() {
    if [[ -d "/etc/bash_completion.d" && -w "/etc/bash_completion.d" ]]; then
        cp "${HOME}/.local/lib/sawlog/completion/bash_completion.sh" "$COMPLETION_FILE"
        echo -e "${GREEN}Bash completion installed to $COMPLETION_FILE${NC}"
    elif [[ -d "$HOME/.bash_completion.d" ]]; then
        mkdir -p "$HOME/.bash_completion.d"
        cp "${HOME}/.local/lib/sawlog/completion/bash_completion.sh" "$HOME/.bash_completion.d/sawlog_completion"
        
        # Check if .bash_completion sources the directory
        if [[ -f "$HOME/.bash_completion" ]] && ! grep -q ".bash_completion.d/" "$HOME/.bash_completion" 2>/dev/null; then
            echo 'for file in ~/.bash_completion.d/*; do source "$file"; done' >> "$HOME/.bash_completion"
        fi
        echo -e "${GREEN}Bash completion installed to ~/.bash_completion.d/sawlog_completion${NC}"
    else
        mkdir -p "$HOME/.bash_completion.d"
        cp "${HOME}/.local/lib/sawlog/completion/bash_completion.sh" "$HOME/.bash_completion.d/sawlog_completion"
        
        # Add to .bashrc if .bash_completion doesn't exist
        if ! grep -q ".bash_completion.d/sawlog_completion" "$HOME/.bashrc" 2>/dev/null; then
            echo 'if [ -f ~/.bash_completion.d/sawlog_completion ]; then source ~/.bash_completion.d/sawlog_completion; fi' >> "$HOME/.bashrc"
        fi
        echo -e "${GREEN}Bash completion installed to ~/.bash_completion.d/sawlog_completion${NC}"
        echo -e "${YELLOW}You may need to restart your shell or source ~/.bashrc for completion to work${NC}"
    fi
}

# Install zsh completion
install_zsh_completion() {
    mkdir -p "${HOME}/.zsh/completions"
    cp "${HOME}/.local/lib/sawlog/completion/zsh_completion.sh" "$ZSH_COMPLETION_FILE"
    
    # Check if the completions directory is in fpath
    if ! grep -q ".zsh/completions" "$HOME/.zshrc" 2>/dev/null; then
        echo 'fpath=(~/.zsh/completions $fpath)' >> "$HOME/.zshrc"
        echo 'autoload -Uz compinit && compinit' >> "$HOME/.zshrc"
    fi
    
    echo -e "${GREEN}ZSH completion installed to $ZSH_COMPLETION_FILE${NC}"
    echo -e "${YELLOW}You may need to restart your shell or run 'autoload -Uz compinit && compinit' for completion to work${NC}"
}

# Uninstall the tool
uninstall_tool() {
    echo -e "${BLUE}Uninstalling ${TOOL_NAME}...${NC}"
    
    # Stop and disable the monitoring service if it exists
    if systemctl is-active --quiet sawlog-monitor.service 2>/dev/null; then
        echo -e "${CYAN}Stopping system monitoring service...${NC}"
        sudo systemctl stop sawlog-monitor.service
        sudo systemctl disable sawlog-monitor.service
        echo -e "${GREEN}Stopped and disabled system monitoring service${NC}"
    fi
    
    if systemctl --user is-active --quiet sawlog-monitor.service 2>/dev/null; then
        echo -e "${CYAN}Stopping user monitoring service...${NC}"
        systemctl --user stop sawlog-monitor.service
        systemctl --user disable sawlog-monitor.service
        echo -e "${GREEN}Stopped and disabled user monitoring service${NC}"
    fi
    
    # Remove service files
    if [[ -f "$SERVICE_FILE" ]]; then
        sudo rm "$SERVICE_FILE"
        sudo systemctl daemon-reload
        echo -e "${GREEN}Removed system service file${NC}"
    fi
    
    if [[ -f "$USER_SERVICE_FILE" ]]; then
        rm "$USER_SERVICE_FILE"
        systemctl --user daemon-reload
        echo -e "${GREEN}Removed user service file${NC}"
    fi
    
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
    
    # Remove lib files
    if [[ -d "${HOME}/.local/lib/sawlog" ]]; then
        rm -rf "${HOME}/.local/lib/sawlog"
        echo -e "${GREEN}Removed library files${NC}"
    fi
    
    # Remove share files
    if [[ -d "${HOME}/.local/share/sawlog" ]]; then
        rm -rf "${HOME}/.local/share/sawlog"
        echo -e "${GREEN}Removed shared files${NC}"
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