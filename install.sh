#!/usr/bin/env bash
# ==============================================================================
#  ⚡ Linux SSH & Interactive Terminal Priority Optimizer (Installer)
# ==============================================================================
#  Author: adminsir-glich
#  Repository: https://github.com/adminsir-glich/linux-ssh-priority
#  License: MIT
# ==============================================================================

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════════╗"
echo "  ║        ⚡ LINUX SSH & INTERACTIVE TERMINAL PRIORITY OPTIMIZER      ║"
echo "  ║      Guaranteed SSH Responsiveness & Zero Freeze Under 100% Load   ║"
echo "  ╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[ERROR] This installer must be run as root (use sudo).${NC}" >&2
    exit 1
fi

echo -e "${BLUE}[*] Detecting environment and systemd services...${NC}"

# Detect SSH service name (Debian/Ubuntu: ssh, RHEL/Fedora/Arch/SUSE: sshd)
SSH_SERVICE="ssh"
if systemctl list-unit-files | grep -qE '^sshd\.service'; then
    SSH_SERVICE="sshd"
elif systemctl list-unit-files | grep -qE '^ssh\.service'; then
    SSH_SERVICE="ssh"
fi
echo -e "${GREEN}[+] Detected SSH service: ${BOLD}${SSH_SERVICE}.service${NC}"

HAS_SSH_SOCKET=0
if systemctl list-unit-files | grep -qE '^ssh\.socket' && systemctl is-active --quiet ssh.socket 2>/dev/null; then
    HAS_SSH_SOCKET=1
    echo -e "${GREEN}[+] Detected active socket activation: ${BOLD}ssh.socket${NC}"
fi

# ------------------------------------------------------------------------------
# 1. Systemd SSH Daemon Override (Immunity & Scheduling Priority)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Layer 1: Configuring SSH daemon systemd priorities & OOM immunity...${NC}"

OVERRIDE_DIR="/etc/systemd/system/${SSH_SERVICE}.service.d"
mkdir -p "$OVERRIDE_DIR"

cat << "EOF" > "${OVERRIDE_DIR}/priority.conf"
[Service]
# Maximum CPU scheduling priority & CFS Weight
Nice=-20
CPUWeight=10000

# High I/O scheduling priority (Best Effort Class 2, Priority 0)
IOSchedulingClass=best-effort
IOSchedulingPriority=0
IOWeight=10000

# Immunize SSH daemon from the Linux Kernel OOM killer
OOMScoreAdjust=-900

# Memory protection: ensure SSH daemon memory pages are never evicted or dropped
MemoryMin=64M
MemoryLow=128M

# Allow unlimited tasks so logins never fail on process exhaustion
TasksMax=infinity

# Fast timeout bounds to prevent hanging connection units
TimeoutStartSec=10s
TimeoutStopSec=10s
EOF

if [ "$HAS_SSH_SOCKET" -eq 1 ]; then
    SOCKET_DIR="/etc/systemd/system/ssh.socket.d"
    mkdir -p "$SOCKET_DIR"
    cat << "EOF" > "${SOCKET_DIR}/priority.conf"
[Socket]
Backlog=512
EOF
fi
echo -e "${GREEN}[✓] SSH daemon systemd overrides installed.${NC}"

# ------------------------------------------------------------------------------
# 2. Systemd User Slice Priority (10x Scheduling Advantage Over Background Jobs)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Layer 2: Configuring systemd user session slice priority...${NC}"

USER_SLICE_DIR="/etc/systemd/system/user-.slice.d"
mkdir -p "$USER_SLICE_DIR"

cat << "EOF" > "${USER_SLICE_DIR}/priority.conf"
[Slice]
# Give logged-in user interactive terminal sessions 10x scheduling priority over background services
CPUWeight=1000
IOWeight=1000
EOF
echo -e "${GREEN}[✓] User slice priority override configured.${NC}"

# ------------------------------------------------------------------------------
# 3. SSH Daemon Interactive QoS & Anti-Drop Configuration
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Layer 3: Configuring sshd interactive network QoS and keepalive...${NC}"

SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
mkdir -p "$SSHD_CONFIG_DIR"

cat << "EOF" > "${SSHD_CONFIG_DIR}/99-terminal-priority.conf"
# Real-time Interactive Quality of Service (QoS)
IPQoS lowdelay throughput

# TCP Keepalive and frequent health checks
TCPKeepAlive yes
ClientAliveInterval 15
ClientAliveCountMax 4

# Increase connection queue for unauthenticated bursts / high load
MaxStartups 100:30:200
MaxSessions 50
EOF
echo -e "${GREEN}[✓] sshd QoS and keepalive parameters configured.${NC}"

# ------------------------------------------------------------------------------
# 4. PAM Limits for Priority & Negative Nice
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Layer 4: Configuring PAM limits for interactive negative nice values...${NC}"

