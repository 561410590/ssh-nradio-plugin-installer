#!/bin/sh
# NRadio IPv4/IPv6 multi-WAN, V3.2.0 (2026-09-14).
# Reuse native WAN routing/NAT/health and the existing 0xff00 connmark mask.
MW_RUN=/var/run/nradio-multiwan
MW_HELPER=/usr/libexec/nradio-multiwan

mw_sections() {
    uci -q show "$1" 2>/dev/null | awk -F '[.=]' -v kind="$2" '$0 ~ "=" kind "$" {print $2}'
}

mw_name() {
    case "$1" in ''|*[!a-zA-Z0-9_]*) return 1 ;; esac
    [ "${#1}" -le 15 ]
}

mw_weight() {
    case "$1" in ''|*[!0-9]*|0*) return 1 ;; esac
    [ "${#1}" -le 4 ] && [ "$1" -le 1000 ]
}

mw_ipv4() {
    [ "$1" = '-' ] && return 0
    case "$1" in ''|*[!0-9./]*) return 1 ;; esac
    printf '%s\n' "$1" | awk '
        /^[0-9.]+(\/[0-9]+)?$/ {
            n=split($0,a,"/"); if(n>2 || (n==2 && (a[2]+0>32 || length(a[2])>2))) exit 1;
            if(split(a[1],b,".")!=4) exit 1;
            for(i=1;i<=4;i++) if(b[i]=="" || b[i]+0>255 || length(b[i])>3 || (length(b[i])>1 && substr(b[i],1,1)=="0")) exit 1;
            ok=1
        }
        END {if(!ok) exit 1}'
}

mw_ports() {
    [ "$1" = '-' ] && return 0
    case "$1" in ''|*[!0-9:]*) return 1 ;; esac
    printf '%s\n' "$1" | awk '
        /^[0-9]+(:[0-9]+)?$/ {
            n=split($0,a,":");
            for(i=1;i<=n;i++) if(length(a[i])>5 || a[i]+0<1 || a[i]+0>65535 || substr(a[i],1,1)=="0") exit 1;
            if(n==2 && a[1]+0>a[2]+0) exit 1; ok=1
        }
        END {if(!ok) exit 1}'
}

mw_ipv6() {
    [ "$1" = '-' ] && return 0
    case "$1" in ''|*[!0-9a-fA-F:/]*) return 1 ;; esac
    printf '%s\n' "$1" | awk '
        function groups(s, a,n,i) {
            if(s=="") return 0; n=split(s,a,":");
            for(i=1;i<=n;i++) if(length(a[i])<1 || length(a[i])>4) return -100;
            return n
        }
        {n=split($0,p,"/"); if(n>2 || (n==2 && (p[2]!~/^[0-9]+$/ || length(p[2])>3 || p[2]+0>128))) exit 1;
         s=p[1]; if(s!~/:/ || s~/:::/) exit 1;
         compressed=gsub(/::/,"X",s); if(compressed>1) exit 1;
         if(compressed) {split(s,a,"X"); l=groups(a[1]); r=groups(a[2]); ok=(l>=0 && r>=0 && l+r<8)}
         else ok=(groups(s)==8)
        } END {if(!ok) exit 1}'
}

mw_validate_rule() {
    case "${6:-4}" in
        4) mw_ipv4 "$1" && mw_ipv4 "$2" || return 1 ;;
        6) mw_ipv6 "$1" && mw_ipv6 "$2" || return 1 ;;
        *) return 1 ;;
    esac
    mw_ports "$4" && mw_name "$5" || return 1
    case "$3" in tcp|udp) ;; all) [ "$4" = '-' ] || return 1 ;; *) return 1 ;; esac
    # An all-destination/all-source/all-protocol rule would bypass balancing.
    [ "$1/$2/$3/$4" != '-/-/all/-' ]
}

