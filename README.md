# 🪵 SawLog - Advanced System Log Explorer

<svg width="240" height="240" viewBox="0 0 240 240" xmlns="http://www.w3.org/2000/svg">
  <!-- Background circle -->
  <circle cx="120" cy="120" r="110" fill="#2d3748" />
  
  <!-- Outer ring -->
  <circle cx="120" cy="120" r="105" fill="none" stroke="#48bb78" stroke-width="4" />
  
  <!-- Banner -->
<svg viewBox="0 0 800 250" xmlns="http://www.w3.org/2000/svg">
  <!-- Background with retro 80s grid effect -->
  <defs>
    <linearGradient id="retroBg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0b0014" />
      <stop offset="100%" stop-color="#1e1e2e" />
    </linearGradient>
    <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
      <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#6c0ba8" stroke-width="0.5" opacity="0.2"/>
    </pattern>
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="2" result="blur" />
      <feComposite in="SourceGraphic" in2="blur" operator="over" />
    </filter>
    <linearGradient id="synthTitle" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#f72585" />
      <stop offset="50%" stop-color="#7209b7" />
      <stop offset="100%" stop-color="#4361ee" />
    </linearGradient>
  </defs>
  
  <!-- Main background -->
  <rect width="800" height="250" fill="url(#retroBg)" rx="8" />
  <rect width="800" height="250" fill="url(#grid)" rx="8" />
  
  <!-- Decorative elements -->
  <circle cx="750" cy="50" r="30" fill="#f72585" opacity="0.1" />
  <circle cx="720" cy="80" r="50" fill="#4361ee" opacity="0.1" />
  <circle cx="50" cy="200" r="40" fill="#f72585" opacity="0.1" />
  
  <!-- Title and Tagline with retro 80s style -->
  <text x="400" y="35" font-family="monospace" font-size="32" font-weight="bold" fill="url(#synthTitle)" text-anchor="middle" filter="url(#glow)">SAWLOG</text>
  <text x="400" y="60" font-family="monospace" font-size="14" fill="#cba6f7" text-anchor="middle">Advanced journalctl log viewer and extractor</text>
  
  <!-- GitHub link -->
  <text x="400" y="80" font-family="monospace" font-size="11" fill="#a6adc8" text-anchor="middle">https://github.com/eraxe/sawlog.git</text>
  
  <!-- Terminal Window Border - TALLER to include buttons -->
  <rect x="50" y="95" width="700" height="135" rx="6" fill="#191724" stroke="#6c7086" stroke-width="1.5" />
  <rect x="50" y="95" width="700" height="20" rx="6" fill="#26233a" />
  
  <!-- Terminal Window Controls -->
  <circle cx="65" cy="105" r="4.5" fill="#f38ba8" />
  <circle cx="85" cy="105" r="4.5" fill="#fab387" />
  <circle cx="105" cy="105" r="4.5" fill="#a6e3a1" />
  
  <!-- Terminal title -->
  <text x="400" y="109" font-family="monospace" font-size="10" fill="#cdd6f4" text-anchor="middle">sawlog-terminal</text>
  
  <!-- Command prompt with cursor -->
  <text x="60" y="130" font-family="monospace" font-size="11" fill="#cdd6f4">$</text>
  <text x="75" y="130" font-family="monospace" font-size="11" fill="#a6e3a1">sawlog</text>
  <text x="125" y="130" font-family="monospace" font-size="11" fill="#89b4fa">NetworkManager</text>
  <text x="245" y="130" font-family="monospace" font-size="11" fill="#f5c2e7">--priority=err</text>
  <text x="345" y="130" font-family="monospace" font-size="11" fill="#89dceb">--follow</text>
  <rect x="405" y="122" width="6" height="12" fill="#cdd6f4" opacity="0.5">
    <animate attributeName="opacity" values="0.5;0;0.5" dur="1.5s" repeatCount="indefinite" />
  </rect>
  
  <!-- Log Entries with subtle shadow -->
  <!-- Log line 1 -->
  <rect x="60" y="140" width="675" height="13" rx="2" fill="#1a1823" stroke="#2e2a3a" stroke-width="0.5" />
  <rect x="60" y="140" width="140" height="13" rx="2" fill="#585b70" opacity="0.4" />
  <text x="65" y="150" font-family="monospace" font-size="9.5" fill="#bac2de">Apr 29 10:23:18</text>
  <rect x="200" y="140" width="95" height="13" rx="2" fill="#cba6f7" opacity="0.6" />
  <text x="205" y="150" font-family="monospace" font-size="9.5" fill="#1e1e2e">NetworkManager</text>
  <rect x="295" y="140" width="440" height="13" rx="2" fill="#f38ba8" opacity="0.6" />
  <text x="300" y="150" font-family="monospace" font-size="9.5" fill="#1e1e2e">ERROR: Connection failed: Timeout was reached</text>
  
  <!-- Log line 2 -->
  <rect x="60" y="157" width="675" height="13" rx="2" fill="#1a1823" stroke="#2e2a3a" stroke-width="0.5" />
  <rect x="60" y="157" width="140" height="13" rx="2" fill="#585b70" opacity="0.4" />
  <text x="65" y="167" font-family="monospace" font-size="9.5" fill="#bac2de">Apr 29 10:23:20</text>
  <rect x="200" y="157" width="95" height="13" rx="2" fill="#cba6f7" opacity="0.6" />
  <text x="205" y="167" font-family="monospace" font-size="9.5" fill="#1e1e2e">NetworkManager</text>
  <rect x="295" y="157" width="440" height="13" rx="2" fill="#f38ba8" opacity="0.6" />
  <text x="300" y="167" font-family="monospace" font-size="9.5" fill="#1e1e2e">ERROR: DHCP client failed to get an IP address</text>
  
  <!-- Log line 3 -->
  <rect x="60" y="174" width="675" height="13" rx="2" fill="#1a1823" stroke="#2e2a3a" stroke-width="0.5" />
  <rect x="60" y="174" width="140" height="13" rx="2" fill="#585b70" opacity="0.4" />
  <text x="65" y="184" font-family="monospace" font-size="9.5" fill="#bac2de">Apr 29 10:24:05</text>
  <rect x="200" y="174" width="95" height="13" rx="2" fill="#cba6f7" opacity="0.6" />
  <text x="205" y="184" font-family="monospace" font-size="9.5" fill="#1e1e2e">NetworkManager</text>
  <rect x="295" y="174" width="440" height="13" rx="2" fill="#f38ba8" opacity="0.6" />
  <text x="300" y="184" font-family="monospace" font-size="9.5" fill="#1e1e2e">ERROR: Connection activation failed: (2) Device not ready</text>
  
  <!-- Command buttons INSIDE terminal -->
  <rect x="60" y="195" width="100" height="20" rx="4" fill="#f9e2af" opacity="0.75">
    <animate attributeName="opacity" values="0.75;0.85;0.75" dur="3s" repeatCount="indefinite" />
  </rect>
  <text x="110" y="208" font-family="monospace" font-size="9" fill="#1e1e2e" text-anchor="middle" font-weight="bold">BOOKMARKS</text>
  
  <rect x="170" y="195" width="100" height="20" rx="4" fill="#a6e3a1" opacity="0.75">
    <animate attributeName="opacity" values="0.75;0.85;0.75" dur="4s" repeatCount="indefinite" />
  </rect>
  <text x="220" y="208" font-family="monospace" font-size="9" fill="#1e1e2e" text-anchor="middle" font-weight="bold">STATISTICS</text>
  
  <rect x="280" y="195" width="100" height="20" rx="4" fill="#89b4fa" opacity="0.75">
    <animate attributeName="opacity" values="0.75;0.85;0.75" dur="3.5s" repeatCount="indefinite" />
  </rect>
  <text x="330" y="208" font-family="monospace" font-size="9" fill="#1e1e2e" text-anchor="middle" font-weight="bold">TOP ISSUES</text>
  
  <rect x="390" y="195" width="120" height="20" rx="4" fill="#f5c2e7" opacity="0.75">
    <animate attributeName="opacity" values="0.75;0.85;0.75" dur="2.5s" repeatCount="indefinite" />
  </rect>
  <text x="450" y="208" font-family="monospace" font-size="9" fill="#1e1e2e" text-anchor="middle" font-weight="bold">HEALTH REPORT</text>
  
  <!-- Status bar at bottom of terminal -->
  <rect x="50" y="230" width="700" height="12" rx="0" fill="#26233a" />
  <text x="60" y="239" font-family="monospace" font-size="8" fill="#a6adc8">sawlog v2.0</text>
  <text x="725" y="239" font-family="monospace" font-size="8" fill="#a6adc8" text-anchor="end">3 errors found</text>
  
  <!-- Feature Indicators with enhanced icons -->
  <g transform="translate(520, 195)">
    <!-- Monitor icon - animated -->
    <rect x="0" y="0" width="20" height="20" rx="3" fill="#cba6f7" opacity="0.8" />
    <rect x="4" y="4" width="12" height="8" rx="1" fill="#1e1e2e" />
    <rect x="8" y="12" width="4" height="4" fill="#1e1e2e" />
    <rect x="6" y="16" width="8" height="1" fill="#1e1e2e" />
    <circle cx="10" cy="8" r="2" fill="#f72585" opacity="0.8">
      <animate attributeName="opacity" values="0.8;0.3;0.8" dur="2s" repeatCount="indefinite" />
    </circle>
    <text x="25" y="12" font-family="monospace" font-size="8" fill="#cdd6f4">Monitor</text>
  </g>
  
  <g transform="translate(585, 195)">
    <!-- Alert icon - animated -->
    <rect x="0" y="0" width="20" height="20" rx="3" fill="#f38ba8" opacity="0.8" />
    <path d="M10,3 L17,15 L3,15 Z" fill="#1e1e2e" />
    <rect x="9" y="7" width="2" height="4" fill="#1e1e2e" />
    <rect x="9" y="12" width="2" height="2" fill="#1e1e2e">
      <animate attributeName="fill" values="#1e1e2e;#f9e2af;#1e1e2e" dur="1.5s" repeatCount="indefinite" />
    </rect>
    <text x="25" y="12" font-family="monospace" font-size="8" fill="#cdd6f4">Alert</text>
  </g>

  <g transform="translate(635, 195)">
    <!-- Stats icon - animated bars -->
    <rect x="0" y="0" width="20" height="20" rx="3" fill="#a6e3a1" opacity="0.8" />
    <rect x="4" y="12" width="2" height="4" fill="#1e1e2e">
      <animate attributeName="height" values="4;6;4" dur="2s" repeatCount="indefinite" />
    </rect>
    <rect x="8" y="8" width="2" height="8" fill="#1e1e2e">
      <animate attributeName="height" values="8;4;8" dur="2s" repeatCount="indefinite" />
    </rect>
    <rect x="12" y="4" width="2" height="12" fill="#1e1e2e">
      <animate attributeName="height" values="12;8;12" dur="2s" repeatCount="indefinite" />
    </rect>
    <text x="25" y="12" font-family="monospace" font-size="8" fill="#cdd6f4">Stats</text>
  </g>
  
  <g transform="translate(685, 195)">
    <!-- Search icon with pulse -->
    <rect x="0" y="0" width="20" height="20" rx="3" fill="#89b4fa" opacity="0.8" />
    <circle cx="8" cy="8" r="4" fill="none" stroke="#1e1e2e" stroke-width="1.5" />
    <line x1="11" y1="11" x2="15" y2="15" stroke="#1e1e2e" stroke-width="1.5" />
    <circle cx="8" cy="8" r="6" fill="none" stroke="#4cc4ff" stroke-width="0.5" opacity="0.5">
      <animate attributeName="r" values="4;7;4" dur="2s" repeatCount="indefinite" />
      <animate attributeName="opacity" values="0.5;0;0.5" dur="2s" repeatCount="indefinite" />
    </circle>
    <text x="25" y="12" font-family="monospace" font-size="8" fill="#cdd6f4">Find</text>
  </g>