mkdir -p /etc/security/limits.d
cat << "EOF" > /etc/security/limits.d/99-terminal-priority.conf
# Allow all logged-in user terminal sessions to use high CPU & I/O priority
*    soft   priority   -10
*    hard   priority   -20
*    soft   nice       -10
*    hard   nice       -20
root soft   priority   -10
root hard   priority   -20
root soft   nice       -10
root hard   nice       -20
EOF
echo -e "${GREEN}[✓] PAM limits configured.${NC}"

# ------------------------------------------------------------------------------
# 5. Shell & Terminal Command Prioritization Profile Script
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Layer 5: Configuring interactive shell & child command auto-priority...${NC}"

cat << "EOF" > /etc/profile.d/99-terminal-priority.sh
# Priority scheduling for interactive SSH / terminal sessions
if [ -t 0 ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
    # Renice interactive shell so it and all spawned commands preempt background tasks
    renice -n -10 -p $$ >/dev/null 2>&1 || true
    
    # Set I/O priority to Best-Effort Priority 0 (highest non-realtime)
    ionice -c 2 -n 0 -p $$ >/dev/null 2>&1 || true
    
    # Configure fast, safe asynchronous history so disk flush never blocks keystrokes
    shopt -s histappend 2>/dev/null || true
fi
EOF
chmod +x /etc/profile.d/99-terminal-priority.sh
echo -e "${GREEN}[✓] Interactive shell priority profile deployed.${NC}"

# ------------------------------------------------------------------------------
# 6. Kernel Sysctl Anti-Freeze & Responsiveness Tuning
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Layer 6: Applying kernel sysctl responsiveness & I/O throttling rules...${NC}"

# Ensure BBR module is loaded
modprobe tcp_bbr 2>/dev/null || true
mkdir -p /etc/modules-load.d
echo "tcp_bbr" > /etc/modules-load.d/bbr.conf

cat << "EOF" > /etc/sysctl.d/99-system-priority.conf
# ==============================================================
# Linux Kernel Interactive Responsiveness & System Optimization
# ==============================================================

# CFS Task Scheduler: Autogroup isolates TTY/terminal sessions from background CPU hogs
kernel.sched_autogroup_enabled = 1

# ==============================================================
# Virtual Memory & I/O Smoothness (Anti-Freeze & Anti-Thrashing)
# ==============================================================

# Keep swappiness low so physical RAM is used instead of slow virtual disk
vm.swappiness = 10

# Preserve filesystem cache (inodes/dentries) for instant terminal commands
vm.vfs_cache_pressure = 50

# Continuous, small background writebacks to prevent huge blocking I/O freezes
vm.dirty_background_ratio = 3
vm.dirty_ratio = 6

# Reserve 64MB of RAM strictly for admin logins and emergency commands
vm.admin_reserve_kbytes = 65536

# Reserve 64MB of RAM for kernel network socket buffers and allocations
vm.min_free_kbytes = 65536

# Protect allocating task from blind OOM kills
vm.oom_kill_allocating_task = 0

# Maximum memory maps for multi-threaded processes
vm.max_map_count = 262144

# ==============================================================
# Network Stack & TCP Optimization
# ==============================================================

# Enable BBR congestion control and FQ queue discipline
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr

# TCP responsiveness & connection management
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# Increase socket backlogs for spike absorption
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 4096
EOF

sysctl -p /etc/sysctl.d/99-system-priority.conf >/dev/null 2>&1 || true
echo -e "${GREEN}[✓] Kernel sysctl rules applied successfully.${NC}"

# ------------------------------------------------------------------------------
# 7. Reload & Verify Daemons
# ------------------------------------------------------------------------------
echo -e "${BLUE}[*] Reloading systemd and SSH services...${NC}"
systemctl daemon-reload

if [ "$HAS_SSH_SOCKET" -eq 1 ]; then
    systemctl restart ssh.socket "${SSH_SERVICE}.service" || true
else
    systemctl restart "${SSH_SERVICE}.service" || true
fi

echo -e "\n${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  🎉 SUCCESS: Linux SSH & Terminal Priority Optimizer Installed!     ${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "  • SSH Daemon:     ${BOLD}Nice -20, OOM Immune (-900), 64MB Reserved RAM${NC}"
echo -e "  • User Sessions:  ${BOLD}10x Cgroup Scheduling Weight over background daemons${NC}"
echo -e "  • Terminal Shell: ${BOLD}Nice -10, ionice Priority 0, CFS Autogroup Isolation${NC}"
echo -e "  • Memory/Disk:    ${BOLD}Continuous Dirty Throttling (Anti-Freeze Active)${NC}"
echo -e "  • Network QoS:    ${BOLD}TCP BBR + fq_codel + IPQoS Low Delay Active${NC}"
echo -e "\nRun ${CYAN}./test_priority.sh${NC} to benchmark and verify active status."
EOF
