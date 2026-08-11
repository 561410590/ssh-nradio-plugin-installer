#!/bin/sh
# NRadio 智能频段切换 v5 - 联网健康优先，频段仅作决策参考
LOG_TAG="nradio-band"
STATE_FILE="/tmp/nradio_band_state"
LOCK_DIR="/tmp/nradio-smart-band.lock"
RUNTIME_LOG="/tmp/nradio-smart-band.log"
MIN_BW=20000
MAX_RETRIES=1
COOLDOWN=43200
RETRY_WINDOW=86400
HEALTH_FAILURE_LIMIT=3
HEALTH_PROBE_COUNT=2
HEALTH_PROBE_TIMEOUT=2
HEALTH_TARGET_1="223.5.5.5"
HEALTH_TARGET_2="119.29.29.29"
SOFT_RECOVERY_WAIT=20
IPV4_RECOVERY_WAIT=180
IPV6_RECOVERY_WAIT=60
IPV6_RECOVERY_COOLDOWN=21600
DAY_START=5
DAY_END=22

TMP_FILE=""
BAND_STATUS="unknown"
BAND_REASON="unknown"
BAND_KEY="unknown"
RETRY_COUNT=0
RETRY_WINDOW_START=0
RETRY_BLOCK_REASON=""
OBS_PREVIOUS_BAND=""
OBS_SINCE=0
OBS_COUNT=0
HEALTH_STATUS="unknown"
HEALTH_REASON="not-checked"
ACTIVE_DEVICE=""
OPERATOR_NAME="unknown"
OPERATOR_PROFILE="unknown"
IPV6_STATUS="unknown"
EXEC_MODE="apply"

log() {
    local _line _size _log_tmp
    _line="$(date '+%Y-%m-%d %H:%M:%S') $1"
    logger -t "$LOG_TAG" "$1"
    printf '%s\n' "$_line" >> "$RUNTIME_LOG"
    _size="$(wc -c < "$RUNTIME_LOG" 2>/dev/null || echo 0)"
    if is_uint "$_size" && [ "$_size" -gt 65536 ]; then
        _log_tmp="${RUNTIME_LOG}.tmp.$$"
        tail -n 240 "$RUNTIME_LOG" > "$_log_tmp" 2>/dev/null || true
        mv "$_log_tmp" "$RUNTIME_LOG"
    fi
    echo "$_line"
}