</svg>
  
  <!-- Magnifying glass -->
  <circle cx="155" cy="150" r="24" fill="none" stroke="#e2e8f0" stroke-width="5" />
  <line x1="172" y1="167" x2="190" y2="185" stroke="#e2e8f0" stroke-width="8" stroke-linecap="round" />
  
  <!-- Saw tooth pattern on top -->
  <path d="M75,55 L85,35 L95,55 L105,35 L115,55 L125,35 L135,55 L145,35 L155,55 L165,35" 
        fill="none" stroke="#ed8936" stroke-width="4" stroke-linejoin="round" />
</svg>

## The Ultimate System Log Analysis Tool

SawLog is a powerful command-line utility designed to make system log analysis easier and more insightful. Built for system administrators, DevOps engineers, and power users, SawLog wraps around journalctl to provide enhanced log viewing, filtering, and analysis capabilities.

### ✨ Key Features

- **🔍 Interactive Search**: Easily find and explore logs across system and user services
- **🚦 Smart Filtering**: Filter logs by priority, time, or pattern with intuitive syntax
- **📊 Log Statistics**: Get instant insights with statistical analysis of log patterns
- **🚨 Monitoring**: Set up automated monitoring with configurable alerts
- **🔔 Notifications**: Desktop, email and custom notifications for critical events
- **📈 Trend Analysis**: Track error and warning patterns over time
- **🔖 Bookmarks**: Save and reuse common queries
- **📋 Export**: Share findings in various formats (HTML, CSV, Markdown)
- **🧰 System Health**: Generate comprehensive system health reports

