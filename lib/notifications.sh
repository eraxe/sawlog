#!/bin/bash
# Notification configuration functions for sawlog

# Configure notification preferences
configure_notifications() {
    echo -e "${BOLD}${BLUE}Configure Monitoring Notifications:${NC}"
    echo
    
    # Create default notification config if it doesn't exist
    if [[ ! -f "$NOTIFICATION_CONFIG" ]]; then
        mkdir -p "$CONFIG_DIR"
        cp "${BASE_DIR}/share/sawlog/templates/notification.conf.template" "$NOTIFICATION_CONFIG"
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