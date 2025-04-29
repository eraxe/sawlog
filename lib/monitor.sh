#!/bin/bash
# Monitoring setup functions for sawlog

# Setup the monitoring service
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
        cp "${BASE_DIR}/share/sawlog/templates/monitor.conf.template" "$MONITOR_CONFIG"
    fi
    
    # Create the notification configuration if it doesn't exist
    if [[ ! -f "$NOTIFICATION_CONFIG" ]]; then
        echo -e "${CYAN}Creating default notification configuration...${NC}"
        mkdir -p "$CONFIG_DIR"
        cp "${BASE_DIR}/share/sawlog/templates/notification.conf.template" "$NOTIFICATION_CONFIG"
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

# Disable the monitoring service
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