## 📋 Installation

### Quick Install

```bash
git clone https://github.com/yourusername/sawlog.git
cd sawlog
./bin/sawlog --install
```

This will install SawLog to ~/.local/bin and set up all necessary configurations.

### Requirements

- Linux system with systemd/journald
- Bash 4.0+
- The following utilities:
  - journalctl (core dependency)
  - jq (for enhanced statistics)
  - bc (for calculations)
  - Optional: notify-send/zenity/kdialog (for desktop notifications)
  - Optional: smartctl (for disk health monitoring)

## 🚀 Usage Examples

### Basic Usage

```bash
# Show the last 50 lines of NetworkManager logs
sawlog NetworkManager

# Follow SSH daemon logs, showing only errors and critical messages
sawlog -f -p err,crit sshd

# Search for "error" in kernel logs from the last hour
sawlog -k -g error -t "1 hour ago"

# View logs from multiple services at once
sawlog -m "NetworkManager systemd"
```

### Advanced Features

```bash
# Analyze system log statistics
sawlog --stats

# Show potential problem areas that need attention
sawlog --attention

# Generate a system health report
sawlog --health-report system_health.md

# Set up the monitoring service
sawlog --setup-monitor

# View error and warning trends over the past 2 weeks
sawlog --trends 14
```

### Working with Bookmarks

