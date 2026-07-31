#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"; rm -f /tmp/nradio-quote-regression-pwn' EXIT INT TERM HUP

for script in 00-current/*.sh; do
    sh -n "$script"
done

for parent_script in \
    00-current/ssh-nradio-plugin-installer.sh \
    00-current/ssh-nradio-plugin-installer-2.0.0beta.sh
do
    embedded_name=$(basename "$parent_script")
    sed -n "/<<'EOF_PLUGIN_UNINSTALL_HELPER'/,/^EOF_PLUGIN_UNINSTALL_HELPER$/p" "$parent_script" |
        sed '1d;$d' > "$tmp_dir/$embedded_name.uninstall"
    sh -n "$tmp_dir/$embedded_name.uninstall"

    sed -n '/<<EOF_EASYTIER_ROUTE_APPLY/,/^EOF_EASYTIER_ROUTE_APPLY$/p' "$parent_script" |
        sed '1d;$d; s/\\\([$`\\]\)/\1/g' > "$tmp_dir/$embedded_name.easytier"
    sh -n "$tmp_dir/$embedded_name.easytier"
done

if grep -En 'curl[^[:cntrl:]]*([[:space:]]-[[:alnum:]]*k[[:alnum:]]*|--insecure)|wget[^[:cntrl:]]*--no-check-certificate' 00-current/*.sh; then
    printf '%s\n' 'unsafe TLS bypass flag found' >&2
    exit 1
fi

for shell_quote_file in \
    00-current/ssh-nradio-plugin-installer.sh \
    00-current/ssh-nradio-plugin-installer-2.0.0beta.sh
do
    function_file="$tmp_dir/$(basename "$shell_quote_file").functions"
    sed -n '/^shell_quote() {/,/^}$/p; /^state_file_is_v2() {/,/^}$/p' "$shell_quote_file" > "$function_file"
    . "$function_file"

    for value in "plain" "alpha'beta" 'x; touch /tmp/nradio-quote-regression-pwn; #' "line1
line2"; do
        quoted=$(shell_quote "$value")
        printf 'VALUE=%s\n' "$quoted" | sh -n -
    done

    rm -f /tmp/nradio-quote-regression-pwn
    quoted=$(shell_quote "x'; touch /tmp/nradio-quote-regression-pwn; #")
    printf 'VALUE=%s\n' "$quoted" > "$tmp_dir/state"
    if ! . "$tmp_dir/state" 2>/dev/null; then
        printf '%s\n' "quoted state failed to load: $shell_quote_file" >&2
        exit 1
    fi
    if [ -e /tmp/nradio-quote-regression-pwn ]; then
        printf '%s\n' "state value injection regression detected: $shell_quote_file" >&2
        exit 1
    fi

    printf '%s\n' "VALUE='legacy'" > "$tmp_dir/legacy-state"
    if state_file_is_v2 "$tmp_dir/legacy-state"; then
        printf '%s\n' "legacy state format accepted: $shell_quote_file" >&2
        exit 1
    fi
    printf '%s\n' "NRADIO_STATE_FORMAT='2'" "VALUE='current'" > "$tmp_dir/current-state"
    state_file_is_v2 "$tmp_dir/current-state"
    grep -q 'EasyTier 路由状态文件格式不安全' "$shell_quote_file"
done

for opkg_script in \
    00-current/ssh-nradio-plugin-installer.sh \
    00-current/ssh-nradio-plugin-installer-2.0.0beta.sh
do
    opkg_function_file="$tmp_dir/$(basename "$opkg_script").opkg-function"
    sed -n '/^ensure_opkg_update() {/,/^}$/p' "$opkg_script" > "$opkg_function_file"
    (
        FEEDS="$tmp_dir/mock-feeds"
        : > "$FEEDS"
        . "$opkg_function_file"
        ensure_default_feeds() { return 0; }
        log() { :; }
        opkg() { return 1; }
        if ensure_opkg_update; then
            printf '%s\n' "opkg update failure was ignored: $opkg_script" >&2
            exit 1
        fi
    )
done

if grep -En '^[[:space:]]*ensure_opkg_update[[:space:]]*$' \
    00-current/ssh-nradio-plugin-installer.sh \
    00-current/ssh-nradio-plugin-installer-2.0.0beta.sh
then
    printf '%s\n' 'unchecked ensure_opkg_update call found' >&2
    exit 1
fi

grep -q 'SCRIPT_VERSION="V2.6.1"' 00-current/ssh-nradio-plugin-installer.sh
grep -q 'SCRIPT_RELEASE_DATE="2026-07-31"' 00-current/ssh-nradio-plugin-installer.sh
grep -q 'V2.6.1' README.md
grep -q 'V2.6.1' CHANGELOG.md
for script in 00-current/ssh-nradio-plugin-installer.sh 00-current/ssh-nradio-plugin-installer-2.0.0beta.sh; do
    grep -q 'deb8730e598e0cda45ad554127f87f2ee534c8a4a12efc8d4865f81fc12d56f1' "$script"
    grep -q '04b52b5c3df51266e6f4d8568cd17679b37fe0cbd4a65ead0aa9958b5dd72f8d' "$script"
done
grep -q 'deb8730e598e0cda45ad554127f87f2ee534c8a4a12efc8d4865f81fc12d56f1' 00-current/qiyou-nradio-temp-installer.sh
grep -q '04b52b5c3df51266e6f4d8568cd17679b37fe0cbd4a65ead0aa9958b5dd72f8d' 00-current/leigod-nradio-temp-installer.sh
grep -q 'verify_remote_script_sha256 "奇游入口脚本"' 00-current/ssh-nradio-plugin-installer-2.0.0beta.sh
grep -q 'verify_remote_script_sha256 "雷神官方安装脚本"' 00-current/ssh-nradio-plugin-installer-2.0.0beta.sh

checksum_file="$tmp_dir/checksums.sha256"
awk '/^[0-9a-f]{64}[[:space:]]+[0-9]+[[:space:]]+/ { print $1 "  " $3 }' CHECKSUMS.txt > "$checksum_file"
sha256sum -c "$checksum_file"
printf '%s\n' 'repository checks passed'