is_uint() {
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

state_get() {
    local _iface="$1" _key="$2"
    [ -f "$STATE_FILE" ] || return 0
    grep "^${_iface}_${_key}=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2 | head -n 1
}

state_has() {
    local _iface="$1"
    [ -f "$STATE_FILE" ] && grep -q "^${_iface}_" "$STATE_FILE" 2>/dev/null
}

state_clear() {
    local _iface="$1"
    state_has "$_iface" || return 0

    TMP_FILE="${STATE_FILE}.tmp.$$"
    grep -v "^${_iface}_" "$STATE_FILE" > "$TMP_FILE" 2>/dev/null || true
    mv "$TMP_FILE" "$STATE_FILE"
    TMP_FILE=""
}

state_write() {
    local _iface="$1" _count="$2" _last="$3" _window="$4" _band="$5" _since="$6" _samples="$7" _failures="$8" _ipv6_last="$9"

    TMP_FILE="${STATE_FILE}.tmp.$$"
    if [ -f "$STATE_FILE" ]; then
        grep -v "^${_iface}_" "$STATE_FILE" 2>/dev/null | grep -v '^format=' > "$TMP_FILE" 2>/dev/null || true
    else
        : > "$TMP_FILE"
    fi
    printf '%s\n' \
        "format=5" \
        "${_iface}_c=${_count}" \
        "${_iface}_t=${_last}" \
        "${_iface}_w=${_window}" \
        "${_iface}_b=${_band}" \
        "${_iface}_s=${_since}" \
        "${_iface}_n=${_samples}" \
        "${_iface}_f=${_failures}" \
        "${_iface}_v=${_ipv6_last}" >> "$TMP_FILE"
    mv "$TMP_FILE" "$STATE_FILE"
    TMP_FILE=""
}

state_write_retry() {
    local _iface="$1" _count="$2" _last="$3" _window="$4" _failures="${5:-0}" _band _since _samples _ipv6_last

    _band="$(state_get "$_iface" b)"
    _since="$(state_get "$_iface" s)"
    _samples="$(state_get "$_iface" n)"
    _ipv6_last="$(state_get "$_iface" v)"
    [ -n "$_band" ] || _band="$BAND_KEY"
    is_uint "$_since" || _since="$(date +%s)"
    is_uint "$_samples" || _samples=1
    is_uint "$_failures" || _failures=0
    is_uint "$_ipv6_last" || _ipv6_last=0
    state_write "$_iface" "$_count" "$_last" "$_window" "$_band" "$_since" "$_samples" "$_failures" "$_ipv6_last"
}

record_band_observation() {
    local _iface="$1" _now _count _last _window _previous _since _samples _failures _ipv6_last

    _now="$(date +%s)"
    _count="$(state_get "$_iface" c)"
    _last="$(state_get "$_iface" t)"
    _window="$(state_get "$_iface" w)"
    _previous="$(state_get "$_iface" b)"
    _since="$(state_get "$_iface" s)"
    _samples="$(state_get "$_iface" n)"
    _failures="$(state_get "$_iface" f)"
    _ipv6_last="$(state_get "$_iface" v)"

    is_uint "$_count" || _count=0
    is_uint "$_last" || _last=0
    is_uint "$_window" || _window="$_now"
    is_uint "$_failures" || _failures=0
    is_uint "$_ipv6_last" || _ipv6_last=0
    OBS_PREVIOUS_BAND="$_previous"

    if [ "$_previous" = "$BAND_KEY" ] && is_uint "$_since" && is_uint "$_samples"; then
        if [ "$_now" -lt "$_since" ]; then
            _since="$_now"
            _samples=1
        else
            _samples=$((_samples + 1))
        fi
    else
        _since="$_now"
        _samples=1
    fi

    OBS_SINCE="$_since"
    OBS_COUNT="$_samples"
    state_write "$_iface" "$_count" "$_last" "$_window" "$BAND_KEY" "$_since" "$_samples" "$_failures" "$_ipv6_last"
}

state_set_health_failures() {
    local _iface="$1" _failures="$2" _now _count _last _window _band _since _samples _ipv6_last
    _now="$(date +%s)"
    _count="$(state_get "$_iface" c)"
    _last="$(state_get "$_iface" t)"
    _window="$(state_get "$_iface" w)"
    _band="$(state_get "$_iface" b)"
    _since="$(state_get "$_iface" s)"
    _samples="$(state_get "$_iface" n)"
    _ipv6_last="$(state_get "$_iface" v)"
    is_uint "$_count" || _count=0
    is_uint "$_last" || _last=0
    is_uint "$_window" || _window="$_now"
    [ -n "$_band" ] || _band="$BAND_KEY"
    is_uint "$_since" || _since="$_now"
    is_uint "$_samples" || _samples=1
    is_uint "$_failures" || _failures=0
    is_uint "$_ipv6_last" || _ipv6_last=0
    state_write "$_iface" "$_count" "$_last" "$_window" "$_band" "$_since" "$_samples" "$_failures" "$_ipv6_last"
}

state_set_ipv6_last() {
    local _iface="$1" _ipv6_last="$2" _now _count _last _window _band _since _samples _failures
    _now="$(date +%s)"
    _count="$(state_get "$_iface" c)"
    _last="$(state_get "$_iface" t)"
    _window="$(state_get "$_iface" w)"
    _band="$(state_get "$_iface" b)"
    _since="$(state_get "$_iface" s)"
    _samples="$(state_get "$_iface" n)"
    _failures="$(state_get "$_iface" f)"
    is_uint "$_count" || _count=0
    is_uint "$_last" || _last=0
    is_uint "$_window" || _window="$_now"
    [ -n "$_band" ] || _band="$BAND_KEY"
    is_uint "$_since" || _since="$_now"
    is_uint "$_samples" || _samples=1
    is_uint "$_failures" || _failures=0
    is_uint "$_ipv6_last" || _ipv6_last=0
    state_write "$_iface" "$_count" "$_last" "$_window" "$_band" "$_since" "$_samples" "$_failures" "$_ipv6_last"
}

interface_disabled() {
    local _iface="$1" _disabled
    _disabled="$(uci -q get "network.${_iface}.disabled" 2>/dev/null || true)"
    [ "$_disabled" = "1" ]
}

detect_operator() {
    local _iface="$1" _line _name _upper
    OPERATOR_NAME="unknown"
    OPERATOR_PROFILE="unknown"
    _line="$(atsd_cli -i "$_iface" -c 'AT+COPS?' 2>/dev/null | grep '+COPS:' | head -n 1)"
    [ -n "$_line" ] || return 1
    _name="$(printf '%s\n' "$_line" | cut -d'"' -f2 | tr -d '\r\n')"
    [ -n "$_name" ] || _name="$(printf '%s\n' "$_line" | cut -d',' -f3 | tr -d ' "\r\n')"
    [ -n "$_name" ] || return 1
    OPERATOR_NAME="$_name"
    _upper="$(printf '%s' "$_line $_name" | tr '[:lower:]' '[:upper:]')"
    case "$_upper" in
        *CHINA\ MOBILE*|*CMCC*|*BROADNET*|*CBN*|*46000*|*46002*|*46004*|*46007*|*46008*|*46015*)
            OPERATOR_PROFILE="mobile-broadnet"
            ;;
        *UNICOM*|*46001*|*46006*|*46009*)
            OPERATOR_PROFILE="unicom"
            ;;
        *TELECOM*|*46003*|*46005*|*46011*|*46012*)
            OPERATOR_PROFILE="telecom"
            ;;
    esac
    return 0
}

