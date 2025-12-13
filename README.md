# OptiMac-Intel

**CLI-based macOS optimization tool for Intel Macs**

A comprehensive command-line system optimization suite designed specifically for Intel-based MacBooks. This is the CLI version of the OptiMac application, offering powerful system tuning, maintenance, and monitoring capabilities through an interactive terminal interface.

## ⚠️ Important Notice

**This tool is designed exclusively for Intel-based Macs.** If you have an Apple Silicon Mac (M1/M2/M3), please use the appropriate version.

## Features

### 🚀 System Optimizations
- **Performance Tuning**: Optimize kernel parameters for improved system responsiveness
- **Memory Management**: Advanced memory optimization and purging
- **SSD Optimization**: TRIM support and hibernation management
- **Security Hardening**: Firewall configuration and system security enhancements

### 🌐 Network Optimizations
- **TCP/IP Stack Tuning**: Optimize network parameters for better throughput
- **DNS Management**: Fast DNS cache flushing
- **Firewall Control**: Easy firewall enable/disable functionality

### 💾 Storage Optimizations
- **Cache Clearing**: System and user cache cleanup
- **Language Files**: Remove unused language resources
- **Font Cache**: Rebuild and optimize font caches
- **Metadata Cleanup**: Remove .DS_Store files recursively

### ⚡ Performance Tweaks
- **Spotlight Control**: Disable/enable system indexing
- **Animation Removal**: Eliminate UI animations for faster response
- **Dashboard Management**: Disable legacy Dashboard
- **Dock Optimization**: Remove Dock animations

### 🔧 Maintenance Tools
- **Disk Permissions**: Verify and repair disk permissions
- **Maintenance Scripts**: Run daily/weekly/monthly maintenance
- **System Logs**: Clear old log files
- **SMC Reset**: Guided SMC reset instructions

### 🔋 Power Management
- **Power Settings**: Optimize sleep and wake behaviors
- **Low Power Mode**: Toggle power saving features
- **AutoBoot Control**: Manage automatic boot on lid open (Intel only)

### 📊 System Monitoring
- **CPU Information**: Detailed processor stats
- **Memory Status**: Real-time RAM usage
- **GPU Details**: Graphics card information
- **Battery Health**: Cycle count and battery condition
- **Disk Usage**: Storage space monitoring
- **Network Status**: Active network interfaces
- **Temperature Sensors**: Hardware temperature monitoring (requires iStats)

### 🎯 Advanced Features
- **Multi-Select Interface**: Choose multiple optimizations per section (e.g., `A,C` to run options A and C)
- **State Tracking**: Persistent logging of all optimizations with timestamps
- **MDM Detection**: Check for Mobile Device Management enrollment
- **Flexible Input**: Supports both comma-separated and space-separated selections

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/VonKleistL/OptiMac-Intel.git

# Navigate to the directory
cd OptiMac-Intel

# Make the script executable
chmod +x optimac.sh

# Run the optimizer
./optimac.sh
```

### System Requirements

- **macOS**: 10.13 High Sierra or later
- **Architecture**: Intel x86_64 only
- **Privileges**: Sudo access required for most optimizations
- **Shell**: Bash 3.2 or later (default on macOS)

## Usage

### Basic Usage

```bash
./optimac.sh
```

The script will present an interactive menu with the following sections:

1. **System Optimizations** - Core system performance tuning
2. **Network Optimizations** - Network stack enhancements
3. **Storage Optimizations** - Disk and cache management
4. **Performance Tweaks** - UI and system responsiveness
5. **Maintenance** - System maintenance tasks
6. **Power Management** - Battery and power settings
7. **Check System Status** - Comprehensive system information
8. **View All Optimization States** - Review optimization history
9. **Reset All Optimizations** - Clear optimization state tracking
10. **Check MDM Status** - Detect MDM enrollment

### Multi-Select Feature

When entering any optimization section, you can select multiple options using letters:

```
Select optimizations to run (e.g., A,C or A C):
A. Optimize System Performance
B. Optimize Memory Management
C. Optimize SSD Settings
D. Optimize Security
0. Cancel

