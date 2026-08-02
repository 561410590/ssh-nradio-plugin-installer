#!/bin/sh
# NRadio 智能频段切换 v3 - 低频驻留时安全触发重新选网
LOG_TAG="nradio-band"
STATE_FILE="/tmp/nradio_band_state"
LOCK_DIR="/tmp/nradio-smart-band.lock"
MIN_FREQ=1500000
MIN_BW=20000
MAX_RETRIES=3
COOLDOWN=7200
RETRY_WINDOW=43200
DAY_START=5
DAY_END=22

TMP_FILE=""
BAND_STATUS="unknown"
BAND_REASON="unknown"
RETRY_COUNT=0
RETRY_WINDOW_START=0
RETRY_BLOCK_REASON=""

log() {
    logger -t "$LOG_TAG" "$1"
    echo "$(date +%H:%M:%S) $1"
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

state_write_retry() {
    local _iface="$1" _count="$2" _last="$3" _window="$4"

    TMP_FILE="${STATE_FILE}.tmp.$$"
    if [ -f "$STATE_FILE" ]; then
        grep -v "^${_iface}_" "$STATE_FILE" > "$TMP_FILE" 2>/dev/null || true
    else
        : > "$TMP_FILE"
    fi
    printf '%s\n' \
        "${_iface}_c=${_count}" \
        "${_iface}_t=${_last}" \
        "${_iface}_w=${_window}" >> "$TMP_FILE"
    mv "$TMP_FILE" "$STATE_FILE"
    TMP_FILE=""
}

interface_disabled() {
    local _iface="$1" _disabled
    _disabled="$(uci -q get "network.${_iface}.disabled" 2>/dev/null || true)"
    [ "$_disabled" = "1" ]
}

check_band() {
    local _iface="$1" _info _mode _band _freq _bw _tech

    BAND_STATUS="unknown"
    BAND_REASON="query-failed"
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
    BAND_STATUS="${_tech} band=${_band} freq=${_freq}kHz bw=${_bw}kHz"

    if [ "$_mode" = "7" ]; then
        case "$_band" in
            5|8|28)
                BAND_REASON="low-coverage-band"
                return 0
                ;;
            1|3|41|78|79)
                BAND_REASON="preferred-nr-band"
                return 2
                ;;
        esac
    fi

    if [ "$_freq" -lt "$MIN_FREQ" ] || [ "$_bw" -lt "$MIN_BW" ]; then
        BAND_REASON="low-frequency-or-bandwidth"
        return 0
    fi

    BAND_REASON="high-frequency-band"
    return 2
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

    log "${_iface}: reselect ${_count}/${MAX_RETRIES}; ${BAND_STATUS}; reason=${BAND_REASON}"
    if atsd_cli -i "$_iface" -c 'AT+CFUN=1,1' -w 5000 >/dev/null 2>&1; then
        _rc=0
    else
        _rc=$?
    fi
    state_write_retry "$_iface" "$_count" "$_now" "$_window"
    [ "$_rc" -eq 0 ] || log "${_iface}: AT+CFUN returned rc=${_rc}; retry budget retained"
}

process() {
    local _iface="$1" _desc="$2" _rc

    if interface_disabled "$_iface"; then
        if state_has "$_iface"; then
            state_clear "$_iface"
            log "${_iface}(${_desc}): interface disabled; stale retry state cleared"
        fi
        echo "${_iface}=DISABLED"
        return 0
    fi

    check_band "$_iface"
    _rc=$?
    if [ "$_rc" -eq 1 ]; then
        log "${_iface}(${_desc}): band query failed"
        echo "${_iface}=UNKNOWN"
        return 1
    fi

    if [ "$_rc" -eq 2 ]; then
        if state_has "$_iface"; then
            state_clear "$_iface"
            log "${_iface}(${_desc}): recovered; ${BAND_STATUS}; retry state cleared"
        fi
        echo "${_iface}=HIGH ${BAND_STATUS}"
        return 0
    fi

    log "${_iface}(${_desc}): LOW; ${BAND_STATUS}; reason=${BAND_REASON}"
    if ! retry_ok "$_iface"; then
        log "${_iface}(${_desc}): reselect skipped; ${RETRY_BLOCK_REASON}"
        echo "${_iface}=LOW BLOCKED ${RETRY_BLOCK_REASON}"
        return 1
    fi

    do_cfun "$_iface"
    echo "${_iface}=LOW RESELECTED"
}

HOUR="$(date +%H)"
if [ "$HOUR" -lt "$DAY_START" ] || [ "$HOUR" -ge "$DAY_END" ]; then
    exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "another instance is running; skipped"
    exit 0
fi

cleanup() {
    [ -n "$TMP_FILE" ] && rm -f "$TMP_FILE"
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

process "cpe" "CT"
process "cpe1" "CU"
