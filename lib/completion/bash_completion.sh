# Bash completion for sawlog
_sawlog_completions() {
    local cur prev opts services priorities bookmark_names categories
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Options
    opts="-h --help -i --install -u --uninstall -v --version -n --lines -f --follow -p --priority -g --grep -H --highlight -o --output -s --system -U --user -m --multi -a --all -k --kernel -x --expand -t --time -T --until --today --yesterday -c --clipboard -F --file -j --json -E --export -r --reverse --bookmark --bookmarks --use --refresh --status -l --list --stats --system-stats --attention --top-issues --category --setup-monitor --disable-monitor --configure-notifications --health-report --trends"
    
    # Handle option arguments
    case $prev in
        -n|--lines|--top-issues)
            COMPREPLY=( $(compgen -W "10 20 50 100 200 500 1000" -- "$cur") )
            return 0
            ;;
        -p|--priority)
            priorities="emerg alert crit err warning notice info debug"
            COMPREPLY=( $(compgen -W "$priorities" -- "$cur") )
            return 0
            ;;
        -o|--output)
            COMPREPLY=( $(compgen -W "short short-precise verbose json cat pretty" -- "$cur") )
            return 0
            ;;
        -F|--file)
            COMPREPLY=( $(compgen -f "$cur") )
            return 0
            ;;
        -t|--time|-T|--until|--trends)
            COMPREPLY=( $(compgen -W "today yesterday '1h ago' '12h ago' '1d ago' '1 week ago' '7' '14' '30'" -- "$cur") )
            return 0
            ;;
        -E|--export)
            COMPREPLY=( $(compgen -W "html csv markdown" -- "$cur") )
            return 0
            ;;
        --category)
            categories="system security performance application network hardware"
            COMPREPLY=( $(compgen -W "$categories" -- "$cur") )
            return 0
            ;;
        --use)
            # Get bookmark names from the bookmark file
            if [[ -f "$HOME/.config/sawlog/bookmarks.conf" ]]; then
                bookmark_names=$(grep -v '^#' "$HOME/.config/sawlog/bookmarks.conf" | cut -d '|' -f 1)
                COMPREPLY=( $(compgen -W "$bookmark_names" -- "$cur") )
            fi
            return 0
            ;;
    esac
    
    # If starting with dash, suggest options
    if [[ $cur == -* ]]; then
        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        return 0
    fi
    
    # Otherwise, suggest services from cache
    if [[ -f "$HOME/.config/sawlog/services.cache" ]]; then
        services=$(cat "$HOME/.config/sawlog/services.cache")
        COMPREPLY=( $(compgen -W "$services" -- "$cur") )
    fi
    
    return 0
}

complete -F _sawlog_completions sawlog