# IDs are positions among ALL native interface sections, including IPv6.
mw_interfaces() {
    local wanted="${1:-all}" iface id=0 family enabled dev state data checker af
    for iface in $(mw_sections mwan3 interface); do
        id=$((id + 1))
        mw_name "$iface" || continue
        family=$(uci -q get "mwan3.$iface.family")
        enabled=$(uci -q get "mwan3.$iface.enabled")
        case "$family/$enabled" in ipv4/1) af=4 ;; ipv6/1) af=6 ;; *) continue ;; esac
        [ "$wanted" = all ] || [ "$af" = "$wanted" ] || continue
        [ "$id" -lt 253 ] || continue
        data=$(ifstatus "$iface" 2>/dev/null)
        dev=$(printf '%s' "$data" | jsonfilter -e '@.l3_device' 2>/dev/null)
        state=offline
        checker=$iface
        case "$iface" in cpe*_4) checker=${iface%_4} ;; esac
        if [ "$(printf '%s' "$data" | jsonfilter -e '@.up' 2>/dev/null)" = true ] &&
           [ "$(cat "/var/run/mwan3/iface_state/$iface" 2>/dev/null)" = online ] &&
           [ -n "$(ip -"$af" route show table "$id" default 2>/dev/null)" ]; then
            case "$(cat "/var/run/wanchk/iface_state/$checker" 2>/dev/null)" in
                down|failed|offline) ;;
                *) state=online ;;
            esac
        fi
        printf '%s|%s|%s|%s\n' "$iface" "$id" "${dev:--}" "$state"
    done
}

mw_snapshot() {
    local wanted="${1:-4}" selected iface row weight all seen=' ' family
    selected=$(uci -q get nradio_multiwan.main.interfaces)
    all=$(mw_interfaces "$wanted")
    for iface in $selected; do
        mw_name "$iface" || return 1
        case "$seen" in *" $iface "*) return 1 ;; esac
        seen="$seen$iface "
        row=$(printf '%s\n' "$all" | awk -F '|' -v name="$iface" '$1==name {print; exit}')
        if [ -z "$row" ]; then
            family=$(uci -q get "mwan3.$iface.family")
            case "$wanted/$family" in 4/ipv6|6/ipv4) continue ;; *) return 1 ;; esac
        fi
        weight=$(uci -q get "nradio_multiwan.l_$iface.weight")
        mw_weight "$weight" || return 1
        printf '%s|%s\n' "$row" "$weight"
    done
}

mw_rule_rows() {
    local wanted="${1:-4}" rule src dst proto ports iface family
    for rule in $(mw_sections nradio_multiwan rule); do
        mw_name "$rule" || return 1
        src=$(uci -q get "nradio_multiwan.$rule.src")
        dst=$(uci -q get "nradio_multiwan.$rule.dst")
        proto=$(uci -q get "nradio_multiwan.$rule.proto")
        ports=$(uci -q get "nradio_multiwan.$rule.ports")
        iface=$(uci -q get "nradio_multiwan.$rule.interface")
        case "$(uci -q get "mwan3.$iface.family")" in ipv6) family=6 ;; ipv4) family=4 ;; *) return 1 ;; esac
        [ "$family" = "$wanted" ] || continue
        mw_validate_rule "$src" "$dst" "$proto" "$ports" "$iface" "$family" || return 1
        printf '%s|%s|%s|%s|%s|%s\n' "$rule" "$src" "$dst" "$proto" "$ports" "$iface"
    done
}

# Build a staging chain. Conditional probability uses remaining selected weight,
# so three or more WANs keep the configured ratio as well as two WANs.
# MW_SNAPSHOT / MW_RULES contain validated data; this function is read-only.
mw_render() {
    local chain="$1" iface id dev state weight total probability rule src dst proto ports target mark
    total=$(printf '%s\n' "$MW_SNAPSHOT" | awk -F '|' '$4=="online" {n+=$5} END {print n+0}')
    printf '*mangle\n:%s - [0:0]\n-F %s\n' "$chain" "$chain"
    while IFS='|' read -r rule src dst proto ports target; do
        [ -n "$rule" ] || continue
        mark=$(printf '%s\n' "$MW_SNAPSHOT" | awk -F '|' -v name="$target" '$1==name && $4=="online" {printf "0x%x",$2*256; exit}')
        [ -n "$mark" ] || continue
        printf -- '-A %s -m mark --mark 0/0xff00' "$chain"
        [ "$src" = '-' ] || printf ' -s %s' "$src"
        [ "$dst" = '-' ] || printf ' -d %s' "$dst"
        [ "$proto" = all ] || printf ' -p %s' "$proto"
        [ "$ports" = '-' ] || printf ' -m %s --dport %s' "$proto" "$ports"
        printf ' -m comment --comment nr-mw-%s -j MARK --set-xmark %s/0xff00\n' "$rule" "$mark"
    done <<EOF_RULES
$MW_RULES
EOF_RULES
    while IFS='|' read -r iface id dev state weight; do
        [ "$state" = online ] || continue
        mark=$(printf '0x%x' "$((id * 256))")
        printf -- '-A %s -m mark --mark 0/0xff00' "$chain"
        if [ "$weight" -lt "$total" ]; then
            probability=$(awk -v w="$weight" -v t="$total" 'BEGIN {printf "%.10f",w/t}')
            printf ' -m statistic --mode random --probability %s' "$probability"
        fi
        printf ' -m comment --comment nr-mw-%s -j MARK --set-xmark %s/0xff00\n' "$iface" "$mark"
        total=$((total - weight))
    done <<EOF_LINES
$MW_SNAPSHOT
EOF_LINES
    # No selected WAN online: fail closed, instead of leaking to an unselected WAN.
    printf -- '-A %s -m mark --mark 0/0xff00 -j MARK --set-xmark 0xfe00/0xff00\n' "$chain"
}

