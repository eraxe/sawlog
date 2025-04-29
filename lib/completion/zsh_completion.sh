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
    
    case $state in
        bookmarks)
            if [[ -f "$HOME/.config/sawlog/bookmarks.conf" ]]; then
                local -a bookmarks
                bookmarks=($(grep -v '^#' "$HOME/.config/sawlog/bookmarks.conf" | cut -d '|' -f 1))
                _describe 'bookmarks' bookmarks
            fi
            ;;
    esac
    
    if [[ -f "$HOME/.config/sawlog/services.cache" ]]; then
        local -a services
        services=($(cat "$HOME/.config/sawlog/services.cache"))
        _describe 'services' services
    fi
    
    _arguments -s $options
}

_sawlog