status_field() {
    local _text="$1" _field="$2"
    printf '%s\n' "$_text" | sed -n "s/^[[:space:]]*\"${_field}\":[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

ipv4_interface_status() {
    local _iface="$1"
    command -v ifstatus >/dev/null 2>&1 || return 1
    ifstatus "${_iface}_4" 2>/dev/null
}

check_ipv4_health() {
    local _iface="$1" _status _dev
    HEALTH_STATUS="unhealthy"
    HEALTH_REASON="interface-status-missing"
    ACTIVE_DEVICE=""

    _status="$(ipv4_interface_status "$_iface")"
    [ -n "$_status" ] || return 1
    printf '%s\n' "$_status" | grep -F '"up": true' >/dev/null 2>&1 || {
        HEALTH_REASON="ipv4-interface-down"
        return 1
    }
    printf '%s\n' "$_status" | grep -F '"address": "' >/dev/null 2>&1 || {
        HEALTH_REASON="ipv4-address-missing"
        return 1
    }
    _dev="$(status_field "$_status" l3_device)"
    [ -n "$_dev" ] || _dev="$(status_field "$_status" device)"
    case "$_dev" in
        ''|*[!A-Za-z0-9_.:-]*)
            HEALTH_REASON="ipv4-device-invalid"
            return 1
            ;;
    esac
    ACTIVE_DEVICE="$_dev"
    ip -4 route show default 2>/dev/null | grep -F "dev $_dev" >/dev/null 2>&1 || {
        HEALTH_REASON="ipv4-default-route-missing"
        return 1
    }

    if ping -I "$_dev" -c "$HEALTH_PROBE_COUNT" -W "$HEALTH_PROBE_TIMEOUT" "$HEALTH_TARGET_1" >/dev/null 2>&1; then
        HEALTH_STATUS="healthy"
        HEALTH_REASON="probe-${HEALTH_TARGET_1}-ok"
        return 0
    fi
    if ping -I "$_dev" -c "$HEALTH_PROBE_COUNT" -W "$HEALTH_PROBE_TIMEOUT" "$HEALTH_TARGET_2" >/dev/null 2>&1; then
        HEALTH_STATUS="healthy"
        HEALTH_REASON="probe-${HEALTH_TARGET_2}-ok"
        return 0
    fi
    HEALTH_REASON="both-probes-failed"
    return 1
}

soft_ipv4_recover() {
    local _iface="$1" _status _elapsed
    log "${_iface}: IPv4 连续异常，先执行轻量续租，不重启模组"
    _status="$(ipv4_interface_status "$_iface")"
    if printf '%s\n' "$_status" | grep -F '"up": true' >/dev/null 2>&1; then
        ubus call "network.interface.${_iface}_4" renew >/dev/null 2>&1 || true
    elif command -v ifup >/dev/null 2>&1; then
        ifup "${_iface}_4" >/dev/null 2>&1 || true
    fi

    _elapsed=0
    while [ "$_elapsed" -lt "$SOFT_RECOVERY_WAIT" ]; do
        sleep 5
        _elapsed=$((_elapsed + 5))
        if check_ipv4_health "$_iface"; then
            log "${_iface}: 轻量续租后 IPv4 已恢复，用时 ${_elapsed}s"
            return 0
        fi
    done
    log "${_iface}: 轻量续租 ${SOFT_RECOVERY_WAIT}s 后仍异常；reason=${HEALTH_REASON}"
    return 1
}