mw_nat6_render() {
    local iface id dev state weight mark
    printf '*nat\n:nr_mw_n6 - [0:0]\n-F nr_mw_n6\n'
    while IFS='|' read -r iface id dev state weight; do
        [ "$state" = online ] || continue
        case "$dev" in ''|-|*[!a-zA-Z0-9_.:-]*) return 1 ;; esac
        mark=$(printf '0x%x' "$((id * 256))")
        printf -- '-A nr_mw_n6 -o %s -m mark --mark %s/0xff00 -j MASQUERADE\n' "$dev" "$mark"
    done <<EOF_NAT6
$MW_SNAPSHOT
EOF_NAT6
}

mw_remove_family() {
    local af="$1" ipt restore rules chain
    if [ "$af" = 6 ]; then ipt=ip6tables; restore=ip6tables-restore; else ipt=iptables; restore=iptables-restore; fi
    rules=$($ipt -w 5 -t mangle -S mwan3_rules 2>/dev/null)
    {
        printf '*mangle\n'
        printf '%s\n' "$rules" | awk '/^-A / && /--comment "?nr-multiwan"? / {sub(/^-A /,"-D "); print}'
        printf 'COMMIT\n'
    } | $restore -w 5 --noflush || return 1
    for chain in nr_mw_a nr_mw_b; do
        $ipt -w 5 -t mangle -F "$chain" 2>/dev/null || true
        $ipt -w 5 -t mangle -X "$chain" 2>/dev/null || true
    done
    if [ "$af" = 6 ]; then
        rules=$(ip6tables -w 5 -t nat -S POSTROUTING 2>/dev/null)
        {
            printf '*nat\n'
            printf '%s\n' "$rules" | awk '/^-A / && /--comment "?nr-multiwan6"? / {sub(/^-A /,"-D "); print}'
            printf 'COMMIT\n'
        } | ip6tables-restore -w 5 --noflush || return 1
        ip6tables -w 5 -t nat -F nr_mw_n6 2>/dev/null || true
        ip6tables -w 5 -t nat -X nr_mw_n6 2>/dev/null || true
    fi
    rm -f "$MW_RUN/signature$af" "$MW_RUN/lines$af"
}