```bash
# Save a query as a bookmark
sawlog --bookmark "network-errors" -p err -g "fail|disconnect" NetworkManager

# Use a saved bookmark
sawlog --use network-errors

# List all bookmarks
sawlog --bookmarks
```

## 🛠️ Configuration

SawLog stores its configuration in `~/.config/sawlog/`:

- `bookmarks.conf` - Saved log queries
- `theme.conf` - Visual customization settings
- `monitor.conf` - Monitoring service configuration
- `notification.conf` - Notification settings

## 🔍 Monitoring Setup

SawLog includes a powerful monitoring service that can continuously watch your logs for issues and alert you when problems occur:

```bash
# Set up the monitoring service
sawlog --setup-monitor

# Configure notification preferences
sawlog --configure-notifications

# Disable the monitoring service
sawlog --disable-monitor
```

The monitoring service can:
- Track error rates across services
- Monitor system health metrics (CPU, memory, disk usage)
- Detect failed services
- Send alerts via multiple channels

## 🔧 Customization

SawLog can be customized to your preferences by editing the configuration files in `~/.config/sawlog/`. The theme, monitoring thresholds, notification methods, and more can all be tailored to your needs.

## 📚 Complete Documentation

For full documentation of all commands and options:

```bash
sawlog --help
```

## 📝 License

MIT License - Feel free to use, modify and distribute as needed.

---

Built with ❤️ by system administrators, for system administrators.