wait_for_ipv4_recovery() {
    local _iface="$1" _elapsed
    _elapsed=0
    while [ "$_elapsed" -le "$IPV4_RECOVERY_WAIT" ]; do
        if check_ipv4_health "$_iface"; then
            log "${_iface}: CFUN 后 IPv4 已恢复，用时 ${_elapsed}s；${HEALTH_REASON}"
            return 0
        fi
        sleep 10
        _elapsed=$((_elapsed + 10))
    done
    log "${_iface}: CFUN 后 ${IPV4_RECOVERY_WAIT}s 内 IPv4 未恢复；reason=${HEALTH_REASON}"
    return 1
}

check_band() {
    local _iface="$1" _info _mode _band _freq _bw _tech

    BAND_STATUS="unknown"
    BAND_REASON="query-failed"
    BAND_KEY="unknown"
    _info="$(atsd_cli -i "$_iface" -c 'AT^HFREQINFO?' 2>/dev/null | grep 'HFREQINFO:' | head -n 1)"
    [ -n "$_info" ] || return 1

    _mode="$(echo "$_info" | cut -d',' -f2 | tr -d ' \r\n')"
    _band="$(echo "$_info" | cut -d',' -f3 | tr -d ' \r\n')"
    _freq="$(echo "$_info" | cut -d',' -f5 | tr -d ' \r\n')"
    _bw="$(echo "$_info" | cut -d',' -f6 | tr -d ' \r\n')"
    is_uint "$_mode" && is_uint "$_band" && is_uint "$_freq" && is_uint "$_bw" || return 1

    case "$_mode" in
        7) _tech="NR" ;;
        6) _tech="LTE" ;;
        *) _tech="MODE${_mode}" ;;
    esac
    BAND_KEY="${_tech}:${_band}"
    BAND_STATUS="${_tech} band=${_band} freq_field=${_freq} bw=${_bw}kHz"

    if [ "$_mode" = "7" ]; then
        case "$_band" in
            28)
                BAND_REASON="nr28-coverage-band"
                return 0
                ;;
            5|8)
                BAND_REASON="low-coverage-band"
                return 0
                ;;
            1|3|41|78|79)
                BAND_REASON="preferred-nr-band"
                return 2
                ;;
        esac
    fi

    if [ "$_mode" = "6" ]; then
        case "$_band" in
            1|3|7|38|39|40|41|42|43)
                BAND_REASON="preferred-lte-band"
                return 2
                ;;
            5|8|12|17|20|26|28)
                BAND_REASON="low-lte-coverage-band"
                return 0
                ;;
        esac
    fi

    if [ "$_bw" -lt "$MIN_BW" ]; then
        BAND_REASON="low-bandwidth"
        return 0
    fi

    BAND_REASON="adequate-bandwidth"
    return 2
}

ipv6_interface_status() {
    local _iface="$1"
    command -v ifstatus >/dev/null 2>&1 || return 1
    ifstatus "${_iface}_6" 2>/dev/null
}

check_ipv6_ready() {
    local _iface="$1" _status
    IPV6_STATUS="unavailable"
    _status="$(ipv6_interface_status "$_iface")"
    [ -n "$_status" ] || return 1
    if ! printf '%s\n' "$_status" | grep -F '"up": true' >/dev/null 2>&1; then
        if printf '%s\n' "$_status" | grep -F '"pending": true' >/dev/null 2>&1; then
            IPV6_STATUS="pending"
        else
            IPV6_STATUS="down"
        fi
        return 1
    fi
    if printf '%s\n' "$_status" | grep -F '"pending": true' >/dev/null 2>&1; then
        IPV6_STATUS="pending"
        return 1
    fi
    printf '%s\n' "$_status" | grep -F '"address": "' >/dev/null 2>&1 || {
        IPV6_STATUS="address-missing"
        return 1
    }
    IPV6_STATUS="ready"
    return 0
}

