#!/bin/bash
# ============================================================
# 用法:
#   首次运行: bash netspeed.sh [网卡名]
#   实时监控: watch -n 1 bash netspeed.sh [网卡名]
#   不填网卡名则自动获取默认网卡
# ============================================================

IFACE=${1:-$(ip route 2>/dev/null | awk '/default/{print $5; exit}')}
TMPFILE="/tmp/.netspeed_${IFACE}"

# ---------- 检查网卡是否存在 ----------
if [ ! -d "/sys/class/net/$IFACE" ]; then
    echo "❌ 网卡 [$IFACE] 不存在！"
    echo ""
    echo "可用网卡:"
    ls /sys/class/net/ | grep -v lo | while read i; do
        STATE=$(cat /sys/class/net/$i/operstate 2>/dev/null)
        echo "  - $i  ($STATE)"
    done
    exit 1
fi

# ---------- 读取当前统计值 ----------
RX_BYTES=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX_BYTES=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
RX_PKTS=$(cat  /sys/class/net/$IFACE/statistics/rx_packets)
TX_PKTS=$(cat  /sys/class/net/$IFACE/statistics/tx_packets)
RX_DROP=$(cat  /sys/class/net/$IFACE/statistics/rx_dropped)
TX_DROP=$(cat  /sys/class/net/$IFACE/statistics/tx_dropped)
RX_ERR=$(cat   /sys/class/net/$IFACE/statistics/rx_errors)
TX_ERR=$(cat   /sys/class/net/$IFACE/statistics/tx_errors)
TIME_NOW=$(date +%s%3N)   # 毫秒时间戳

# ---------- 格式化速率 ----------
format_speed() {
    local bps=$1
    if   [ "$bps" -ge 1073741824 ]; then echo "$(( bps / 1073741824 )) GB/s"
    elif [ "$bps" -ge 1048576    ]; then echo "$(( bps / 1048576    )) MB/s"
    elif [ "$bps" -ge 1024       ]; then echo "$(( bps / 1024       )) KB/s"
    else                                  echo "${bps} B/s"
    fi
}

# ---------- 格式化累计流量 ----------
format_bytes() {
    local bytes=$1
    if   [ "$bytes" -ge 1073741824 ]; then echo "$(( bytes / 1073741824 )) GB"
    elif [ "$bytes" -ge 1048576    ]; then echo "$(( bytes / 1048576    )) MB"
    elif [ "$bytes" -ge 1024       ]; then echo "$(( bytes / 1024       )) KB"
    else                                    echo "${bytes} B"
    fi
}

# ---------- 计算速率（依赖上次保存的值）----------
if [ -f "$TMPFILE" ]; then
    read RX_PREV TX_PREV RX_PKTS_PREV TX_PKTS_PREV TIME_PREV < "$TMPFILE"
    TIME_DIFF=$(( TIME_NOW - TIME_PREV ))   # 毫秒

    if [ "$TIME_DIFF" -gt 0 ]; then
        RX_RATE=$(( (RX_BYTES - RX_PREV) * 1000 / TIME_DIFF ))
        TX_RATE=$(( (TX_BYTES - TX_PREV) * 1000 / TIME_DIFF ))
        RX_PPS=$((  (RX_PKTS  - RX_PKTS_PREV)  * 1000 / TIME_DIFF ))
        TX_PPS=$((  (TX_PKTS  - TX_PKTS_PREV)  * 1000 / TIME_DIFF ))
    else
        RX_RATE=0; TX_RATE=0; RX_PPS=0; TX_PPS=0
    fi

    STATE=$(cat /sys/class/net/$IFACE/operstate 2>/dev/null)
    SPEED=$(cat /sys/class/net/$IFACE/speed 2>/dev/null || echo "N/A")

    echo "╔══════════════════════════════════════════╗"
    printf "║  网卡: %-10s  状态: %-8s  %s  ║\n" \
        "$IFACE" "$STATE" "$(date '+%H:%M:%S')"
    [ "$SPEED" != "N/A" ] && \
    printf "║  链路速率: %-30s  ║\n" "${SPEED} Mbps"
    echo "╠══════════════════════════════════════════╣"
    printf "║  ↓ 接收: %-12s  %6d pps       ║\n" "$(format_speed $RX_RATE)" "$RX_PPS"
    printf "║  ↑ 发送: %-12s  %6d pps       ║\n" "$(format_speed $TX_RATE)" "$TX_PPS"
    echo "╠══════════════════════════════════════════╣"
    printf "║  累计接收: %-10s  %10d 包   ║\n" "$(format_bytes $RX_BYTES)" "$RX_PKTS"
    printf "║  累计发送: %-10s  %10d 包   ║\n" "$(format_bytes $TX_BYTES)" "$TX_PKTS"
    echo "╠══════════════════════════════════════════╣"
    printf "║  RX 错误/丢包: %-5d / %-5d             ║\n" "$RX_ERR" "$RX_DROP"
    printf "║  TX 错误/丢包: %-5d / %-5d             ║\n" "$TX_ERR" "$TX_DROP"
    echo "╚══════════════════════════════════════════╝"

else
    echo "⏳ 初始化中，1 秒后显示速率..."
fi

# ---------- 保存本次值供下次计算 ----------
echo "$RX_BYTES $TX_BYTES $RX_PKTS $TX_PKTS $TIME_NOW" > "$TMPFILE"
