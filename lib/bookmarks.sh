#!/bin/bash
# Bookmark management functions for sawlog

# Main bookmark management function
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