device_has_link_local() {
    local _dev="$1"
    [ -n "$_dev" ] || return 1
    ip -6 address show dev "$_dev" 2>/dev/null | grep -F 'inet6 fe80:' | grep -F ' scope link ' >/dev/null 2>&1
}

device_eui64_link_local() {
    local _dev="$1" _mac _b1 _b2 _b3 _b4 _b5 _b6
    [ -r "/sys/class/net/${_dev}/address" ] || return 1
    _mac="$(tr 'A-F' 'a-f' < "/sys/class/net/${_dev}/address" 2>/dev/null)"
    case "$_mac" in
        [0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]) ;;
        *) return 1 ;;
    esac
    _b1="$(printf '%s\n' "$_mac" | cut -d: -f1)"
    _b2="$(printf '%s\n' "$_mac" | cut -d: -f2)"
    _b3="$(printf '%s\n' "$_mac" | cut -d: -f3)"
    _b4="$(printf '%s\n' "$_mac" | cut -d: -f4)"
    _b5="$(printf '%s\n' "$_mac" | cut -d: -f5)"
    _b6="$(printf '%s\n' "$_mac" | cut -d: -f6)"
    printf 'fe80::%02x%02x:%02xff:fe%02x:%02x%02x\n' \
        "$((0x$_b1 ^ 2))" "$((0x$_b2))" "$((0x$_b3))" \
        "$((0x$_b4))" "$((0x$_b5))" "$((0x$_b6))"
}

ensure_device_link_local() {
    local _dev="$1" _link_local
    device_has_link_local "$_dev" && return 0
    _link_local="$(device_eui64_link_local "$_dev")"
    [ -n "$_link_local" ] || return 1
    log "IPv6恢复: ${_dev} 缺少 link-local，补 ${_link_local}/64"
    ip -6 address add "${_link_local}/64" dev "$_dev" >/dev/null 2>&1 || true
    device_has_link_local "$_dev"
}

recover_ipv6_if_needed() {
    local _iface="$1" _status _dev _now _last _elapsed
    check_ipv6_ready "$_iface" && return 0
    _status="$(ipv6_interface_status "$_iface")"
    [ -n "$_status" ] || return 0

    _now="$(date +%s)"
    _last="$(state_get "$_iface" v)"
    is_uint "$_last" || _last=0
    if [ "$_now" -ge "$_last" ] && [ $((_now - _last)) -lt "$IPV6_RECOVERY_COOLDOWN" ]; then
        return 1
    fi
    state_set_ipv6_last "$_iface" "$_now"

    _dev="$(status_field "$_status" l3_device)"
    [ -n "$_dev" ] || _dev="$(status_field "$_status" device)"
    [ -n "$_dev" ] || _dev="$ACTIVE_DEVICE"
    case "$_dev" in
        ''|*[!A-Za-z0-9_.:-]*)
            log "${_iface}: IPv6 ${IPV6_STATUS}，但设备名无效，跳过恢复"
            return 1
            ;;
    esac

    log "${_iface}: IPv6 ${IPV6_STATUS}，开始独立恢复；不重启蜂窝模组"
    ensure_device_link_local "$_dev" || true
    ip -6 neigh flush dev "$_dev" >/dev/null 2>&1 || true
    ifdown "${_iface}_6" >/dev/null 2>&1 || true
    sleep 2
    ensure_device_link_local "$_dev" || true
    ifup "${_iface}_6" >/dev/null 2>&1 || true

    _elapsed=0
    while [ "$_elapsed" -le "$IPV6_RECOVERY_WAIT" ]; do
        if check_ipv6_ready "$_iface"; then
            log "${_iface}: IPv6 已恢复，用时 ${_elapsed}s"
            [ -x /etc/init.d/odhcpd ] && /etc/init.d/odhcpd restart >/dev/null 2>&1 || true
            return 0
        fi
        sleep 10
        _elapsed=$((_elapsed + 10))
    done
    log "${_iface}: IPv6 独立恢复 ${IPV6_RECOVERY_WAIT}s 后仍为 ${IPV6_STATUS}；6小时内不重复扰动"
    return 1
}