Enter your selections: A,C
```

Supported input formats:
- `A,C` (comma-separated)
- `A C` (space-separated)
- `a c` (lowercase works too)
- `A, C` (mixed with spaces)

### Configuration File

Optimization states are tracked in `~/.macbook_optimizer_state.conf`

Format: `feature=status|timestamp`

Example:
```
system_performance=enabled|2025-12-13 13:45:22
memory_management=enabled|2025-12-13 13:45:35
ssd_optimization=failed|2025-12-13 13:46:10
```

## Examples

### Quick Performance Boost

1. Run the script: `./optimac.sh`
2. Select **4. Performance Tweaks**
3. Enter `A,B,C,D` to disable all animations and UI delays
4. Return to main menu and select **1. System Optimizations**
5. Enter `A,B` for performance and memory optimization

### Network Speed Enhancement

1. Run the script
2. Select **2. Network Optimizations**
3. Enter `A` to optimize TCP/IP settings
4. Select `C` to enable firewall if needed

### Complete System Cleanup

1. Run the script
2. Select **3. Storage Optimizations**
3. Enter `A,C,D` to clear caches and metadata
4. Select **5. Maintenance**
5. Enter `B,C` to run maintenance scripts and clear logs

### Battery Life Extension

1. Run the script
2. Select **6. Power Management**
3. Enter `A,B` to optimize power settings and enable low power mode

## Safety Features

- **State Tracking**: All operations logged with success/failure status
- **Reversible**: Many optimizations can be undone by re-running
- **Permission Checks**: Validates write access before operations
- **Confirmation**: Displays what will be executed before running
- **Error Handling**: Comprehensive error messages and recovery

## Troubleshooting

### Config File Permission Errors

If you encounter permission issues:

```bash
chmod 644 ~/.macbook_optimizer_state.conf
```

Or delete and recreate:

```bash
rm ~/.macbook_optimizer_state.conf
./optimac.sh  # Will recreate automatically
```

### Sudo Password Prompts

Most optimizations require admin privileges. You'll be prompted for your password when needed.

### Failed Optimizations

Check the status log:

```bash
cat ~/.macbook_optimizer_state.conf
```

View specific feature status in the script's menu option 8.

### Temperature Monitoring

If temperature monitoring fails, install iStats:

```bash
sudo gem install iStats
```

## Uninstallation

To remove all traces:

```bash
# Remove the configuration file
rm ~/.macbook_optimizer_state.conf

# Remove the script directory
cd .. && rm -rf OptiMac-Intel
```

Note: System changes made by optimizations will persist. To revert:
- Re-enable features (Spotlight, Dashboard, etc.) through System Preferences
- Restart your Mac to reset kernel parameters to defaults

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-optimization`)
3. Commit your changes (`git commit -m 'Add amazing optimization'`)
4. Push to the branch (`git push origin feature/amazing-optimization`)
5. Open a Pull Request

## Compatibility Notes

### Intel-Specific Features
- AutoBoot control (NVRAM-based)
- SMC reset procedures
- Some hardware-specific optimizations

### Not Compatible With
- Apple Silicon Macs (M1/M2/M3)
- macOS versions earlier than 10.13
- Non-Mac Unix systems

## Warnings

⚠️ **Use at your own risk**. While all optimizations are tested, system changes can have unintended effects.

⚠️ **Backup your data** before running aggressive optimizations.

⚠️ **Some optimizations require a restart** to take full effect.

⚠️ **MDM-enrolled devices** may have restrictions that prevent certain optimizations.

## Related Projects

- **OptiMac** - Full-featured GUI version for macOS
- **OptiMac-Silicon** - Optimized for Apple Silicon Macs

## License

MIT License - see [LICENSE](LICENSE) file for details

## Acknowledgments

Built with extensive research into macOS system internals and optimization techniques. Special thanks to the macOS developer community for documentation and best practices.

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the troubleshooting section

---

**Made with ❤️ for Intel Mac users who want maximum performance from their machines.**