mw_apply_family() {
    local af="$1" ipt restore default policy rules position target signature chain nat_rules
    if [ "$af" = 6 ]; then
        ipt=ip6tables; restore=ip6tables-restore; default=default_rule6; policy=mwan3_policy_net6_switch
    else
        ipt=iptables; restore=iptables-restore; default=default_rule; policy=mwan3_policy_net_switch
    fi
    MW_SNAPSHOT=$(mw_snapshot "$af") || return 1
    if [ -z "$MW_SNAPSHOT" ]; then
        [ ! -f "$MW_RUN/signature$af" ] || mw_remove_family "$af"
        return 0
    fi
    MW_RULES=$(mw_rule_rows "$af") || return 1
    rules=$($ipt -w 5 -t mangle -S mwan3_rules 2>/dev/null) || return 1
    position=$(printf '%s\n' "$rules" | awk -v rule="$default" -v policy="$policy" '
        /^-A / && !/--comment "?nr-multiwan"? / {n++; if($0 ~ "--comment \"?" rule "\"? " && $NF==policy) {print n; exit}}')
    [ -n "$position" ] || return 1
    target=$(printf '%s\n' "$rules" | awk '/--comment "?nr-multiwan"? / {print $NF; exit}')
    signature=$(printf '%s\n%s\n%s\n' "$MW_SNAPSHOT" "$MW_RULES" "$position")
    if [ "$signature" = "$(cat "$MW_RUN/signature$af" 2>/dev/null)" ] &&
       $ipt -w 5 -t mangle -C mwan3_rules -m mark --mark 0/0xff00 -m comment --comment nr-multiwan -j "$target" 2>/dev/null &&
       $ipt -w 5 -t mangle -C "$target" -m mark --mark 0/0xff00 -j MARK --set-xmark 0xfe00/0xff00 2>/dev/null; then
        if [ "$af" = 4 ] || ip6tables -w 5 -t nat -C POSTROUTING -m comment --comment nr-multiwan6 -j nr_mw_n6 2>/dev/null; then
            return 0
        fi
    fi
    case "$target" in nr_mw_a) chain=nr_mw_b ;; *) chain=nr_mw_a ;; esac
    {
        mw_render "$chain"
        printf '%s\n' "$rules" | awk '/^-A / && /--comment "?nr-multiwan"? / {sub(/^-A /,"-D "); print}'
        printf -- '-I mwan3_rules %s -m mark --mark 0/0xff00 -m comment --comment nr-multiwan -j %s\nCOMMIT\n' "$position" "$chain"
    } >"$MW_RUN/rules$af.next" || return 1
    # Validate both tables before switching the IPv6 classifier.
    $restore -w 5 --test --noflush <"$MW_RUN/rules$af.next" || return 1
    if [ "$af" = 6 ]; then
        nat_rules=$(ip6tables -w 5 -t nat -S POSTROUTING) || return 1
        {
            mw_nat6_render
            printf '%s\n' "$nat_rules" | awk '/^-A / && /--comment "?nr-multiwan6"? / {sub(/^-A /,"-D "); print}'
            printf -- '-I POSTROUTING 1 -m comment --comment nr-multiwan6 -j nr_mw_n6\nCOMMIT\n'
        } >"$MW_RUN/nat6.next" || return 1
        ip6tables-restore -w 5 --test --noflush <"$MW_RUN/nat6.next" || return 1
        ip6tables-restore -w 5 --noflush <"$MW_RUN/nat6.next" || return 1
    fi
    $restore -w 5 --noflush <"$MW_RUN/rules$af.next" || return 1
    printf '%s\n' "$signature" >"$MW_RUN/signature$af"
    printf '%s\n' "$MW_SNAPSHOT" >"$MW_RUN/lines$af"
    logger -t nr-multiwan "IPv$af policy refreshed: $(printf '%s\n' "$MW_SNAPSHOT" | tr '\n' ' ')"
}

mw_apply() (
    mkdir -p "$MW_RUN" || exit 1
    exec 9>"$MW_RUN/lock"
    flock -w 10 9 || exit 1
    [ "$(uci -q get nradio_multiwan.main.enabled)" = 1 ] || exit 0
    result=0
    for af in 4 6; do
        mw_apply_family "$af" || { logger -t nr-multiwan "IPv$af policy apply failed"; result=1; }
    done
    exit "$result"
)

mw_stop() (
    mkdir -p "$MW_RUN" || exit 1
    exec 9>"$MW_RUN/lock"
    flock -w 10 9 || exit 1
    result=0
    for af in 4 6; do mw_remove_family "$af" || result=1; done
    rm -f "$MW_RUN/signature" "$MW_RUN/lines"
    exit "$result"
)

mw_connections() {
    local family="${1:-4}"
    if [ -r /proc/net/nf_conntrack ]; then
        cat /proc/net/nf_conntrack
    elif command -v conntrack >/dev/null 2>&1; then
        conntrack -L -f "ipv$family" 2>/dev/null
    fi | awk -v family="$family" '
        {for(i=1;i<=NF;i++) if($i ~ /^src=/) {is6=index($i,":")>0; break}; if((family==6)!=is6) next}
        {for(i=1;i<=NF;i++) if($i ~ /^mark=[0-9]+$/) {split($i,a,"="); id=int(a[2]/256)%256; count[id]++; break}}
        END {for(id in count) print id,count[id]}'
}

