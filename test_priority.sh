#!/usr/bin/env bash
# ==============================================================================
#  ⚡ Linux SSH & Interactive Terminal Priority Optimizer (Verification Suite)
# ==============================================================================
#  Author: adminsir-glich
#  Repository: https://github.com/adminsir-glich/linux-ssh-priority
#  License: MIT
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════════╗"
echo "  ║          ⚡ PRIORITY OPTIMIZER VERIFICATION & AUDIT SUITE         ║"
echo "  ╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

PASS=0
FAIL=0

check_val() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "  [✓] ${label}: ${GREEN}${BOLD}${actual}${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "  [✗] ${label}: ${RED}${BOLD}${actual}${NC} (Expected: ${expected})"
        FAIL=$((FAIL + 1))
    fi
}

echo -e "${BLUE}${BOLD}[1] Auditing SSH Daemon Process Priority & OOM Immunity...${NC}"
SSHD_PID=$(pgrep -f "sshd: /usr/sbin/sshd" | head -n 1 || pgrep -f "/usr/sbin/sshd" | head -n 1 || true)

if [ -n "$SSHD_PID" ]; then
    SSHD_NICE=$(ps -o ni= -p "$SSHD_PID" | tr -d ' ')
    SSHD_OOM=$(cat "/proc/${SSHD_PID}/oom_score_adj" 2>/dev/null || echo "N/A")
    check_val "sshd Nice Level" "-20" "$SSHD_NICE"
    check_val "sshd OOM Score Adjust (Immunity)" "-900" "$SSHD_OOM"
else
    echo -e "  ${YELLOW}[!] sshd main PID not found (listening via socket or active session)${NC}"
fi

echo -e "\n${BLUE}${BOLD}[2] Auditing Current Interactive Shell Priority...${NC}"
CURRENT_NICE=$(ps -o ni= -p $$ | tr -d ' ')
CURRENT_IONICE=$(ionice -p $$ 2>/dev/null || echo "N/A")
check_val "Current Shell Nice Level" "-10" "$CURRENT_NICE"
check_val "Current Shell I/O Scheduling" "prio 0" "$CURRENT_IONICE"

if [ -r "/proc/$$/autogroup" ]; then
    AUTOGROUP=$(cat "/proc/$$/autogroup" 2>/dev/null || echo "N/A")
    echo -e "  [✓] CFS Autogroup Isolation: ${GREEN}${BOLD}${AUTOGROUP}${NC}"
fi

echo -e "\n${BLUE}${BOLD}[3] Auditing Virtual Memory & Anti-Freeze I/O Throttling...${NC}"
check_val "vm.dirty_background_ratio" "3" "$(sysctl -n vm.dirty_background_ratio)"
check_val "vm.dirty_ratio" "6" "$(sysctl -n vm.dirty_ratio)"
check_val "vm.swappiness" "10" "$(sysctl -n vm.swappiness)"
check_val "vm.vfs_cache_pressure" "50" "$(sysctl -n vm.vfs_cache_pressure)"
check_val "vm.admin_reserve_kbytes" "65536" "$(sysctl -n vm.admin_reserve_kbytes)"
check_val "kernel.sched_autogroup_enabled" "1" "$(sysctl -n kernel.sched_autogroup_enabled)"

echo -e "\n${BLUE}${BOLD}[4] Auditing Network & TCP Congestion Control...${NC}"
check_val "TCP Congestion Control" "bbr" "$(sysctl -n net.ipv4.tcp_congestion_control)"
check_val "Default Queue Discipline" "fq" "$(sysctl -n net.core.default_qdisc)"

echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ✨ ALL AUDITS PASSED (${PASS}/${PASS}) - SYSTEM IS FULLY OPTIMIZED!${NC}"
else
    echo -e "${YELLOW}${BOLD}  ⚠️  Audit finished with ${PASS} passed and ${FAIL} warnings.${NC}"
fi
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
EOF
