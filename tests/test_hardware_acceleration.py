"""Local shell integration tests; all router paths and commands use fixtures."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "00-current/ssh-nradio-plugin-installer.sh").read_text(encoding="utf-8")
PARSER = argparse.ArgumentParser()
PARSER.add_argument("--shell", default="sh")
OPTIONS, UNIT_ARGS = PARSER.parse_known_args()

MOCKS = r'''
log() { printf '%s\n' "$*"; }
sleep() { :; }
uname() { printf 'fixture\n'; }
fail_once() {
    if [ -f "$MOCK_ROOT/fail" ] && [ "$(command cat "$MOCK_ROOT/fail")" = "$1" ]; then
        rm "$MOCK_ROOT/fail"
        return 0
    fi
    return 1
}
kv_get() {
    awk -v key="$2" 'index($0,key "=")==1 { print substr($0,length(key)+2); found=1; exit } END { if (!found) exit 1 }' "$1"
}
kv_set() {
    local path="$1" key="$2" value="$3"
    touch "$path"
    awk -v key="$key" 'index($0,key "=")!=1' "$path" > "$path.next"
    printf '%s=%s\n' "$key" "$value" >> "$path.next"
    mv "$path.next" "$path"
}
uci() {
    [ "${1:-}" != -q ] || shift
    local op="$1" arg="${2:-}" package key value pending
    package="${arg%%.*}"
    package="${package%%=*}"
    pending="$MOCK_ROOT/pending-$package"
    case "$op" in
        get)
            if [ -f "$pending" ] && kv_get "$pending" "$arg"; then return 0; fi
            kv_get "$MOCK_ROOT/etc/config/$package" "$arg"
            ;;
        changes) [ ! -f "$pending" ] || command cat "$pending" ;;
        set)
            printf 'uci set %s\n' "$arg" >> "$MOCK_ROOT/actions"
            fail_once "set-$arg" && return 1
            key="${arg%%=*}"; value="${arg#*=}"
            kv_set "$pending" "$key" "$value"
            ;;
        commit)
            printf 'uci commit %s\n' "$arg" >> "$MOCK_ROOT/actions"
            fail_once "commit-$arg" && return 1
            if [ -f "$pending" ]; then
                while IFS='=' read -r key value; do kv_set "$MOCK_ROOT/etc/config/$package" "$key" "$value"; done < "$pending"
                rm "$pending"
            fi
            ;;
        revert) rm -f "$pending" ;;
        *) return 1 ;;
    esac
    return 0
}
fw3() {
    printf 'fw3 %s\n' "$*" >> "$MOCK_ROOT/actions"
    fail_once fw3 && return 1
    if [ "$(uci get firewall.@defaults[0].flow_offloading)" = 1 ]; then
        if [ "$(uci get firewall.@defaults[0].flow_offloading_hw 2>/dev/null || true)" = 1 ]; then
            printf '%s\n' '-A FORWARD -j FLOWOFFLOAD --hw' > "$MOCK_ROOT/rules4"
        else
            printf '%s\n' '-A FORWARD -j FLOWOFFLOAD' > "$MOCK_ROOT/rules4"
        fi
    else
        : > "$MOCK_ROOT/rules4"
    fi
    cp "$MOCK_ROOT/rules4" "$MOCK_ROOT/rules6"
}
iptables() {
    [ ! -f "$MOCK_ROOT/rules-fail" ] || return 1
    command cat "$MOCK_ROOT/rules4"
}
ip6tables() { command cat "$MOCK_ROOT/rules6"; }
iptables-save() { printf '%s\n' '-A FORWARD -j openclash'; }
pidof() { [ ! -f "$MOCK_ROOT/openclash" ] || printf '123\n'; }
dmesg() { command cat "$MOCK_ROOT/dmesg"; }
cat() {
    if [ "${1:-}" = "$MOCK_ROOT/sys/kernel/debug/hnat/hook_toggle" ]; then
        case "$(command cat "$MOCK_ROOT/read-mode")" in
            log)
                local state word
                state="$(command cat "$1")"; word=disabled
                [ "$state" != 1 ] || word=enabled
                printf '[%s.000] value=%s, hook is %s now!\n' "$(wc -l < "$MOCK_ROOT/dmesg")" "$state" "$word" >> "$MOCK_ROOT/dmesg"
                return 0
                ;;
            stale) return 0 ;;
            ring-reset) printf '[new] unrelated\n' > "$MOCK_ROOT/dmesg"; return 0 ;;
        esac
    fi
    command cat "$@"
}
mock_service() {
    case "$1" in
        enabled) [ "$(command cat "$MOCK_ROOT/boot")" = 1 ]; return $? ;;
        enable|disable)
            printf 'service %s\n' "$1" >> "$MOCK_ROOT/actions"
            fail_once "service-$1" && return 1
            if [ "$1" = enable ]; then printf '1\n'; else printf '0\n'; fi > "$MOCK_ROOT/boot"
            ;;
        restart)
            printf 'service restart\n' >> "$MOCK_ROOT/actions"
            fail_once service-restart && return 1
            if [ "$(uci get mtkhnat.global.enable)" != 1 ] || [ -e "$MOCK_ROOT/var/run/mtkhnat/status" ]; then
                printf '0\n' > "$MOCK_ROOT/sys/kernel/debug/hnat/hook_toggle"
                uci set firewall.@defaults[0].flow_offloading=0
            elif [ "$(uci get mtkhnat.global.mode 2>/dev/null || printf 2)" = 2 ]; then
                printf '0\n' > "$MOCK_ROOT/sys/kernel/debug/hnat/hook_toggle"
                uci set firewall.@defaults[0].flow_offloading=1
            else
                if ! fail_once hook-mismatch; then printf '1\n' > "$MOCK_ROOT/sys/kernel/debug/hnat/hook_toggle"; fi
                uci set firewall.@defaults[0].flow_offloading=0
            fi
            uci commit firewall
            fw3 reload
            ;;
        *) return 1 ;;
    esac
}
print_menu_header() { printf 'HEADER:%s\n' "$*"; }
print_menu_item() { printf 'ITEM:%s:%s\n' "$1" "$2"; }
print_menu_prompt() { :; }
read_category_choice() { IFS= read -r UI_READ_RESULT || UI_READ_RESULT=invalid; }
die_menu_input_issue() { printf 'INVALID:%s\n' "$*"; exit 9; }
die() { printf '%s\n' "$*"; exit 9; }
record_action_history() { printf 'HISTORY:%s:%s\n' "$1" "$3"; }
is_current_model_ak798() { [ "$TEST_MODEL" = ak ]; }
is_current_model_c8_788() { [ "$TEST_MODEL" = c8 ]; }
lightweight_appcenter_model_supported() { [ "$TEST_MODEL" = ak ]; }
nradio_5g_aggregation_model_supported() { [ "$TEST_MODEL" = 5800 ]; }
nradio_cpe_monitoring_model_supported() { [ "$TEST_MODEL" = 5800 ] || [ "$TEST_MODEL" = max ]; }
'''


class HardwareAccelerationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nradio-hnat-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.paths = (
            "/etc/init.d/mtkhnat", "/etc/config/", "/sbin/mtkhnat",
            "/sys/kernel/debug/hnat/", "/sys/module/mtkhnat",
            "/lib/modules/", "/proc/sys/net/ipv6", "/var/run/mtkhnat/status",
        )
        block = SOURCE[SOURCE.index("nradio_hwaccel_capabilities() {"):SOURCE.index("read_category_choice() {", SOURCE.index("c8_788_feature_allowed() {"))]
        menu = SOURCE[SOURCE.index("maintenance_test_menu() {"):SOURCE.index("main_menu() {", SOURCE.index("maintenance_test_menu() {"))]
        main = SOURCE[SOURCE.index("main_menu() {", SOURCE.index("maintenance_test_menu() {")):SOURCE.rindex('\nmain_menu "$@"')]
        self.library = self.relocate(block + menu + main)
        self.write("library.sh", self.library)
        self.write("mocks.sh", MOCKS)
        self.write("etc/config/mtkhnat", "mtkhnat.global=global\nmtkhnat.global.enable=1\n")
        self.write("etc/config/firewall", "firewall.@defaults[0]=defaults\nfirewall.@defaults[0].flow_offloading=1\nfirewall.@defaults[0].flow_offloading_hw=1\n")
        self.write("sys/kernel/debug/hnat/hook_toggle", "0\n")
        self.write("sys/kernel/debug/hnat/all_entry", "state=UNBIND\nstate=UNBIND\n")
        self.write("lib/modules/fixture/xt_FLOWOFFLOAD.ko", "")
        (self.root / "sys/module/mtkhnat").mkdir(parents=True)
        (self.root / "proc/sys/net/ipv6").mkdir(parents=True)
        self.write("read-mode", "direct\n")
        self.write("boot", "1\n")
        self.write("dmesg", "[old] value=1, hook is enabled now!\n[boundary] literal \\x55\n")
        self.write("rules4", "-A FORWARD -j FLOWOFFLOAD --hw\n")
        self.write("rules6", "-A FORWARD -j FLOWOFFLOAD --hw\n")
        self.write("actions", "")
        self.write("etc/init.d/mtkhnat", self.relocate('#!/bin/sh\n# /sbin/mtkhnat\n. "$MOCK_ROOT/mocks.sh"\nmock_service "$@"\n'), executable=True)
        self.write("sbin/mtkhnat", "#!/bin/sh\n# OEM controller fixture\n", executable=True)

    def relocate(self, text):
        for path in self.paths:
            text = text.replace(path, self.root.as_posix() + path)
        return text

    def write(self, name, text, executable=False):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8", newline="\n")
        if executable:
            target.chmod(0o755)

    def run_shell(self, body, stdin="", model="5800", rc=0):
        self.write("case.sh", 'set -eu\n. "$MOCK_ROOT/mocks.sh"\n. "$MOCK_ROOT/library.sh"\nSTATE_DIR="$MOCK_ROOT/state"\nMENU_ACTION_COMPLETED=0\n' + body + "\n")
        env = dict(os.environ, MOCK_ROOT=self.root.as_posix(), TEST_MODEL=model)
        # Bytes keep LF input intact on Windows; text-mode pipes add CRLF.
        result = subprocess.run([OPTIONS.shell, str(self.root / "case.sh")], input=stdin.encode("utf-8"), capture_output=True, env=env, timeout=30)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        self.assertEqual(result.returncode, rc, stdout + stderr)
        return stdout

    def test_controller_source_is_not_whitelisted(self):
        self.run_shell("nradio_hwaccel_capabilities")
        self.write("sbin/mtkhnat", "#!/bin/sh\n# Another firmware controller implementation\n", executable=True)
        self.run_shell("nradio_hwaccel_capabilities; nradio_hwaccel_set 1")

    def test_hardware_menu_skips_model_checks(self):
        body = '''
require_root() { :; }
acquire_script_lock() { :; }
require_startup_disclaimer_acceptance_once() { :; }
prime_startup_disclaimer_model() { CURRENT_DETECTED_MODEL="$TEST_MODEL"; }
detect_nros_revision() { printf '2.2.15\n'; }
print_main_menu_header() { :; }
require_supported_nradio_model_environment() { die unexpected_model_check; }
require_nradio_appcenter_startup_environment() { die unexpected_appcenter_check; }
log_nradio_oem_environment_hint() { die unexpected_environment_hint; }
'''
        for invocation, inputs in (("main_menu 5", "11\n3\n"), ("main_menu", "5\n11\n3\n")):
            output = self.run_shell(body + invocation, inputs, model="future-model")
            self.assertIn("HEADER:5 > 11 / 硬件加速管理", output)
            self.assertNotIn("支持:", output)
            self.assertNotIn("提示", output)
            self.assertNotIn("所有机型", output)
        self.run_shell(body + "main_menu 1", model="future-model", rc=9)
        self.run_shell(body + "run_menu_feature 13", model="future-model", rc=9)

    def test_missing_capability_and_status_only(self):
        (self.root / "lib/modules/fixture/xt_FLOWOFFLOAD.ko").unlink()
        output = self.run_shell("nradio_hwaccel_show_status; if nradio_hwaccel_set 1; then exit 7; fi")
        self.assertIn("缺少原厂软件卸载模块", output)
        self.assertIn("BIND=0，尚未观察到硬件命中", output)
        self.assertEqual((self.root / "actions").read_text(), "")

    def test_enable_disable_persistence_and_idempotence(self):
        output = self.run_shell('nradio_hwaccel_set 1; nradio_hwaccel_state_matches 1; nradio_hwaccel_show_status; before="$(cat "$MOCK_ROOT/actions")"; nradio_hwaccel_set 1; [ "$before" = "$(cat "$MOCK_ROOT/actions")" ]; nradio_hwaccel_set 0; nradio_hwaccel_state_matches 0')
        self.assertIn("HNAT 已开启", output)
        self.assertIn("无需重复切换", output)
        self.assertIn("软件卸载已启用", output)
        self.assertIn("mtkhnat.global.mode=2", (self.root / "etc/config/mtkhnat").read_text())
        self.assertNotIn("--hw", (self.root / "rules6").read_text())
        self.assertEqual(len(list((self.root / "state/hnat-backups").iterdir())), 2)

    def test_service_boot_is_enabled(self):
        self.write("boot", "0\n")
        self.run_shell('nradio_hwaccel_set 1; [ "$(cat "$MOCK_ROOT/boot")" = 1 ]')

    def test_hook_log_read_uses_fresh_lines(self):
        self.write("read-mode", "log\n")
        self.run_shell('[ "$(nradio_hwaccel_hook_state)" = 0 ]; nradio_hwaccel_set 1; [ "$HWACCEL_HOOK" = 1 ]')

    def test_hook_log_read_from_empty_history(self):
        self.write("read-mode", "log\n")
        self.write("dmesg", "")
        self.run_shell('[ "$(nradio_hwaccel_hook_state)" = 0 ]')

    def test_missing_service_boot_state_is_unknown(self):
        (self.root / "etc/init.d/mtkhnat").unlink()
        self.run_shell('nradio_hwaccel_collect_state; [ "$HWACCEL_BOOT" = unknown ]')

    def test_stale_and_rotated_logs_are_unknown(self):
        for mode in ("stale", "ring-reset"):
            with self.subTest(mode=mode):
                self.write("read-mode", mode + "\n")
                output = self.run_shell('[ "$(nradio_hwaccel_hook_state)" = unknown ]; if nradio_hwaccel_set 1; then exit 7; fi')
                self.assertIn("无法建立恢复基线", output)
        self.assertEqual((self.root / "actions").read_text(), "")

    def test_blocked_enable_and_pending_changes_stop_before_writes(self):
        self.write("var/run/mtkhnat/status", "")
        output = self.run_shell("if nradio_hwaccel_set 1; then exit 7; fi")
        self.assertIn("原厂 HNAT 阻止标记", output)
        (self.root / "var/run/mtkhnat/status").unlink()
        self.write("pending-firewall", "firewall.other=unsaved\n")
        output = self.run_shell("if nradio_hwaccel_set 1; then exit 7; fi")
        self.assertIn("未提交配置", output)
        self.assertEqual((self.root / "actions").read_text(), "")

    def test_backup_failure_stops_without_switching(self):
        output = self.run_shell('cp() { return 1; }; if nradio_hwaccel_set 1; then exit 7; fi')
        self.assertIn("配置备份失败", output)
        self.assertEqual((self.root / "actions").read_text(), "")
        self.assertEqual((self.root / "sys/kernel/debug/hnat/hook_toggle").read_text(), "0\n")

    def test_failures_restore_exact_configs_runtime_and_boot(self):
        original_mtk = (self.root / "etc/config/mtkhnat").read_bytes()
        original_fw = (self.root / "etc/config/firewall").read_bytes()
        self.write("boot", "0\n")
        for failure in ("set-mtkhnat.global.mode=0", "commit-firewall", "fw3", "service-enable", "service-restart", "hook-mismatch"):
            with self.subTest(failure=failure):
                self.write("fail", failure + "\n")
                output = self.run_shell("if nradio_hwaccel_set 1; then exit 7; fi")
                self.assertIn("状态已恢复", output)
                self.assertEqual((self.root / "etc/config/mtkhnat").read_bytes(), original_mtk)
                self.assertEqual((self.root / "etc/config/firewall").read_bytes(), original_fw)
                self.assertEqual((self.root / "boot").read_text(), "0\n")
                self.assertEqual((self.root / "sys/kernel/debug/hnat/hook_toggle").read_text(), "0\n")
                self.assertIn("--hw", (self.root / "rules6").read_text())

    def test_failed_restore_is_not_reported_as_success(self):
        self.write("fail", "fw3\n")
        output = self.run_shell('cp() { case "$1:$2" in -p:*hnat-backups*) return 1 ;; esac; command cp "$@"; }; if nradio_hwaccel_set 1; then exit 7; fi')
        self.assertIn("未能完整确认恢复", output)
        self.assertNotIn("状态已恢复", output)

    def test_unknown_rules_stop_and_mixed_rules_fail_verification(self):
        self.write("rules-fail", "")
        output = self.run_shell("if nradio_hwaccel_set 1; then exit 7; fi")
        self.assertIn("无法建立恢复基线", output)
        (self.root / "rules-fail").unlink()
        self.write("rules4", "-A FORWARD -j FLOWOFFLOAD\n-A FORWARD -j FLOWOFFLOAD --hw\n")
        self.run_shell('[ "$(nradio_hwaccel_rule_state iptables)" = mixed ]')

    def test_bind_count_and_openclash_check(self):
        self.write("sys/kernel/debug/hnat/all_entry", "state=UNBIND\nstate=BIND\nstate=BINDING\nstate=BIND, bytes=42\n")
        self.write("openclash", "")
        output = self.run_shell("nradio_hwaccel_show_status")
        self.assertIn("BIND=2", output)
        self.assertIn("核心进程存在", output)
        self.assertIn("仅代表进程/规则检查结果", output)

    def test_ipv6_unavailable(self):
        (self.root / "proc/sys/net/ipv6").rmdir()
        self.run_shell('nradio_hwaccel_set 1; nradio_hwaccel_set 0; [ "$HWACCEL_RULE6" = unavailable ]')

    def test_disabled_ipv6_still_checks_residual_rules(self):
        self.run_shell('nradio_hwaccel_set 0; uci set firewall.@defaults[0].disable_ipv6=1; uci commit firewall')
        self.write("rules6", "-A FORWARD -j FLOWOFFLOAD --hw\n")
        self.run_shell('nradio_hwaccel_collect_state; [ "$HWACCEL_RULE6" = hardware ]; if nradio_hwaccel_state_matches 0; then exit 7; fi')
        self.write("rules6", "")
        self.run_shell('nradio_hwaccel_collect_state; [ "$HWACCEL_RULE6" = none ]; nradio_hwaccel_state_matches 0')

    def test_menu_numbers_dispatch_and_return_for_each_layout(self):
        for model, choice in (("5800", 11), ("max", 11), ("generic", 11), ("ak", 11), ("c8", 11)):
            with self.subTest(model=model):
                output = self.run_shell('maintenance_test_menu; [ "$MENU_ACTION_COMPLETED" = 1 ]', f"{choice}\n3\n", model)
                self.assertIn(f"ITEM:{choice}:硬件加速管理", output)
                self.assertIn(f"HEADER:5 > {choice} / 硬件加速管理", output)
                self.assertIn(f"ITEM:{choice + 1}:返回功能分类", output)
                items = re.findall(r"^ITEM:(\d+):", output, re.M)
                parent_items = items[:items.index("12") + 1]
                self.assertEqual(len(parent_items), len(set(parent_items)))
                self.assertEqual(re.findall(r"^ITEM:(\d+):硬件加速管理$", output, re.M), ["11"])
                output = self.run_shell('maintenance_test_menu; [ "$MENU_ACTION_COMPLETED" = 0 ]', f"{choice}\n0\n0\n", model)
                self.assertEqual(output.count(f"ITEM:{choice}:硬件加速管理"), 2)
                self.assertNotIn("HISTORY:", output)
                output = self.run_shell('maintenance_test_menu; [ "$MENU_ACTION_COMPLETED" = 0 ]', "12\n", model)
                self.assertNotIn("HNAT:", output)

    def test_menu_switch_actions_and_failure_history(self):
        output = self.run_shell("maintenance_test_menu", "11\n1\n")
        self.assertIn("HISTORY:5 > 11 > 1:PASS", output)
        output = self.run_shell("maintenance_test_menu", "11\n2\n")
        self.assertIn("HISTORY:5 > 11 > 2:PASS", output)
        self.write("fail", "fw3\n")
        output = self.run_shell("maintenance_test_menu", "11\n1\n", rc=1)
        self.assertIn("HISTORY:5 > 11 > 1:FAIL", output)
        self.assertIn("重载防火墙失败", output)


if __name__ == "__main__":
    unittest.main(argv=[__file__, *UNIT_ARGS])