retry_ok() {
    local _iface="$1" _count _last _window _now _elapsed _remaining

    RETRY_COUNT=0
    RETRY_WINDOW_START=0
    RETRY_BLOCK_REASON=""
    _count="$(state_get "$_iface" c)"
    _last="$(state_get "$_iface" t)"
    _window="$(state_get "$_iface" w)"
    _now="$(date +%s)"

    is_uint "$_count" || _count=0
    if ! is_uint "$_window"; then
        _window="$_now"
        _count=0
    elif [ "$_now" -lt "$_window" ] || [ $((_now - _window)) -ge "$RETRY_WINDOW" ]; then
        _window="$_now"
        _count=0
    fi

    if is_uint "$_last"; then
        if [ "$_now" -lt "$_last" ]; then
            _last=0
            _window="$_now"
            _count=0
        else
            _elapsed=$((_now - _last))
            if [ "$_elapsed" -lt "$COOLDOWN" ]; then
                _remaining=$((COOLDOWN - _elapsed))
                RETRY_BLOCK_REASON="cooldown ${_remaining}s"
                return 1
            fi
        fi
    fi

    if [ "$_count" -ge "$MAX_RETRIES" ]; then
        _remaining=$((RETRY_WINDOW - (_now - _window)))
        [ "$_remaining" -lt 0 ] && _remaining=0
        RETRY_BLOCK_REASON="budget ${_count}/${MAX_RETRIES}, reset in ${_remaining}s"
        return 1
    fi

    RETRY_COUNT="$_count"
    RETRY_WINDOW_START="$_window"
    return 0
}

do_cfun() {
    local _iface="$1" _count _now _window _rc

    _now="$(date +%s)"
    _count=$((RETRY_COUNT + 1))
    _window="$RETRY_WINDOW_START"
    is_uint "$_window" || _window="$_now"

    log "${_iface}: 双探针连续失败，轻量续租无效；执行最后手段 CFUN ${_count}/${MAX_RETRIES}; operator=${OPERATOR_NAME}/${OPERATOR_PROFILE}; ${BAND_STATUS}; health=${HEALTH_REASON}"
    if atsd_cli -i "$_iface" -c 'AT+CFUN=1,1' -w 5000 >/dev/null 2>&1; then
        _rc=0
    else
        _rc=$?
    fi
    state_write_retry "$_iface" "$_count" "$_now" "$_window" 0
    if [ "$_rc" -ne 0 ]; then
        log "${_iface}: AT+CFUN returned rc=${_rc}; retry budget retained"
        return "$_rc"
    fi
    if wait_for_ipv4_recovery "$_iface"; then
        state_set_health_failures "$_iface" 0
        recover_ipv6_if_needed "$_iface" || true
        return 0
    fi
    return 1
}