mw_status() {
    local af snapshot counts iface id dev state weight count total share enabled running ipt
    enabled=$(uci -q get nradio_multiwan.main.enabled)
    case "$enabled" in 1) enabled=已启用 ;; *) enabled=已停用 ;; esac
    running=$(ubus call service list '{"name":"nradio-multiwan"}' 2>/dev/null | jsonfilter -e '@["nradio-multiwan"].instances.*.running' 2>/dev/null)
    case "$running" in *true*) running=运行中 ;; *) running=未运行 ;; esac
    printf 'IPv4/IPv6 多线叠加：%s / 后台：%s\n' "$enabled" "$running"
    for af in 4 6; do
    snapshot=$(mw_snapshot "$af") || return 1
    counts=$(mw_connections "$af")
    printf 'IPv%s：\n' "$af"
    total=$(printf '%s\n' "$snapshot" | awk -F '|' '$4=="online" {n+=$5} END {print n+0}')
    printf '接口 | 状态 | 权重 | 新连接目标占比 | 当前连接数 | 设备\n'
    while IFS='|' read -r iface id dev state weight; do
        [ -n "$iface" ] || continue
        count=$(printf '%s\n' "$counts" | awk -v id="$id" '$1==id {n=$2} END {print n+0}')
        share=0
        [ "$state" != online ] || share=$(awk -v w="$weight" -v t="$total" 'BEGIN {if(t>0) printf "%.1f",100*w/t; else print 0}')
        printf '%s | %s | %s | %s%% | %s | %s\n' "$iface" "$state" "$weight" "$share" "$count" "$dev"
    done <<EOF_STATUS
$snapshot
EOF_STATUS
    printf '固定出口规则（编号|源地址|目的地址|协议|目的端口|出口）：\n'
    mw_rule_rows "$af"
    if [ "$af" = 6 ]; then ipt=ip6tables; else ipt=iptables; fi
    $ipt -w 5 -t mangle -S mwan3_rules 2>/dev/null | grep -- '--comment nr-multiwan\|--comment "nr-multiwan"' || true
    done
}

mw_rates() (
    seconds=${1:-5}
    case "$seconds" in 1|2|3|4|5|10|30) ;; *) exit 1 ;; esac
    snapshot=$( { mw_snapshot 4; mw_snapshot 6; } | awk -F '|' '!seen[$3]++') || exit 1
    printf '物理线路总速率（IPv4 + IPv6，设备去重）：\n'
    counters() {
        printf '%s\n' "$snapshot" | while IFS='|' read -r iface id dev state weight; do
            [ -n "$iface" ] && [ -r "/sys/class/net/$dev/statistics/rx_bytes" ] || continue
            printf '%s %s %s\n' "$iface" "$(cat "/sys/class/net/$dev/statistics/rx_bytes")" "$(cat "/sys/class/net/$dev/statistics/tx_bytes")"
        done
    }
    before=$(counters)
    start=$(cut -d ' ' -f 1 /proc/uptime)
    sleep "$seconds"
    after=$(counters)
    end=$(cut -d ' ' -f 1 /proc/uptime)
    printf '%s\n--\n%s\n' "$before" "$after" | awk -v elapsed="$(awk -v a="$start" -v b="$end" 'BEGIN {print b-a}')" '
        $0=="--" {second=1;next}
        !second {rx[$1]=$2;tx[$1]=$3;next}
        $1 in rx && elapsed>0 {r=$2-rx[$1];t=$3-tx[$1]; if(r<0 || t<0) {print $1,"计数器重置";next}
            printf "%s 下行 %.2f Mbps / 上行 %.2f Mbps\n",$1,r*8/elapsed/1000000,t*8/elapsed/1000000}'
)

case "${1:-status}" in
    list) mw_interfaces "${2:-all}" ;;
    validate-rule) shift; { [ "$#" = 5 ] || [ "$#" = 6 ]; } && mw_validate_rule "$@" ;;
    apply) mw_apply ;;
    stop) mw_stop ;;
    status) mw_status ;;
    rates) mw_rates "${2:-5}" ;;
    daemon)
        while :; do
            mw_apply || logger -t nr-multiwan 'Waiting for valid configuration/native IPv4/IPv6 routing'
            sleep 5
        done
        ;;
    *) printf 'Usage: %s list|apply|stop|status|rates|daemon\n' "$0" >&2; exit 1 ;;
esac
