#!/bin/bash
# Utility functions for sawlog

# Function to copy to clipboard
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

# Function to format log output
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

# Export logs to different formats
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