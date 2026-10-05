#!/usr/bin/env bash
# ==============================================================================
#  ⚡ Linux SSH & Interactive Terminal Priority Optimizer (Uninstaller)
# ==============================================================================
#  Author: adminsir-glich
#  Repository: https://github.com/adminsir-glich/linux-ssh-priority
#  License: MIT
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[ERROR] This uninstaller must be run as root (use sudo).${NC}" >&2
    exit 1
fi

echo -e "${YELLOW}[*] Reverting Linux SSH & Terminal Priority Optimizer configurations...${NC}"

# 1. Remove systemd overrides
rm -f /etc/systemd/system/ssh.service.d/priority.conf
rm -f /etc/systemd/system/sshd.service.d/priority.conf
rm -f /etc/systemd/system/ssh.socket.d/priority.conf
rm -f /etc/systemd/system/user-.slice.d/priority.conf

# Clean empty directories
rmdir /etc/systemd/system/ssh.service.d 2>/dev/null || true
rmdir /etc/systemd/system/sshd.service.d 2>/dev/null || true
rmdir /etc/systemd/system/ssh.socket.d 2>/dev/null || true
rmdir /etc/systemd/system/user-.slice.d 2>/dev/null || true

# 2. Remove sshd config
rm -f /etc/ssh/sshd_config.d/99-terminal-priority.conf

# 3. Remove PAM limits
rm -f /etc/security/limits.d/99-terminal-priority.conf

# 4. Remove profile script
rm -f /etc/profile.d/99-terminal-priority.sh

# 5. Remove sysctl rules
rm -f /etc/sysctl.d/99-system-priority.conf
rm -f /etc/modules-load.d/bbr.conf

# Reload systemd and SSH
systemctl daemon-reload
systemctl reload ssh.service 2>/dev/null || systemctl reload sshd.service 2>/dev/null || true

# Revert swappiness/sysctl to system defaults
sysctl -p /etc/sysctl.conf >/dev/null 2>&1 || true

echo -e "${GREEN}[✓] Uninstallation complete. System restored to default configurations.${NC}"
EOF