process() {
    local _iface="$1" _desc="$2" _band_rc _health_rc _failures _next_failures _old_failures _count _last _ipv6

    if interface_disabled "$_iface"; then
        if [ "$EXEC_MODE" = "apply" ] && state_has "$_iface"; then
            state_clear "$_iface"
            log "${_iface}(${_desc}): 接口已禁用，旧状态已清理"
        fi
        echo "${_iface}=DISABLED"
        return 0
    fi

    detect_operator "$_iface" >/dev/null 2>&1 || true
    check_band "$_iface"
    _band_rc=$?
    check_ipv4_health "$_iface"
    _health_rc=$?

    _failures="$(state_get "$_iface" f)"
    _count="$(state_get "$_iface" c)"
    _last="$(state_get "$_iface" t)"
    is_uint "$_failures" || _failures=0
    is_uint "$_count" || _count=0
    is_uint "$_last" || _last=0
    if check_ipv6_ready "$_iface"; then _ipv6="ready"; else _ipv6="$IPV6_STATUS"; fi

    if [ "$EXEC_MODE" != "apply" ]; then
        if [ "$_health_rc" -eq 0 ]; then
            echo "${_iface}=HOLD mode=${EXEC_MODE} operator=${OPERATOR_NAME}/${OPERATOR_PROFILE} band=${BAND_KEY} health=${HEALTH_STATUS}:${HEALTH_REASON} ipv6=${_ipv6} retries=${_count}/${MAX_RETRIES} last=${_last}"
        else
            _next_failures=$((_failures + 1))
            if [ "$_next_failures" -lt "$HEALTH_FAILURE_LIMIT" ]; then
                echo "${_iface}=WAIT mode=${EXEC_MODE} operator=${OPERATOR_NAME}/${OPERATOR_PROFILE} band=${BAND_KEY} health=${HEALTH_STATUS}:${HEALTH_REASON} failures=${_next_failures}/${HEALTH_FAILURE_LIMIT} ipv6=${_ipv6}"
            elif retry_ok "$_iface"; then
                echo "${_iface}=WOULD-SOFT-RECOVER-THEN-CFUN mode=${EXEC_MODE} operator=${OPERATOR_NAME}/${OPERATOR_PROFILE} band=${BAND_KEY} health=${HEALTH_STATUS}:${HEALTH_REASON}"
            else
                echo "${_iface}=BLOCKED mode=${EXEC_MODE} operator=${OPERATOR_NAME}/${OPERATOR_PROFILE} band=${BAND_KEY} health=${HEALTH_STATUS}:${HEALTH_REASON} block=${RETRY_BLOCK_REASON}"
            fi
        fi
        return 0
    fi

    record_band_observation "$_iface"

    if [ "$_health_rc" -eq 0 ]; then
        _old_failures="$_failures"
        state_set_health_failures "$_iface" 0
        if [ -n "$OBS_PREVIOUS_BAND" ] && [ "$OBS_PREVIOUS_BAND" != "$BAND_KEY" ]; then
            log "${_iface}(${_desc}): 频段变化 ${OBS_PREVIOUS_BAND} -> ${BAND_KEY}；IPv4健康，保持不切换；operator=${OPERATOR_NAME}; ${BAND_STATUS}"
        elif [ "$_old_failures" -gt 0 ]; then
            log "${_iface}(${_desc}): IPv4 已恢复；失败计数 ${_old_failures} -> 0；保持当前频段 ${BAND_KEY}"
        fi
        echo "${_iface}=HEALTHY HOLD operator=${OPERATOR_NAME}/${OPERATOR_PROFILE} band=${BAND_KEY} ${HEALTH_REASON} ipv6=${_ipv6}"
        recover_ipv6_if_needed "$_iface" || true
        return 0
    fi

    _next_failures=$((_failures + 1))
    state_set_health_failures "$_iface" "$_next_failures"
    log "${_iface}(${_desc}): IPv4异常 ${_next_failures}/${HEALTH_FAILURE_LIMIT}; operator=${OPERATOR_NAME}/${OPERATOR_PROFILE}; band=${BAND_KEY}; reason=${HEALTH_REASON}"
    if [ "$_next_failures" -lt "$HEALTH_FAILURE_LIMIT" ]; then
        echo "${_iface}=UNHEALTHY WAIT failures=${_next_failures}/${HEALTH_FAILURE_LIMIT} reason=${HEALTH_REASON}"
        return 1
    fi

    if soft_ipv4_recover "$_iface"; then
        state_set_health_failures "$_iface" 0
        recover_ipv6_if_needed "$_iface" || true
        echo "${_iface}=RECOVERED WITHOUT-CFUN"
        return 0
    fi

    if ! retry_ok "$_iface"; then
        log "${_iface}(${_desc}): CFUN 已阻止；${RETRY_BLOCK_REASON}"
        echo "${_iface}=UNHEALTHY BLOCKED ${RETRY_BLOCK_REASON}"
        return 1
    fi

    if do_cfun "$_iface"; then
        echo "${_iface}=RECOVERED CFUN"
        return 0
    fi
    echo "${_iface}=UNHEALTHY CFUN-FAILED"
    return 1
}

if [ "${NRADIO_SMART_BAND_LIB_ONLY:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

case "${1:-}" in
    ''|apply|--apply) EXEC_MODE="apply" ;;
    status|--status) EXEC_MODE="status" ;;
    dry-run|--dry-run) EXEC_MODE="dry-run" ;;
    *) echo "usage: $0 [apply|status|dry-run]" >&2; exit 2 ;;
esac

if [ "$EXEC_MODE" = "apply" ]; then
    HOUR="$(date +%H)"
    if [ "$HOUR" -lt "$DAY_START" ] || [ "$HOUR" -ge "$DAY_END" ]; then
        exit 0
    fi
fi

if [ "$EXEC_MODE" = "apply" ]; then
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log "已有实例运行，跳过本轮"
        exit 0
    fi
fi

cleanup() {
    [ -n "$TMP_FILE" ] && rm -f "$TMP_FILE"
    [ "$EXEC_MODE" = "apply" ] && rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

RESULT=0
process "cpe" "蜂窝接口1" || RESULT=1
process "cpe1" "蜂窝接口2" || RESULT=1
exit "$RESULT"
