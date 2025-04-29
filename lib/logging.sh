#!/bin/bash
# Logging functions for sawlog

# Fetch and display logs from a service
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

# Interactive search interface
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