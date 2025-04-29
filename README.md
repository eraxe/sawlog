# 🪵 SawLog - Advanced System Log Explorer

<svg width="240" height="240" viewBox="0 0 240 240" xmlns="http://www.w3.org/2000/svg">
  <!-- Background circle -->
  <circle cx="120" cy="120" r="110" fill="#2d3748" />
  
  <!-- Outer ring -->
  <circle cx="120" cy="120" r="105" fill="none" stroke="#48bb78" stroke-width="4" />
  
  <!-- Log lines -->
  <g transform="translate(60, 75)">
    <!-- Log line 1 -->
    <rect x="0" y="0" width="120" height="12" rx="2" fill="#f56565" />
    <rect x="0" y="0" width="30" height="12" rx="2" fill="#805ad5" />
    
    <!-- Log line 2 -->
    <rect x="0" y="22" width="100" height="12" rx="2" fill="#4299e1" />
    <rect x="0" y="22" width="30" height="12" rx="2" fill="#805ad5" />
    
    <!-- Log line 3 -->
    <rect x="0" y="44" width="140" height="12" rx="2" fill="#ecc94b" />
    <rect x="0" y="44" width="30" height="12" rx="2" fill="#805ad5" />
    
    <!-- Log line 4 -->
    <rect x="0" y="66" width="110" height="12" rx="2" fill="#48bb78" />
    <rect x="0" y="66" width="30" height="12" rx="2" fill="#805ad5" />
  </g>
  
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