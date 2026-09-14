import os
import re
import shlex
import subprocess
import unittest
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / '20-tools/nradio-multiwan.sh'
MAIN = ROOT / '00-current/ssh-nradio-plugin-installer.sh'
BASH = os.environ.get('BASH_TEST', 'C:/Program Files/Git/bin/bash.exe' if os.name == 'nt' else '/bin/bash')
CODE = SOURCE.read_text(encoding='utf-8').split('case "${1:-status}" in')[0]


def shell(command, mock=''):
    return subprocess.run([BASH], input=CODE + '\n' + mock + '\n' + command,
                          text=True, encoding='utf-8', capture_output=True)


def render(rows, rules=''):
    result = shell('MW_SNAPSHOT=' + shlex.quote(rows) + '\nMW_RULES=' + shlex.quote(rules) + '\nmw_render nr_mw_a')
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout


def distribution(output):
    remaining = Decimal(1)
    shares = {}
    for line in output.splitlines():
        m = re.search(r'--comment nr-mw-(\w+) -j MARK', line)
        if not m:
            continue
        p = re.search(r'--probability ([.\d]+)', line)
        chance = Decimal(p[1]) if p else Decimal(1)
        shares[m[1]] = remaining * chance
        remaining *= 1 - chance
    return shares


class MultiwanTest(unittest.TestCase):
    def test_embedded_source_matches(self):
        main = MAIN.read_text(encoding='utf-8')
        embedded = main.split("<<'EOF_NRADIO_MULTIWAN'\n", 1)[1].split('\nEOF_NRADIO_MULTIWAN', 1)[0]
        self.assertEqual(embedded, SOURCE.read_text(encoding='utf-8').rstrip())
        self.assertIn('SCRIPT_VERSION="V3.2.0"', main)

    def test_two_lines(self):
        shares = distribution(render('cpe_4|3|eth1|online|1\ncpe1_4|5|port5|online|3'))
        self.assertEqual(shares, {'cpe_4': Decimal('.25'), 'cpe1_4': Decimal('.75')})

    def test_three_unequal_lines(self):
        shares = distribution(render('wan|1|wan0|online|2\ncpe_4|3|eth1|online|3\ncpe1_4|5|port5|online|5'))
        for iface, expected in [('wan', '.2'), ('cpe_4', '.3'), ('cpe1_4', '.5')]:
            self.assertLess(abs(shares[iface] - Decimal(expected)), Decimal('.00000001'))

    def test_offline_removed_then_rejoins(self):
        rows = 'wan|1|wan0|offline|2\ncpe_4|3|eth1|online|3\ncpe1_4|5|port5|online|5'
        shares = distribution(render(rows))
        self.assertEqual(shares, {'cpe_4': Decimal('.375'), 'cpe1_4': Decimal('.625')})
        self.assertIn('wan', distribution(render(rows.replace('offline', 'online'))))

    def test_all_offline_fail_closed(self):
        out = render('cpe_4|3|eth1|offline|1\ncpe1_4|5|port5|offline|3')
        self.assertEqual(distribution(out), {})
        self.assertIn('--set-xmark 0xfe00/0xff00', out)

    def test_fixed_rule_before_balance_and_fallback(self):
        rule = 'r1|192.168.66.20/32|203.0.113.0/24|tcp|443|cpe1_4'
        rows = 'cpe_4|3|eth1|online|1\ncpe1_4|5|port5|online|3'
        out = render(rows, rule)
        self.assertLess(out.index('--comment nr-mw-r1'), out.index('--comment nr-mw-cpe_4'))
        self.assertIn('-s 192.168.66.20/32 -d 203.0.113.0/24 -p tcp -m tcp --dport 443', out)
        self.assertNotIn('--comment nr-mw-r1', render(rows.replace('port5|online', 'port5|offline'), rule))

    def test_mark_mask_preserves_other_features(self):
        out = render('cpe1_4|5|port5|online|3')
        self.assertIn('--set-xmark 0x500/0xff00', out)
        for line in out.splitlines():
            if line.startswith('-A '):
                self.assertIn('-m mark --mark 0/0xff00', line)
        self.assertNotIn('CONNMARK --set', out)

    def test_rule_validation(self):
        valid = [('192.168.66.2', '-', 'all', '-', 'cpe_4'),
                 ('-', '203.0.113.0/24', 'tcp', '8000:8100', 'wan')]
        invalid = [('999.1.1.1', '-', 'all', '-', 'wan'),
                   ('192.168.1.1/33', '-', 'all', '-', 'wan'),
                   ('192.168.1.1\n-A bad', '-', 'all', '-', 'wan'),
                   ('-', '-', 'all', '-', 'wan'),
                   ('-', '-', 'all', '443', 'wan'),
                   ('-', '-', 'tcp', '65536', 'wan'),
                   ('-', '-', 'tcp', '443:80', 'wan'),
                   ('-', '-', 'tcp', '443', 'wan;reboot')]
        for values in valid:
            self.assertEqual(shell('mw_validate_rule ' + shlex.join(values)).returncode, 0, values)
        for values in invalid:
            self.assertNotEqual(shell('mw_validate_rule ' + shlex.join(values)).returncode, 0, values)

    def test_weight_validation(self):
        for value in ['1', '3', '1000']:
            self.assertEqual(shell('mw_weight ' + shlex.quote(value)).returncode, 0)
        for value in ['0', '00', '01', '1001', '-1', '2.5', '1\n2', '']:
            self.assertNotEqual(shell('mw_weight ' + shlex.quote(value)).returncode, 0)

    def test_ipv6_rule_validation(self):
        for value in ['2001:db8::1', '2001:db8:1::/64', '::1', '::/0', '2001:DB8:1:2:3:4:5:6/128']:
            self.assertEqual(shell('mw_validate_rule ' + shlex.join([value, '-', 'tcp', '443', 'cpe_6', '6'])).returncode, 0, value)
        for value in ['2001:db8::/129', '2001:::1', '2001::db8::1', '2001:db8:1:2', '1:2:3:4:5:6:7:8:9', '192.168.1.2', '2001:db8::1\n-A x']:
            self.assertNotEqual(shell('mw_validate_rule ' + shlex.join([value, '-', 'tcp', '443', 'cpe_6', '6'])).returncode, 0, value)

    def test_ipv6_classification_uses_ipv6_interface_ids(self):
        rows = 'cpe_6|4|eth1|online|1\ncpe1_6|6|port5|online|3'
        rule = 'r6|2001:db8:1::/64|2001:db8:2::/64|udp|443|cpe1_6'
        output = render(rows, rule)
        self.assertIn('--set-xmark 0x400/0xff00', output)
        self.assertIn('--set-xmark 0x600/0xff00', output)
        self.assertIn('-s 2001:db8:1::/64 -d 2001:db8:2::/64 -p udp', output)

    def test_nat66_only_selected_online_marked_exits(self):
        rows = 'cpe_6|4|eth1|online|1\ncpe1_6|6|port5|offline|3'
        result = shell('MW_SNAPSHOT=' + shlex.quote(rows) + '\nmw_nat6_render')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('-o eth1 -m mark --mark 0x400/0xff00 -j MASQUERADE', result.stdout)
        self.assertNotIn('port5', result.stdout)
        self.assertEqual(result.stdout.count('-j MASQUERADE'), 1)

    def test_mixed_family_snapshot_filters_independently(self):
        mock = '''
mw_interfaces() { case "$1" in 4) echo 'cpe_4|3|eth1|online';; 6) echo 'cpe_6|4|eth1|online';; esac; }
uci() { case "$3" in
    nradio_multiwan.main.interfaces) echo 'cpe_4 cpe_6';;
    mwan3.cpe_4.family) echo ipv4;;
    mwan3.cpe_6.family) echo ipv6;;
    nradio_multiwan.l_cpe_4.weight|nradio_multiwan.l_cpe_6.weight) echo 3;;
    *) return 1;;
esac; }
'''
        self.assertEqual(shell('mw_snapshot 4', mock).stdout.strip(), 'cpe_4|3|eth1|online|3')
        self.assertEqual(shell('mw_snapshot 6', mock).stdout.strip(), 'cpe_6|4|eth1|online|3')

    def test_ipv4_and_ipv6_connection_counts_separate(self):
        mock = '''
conntrack() { printf '%s\\n' 'tcp src=192.0.2.1 dst=192.0.2.2 mark=768' 'tcp src=2001:db8::1 dst=2001:db8::2 mark=1024'; }
'''
        self.assertEqual(shell('mw_connections 4', mock).stdout.strip(), '3 1')
        self.assertEqual(shell('mw_connections 6', mock).stdout.strip(), '4 1')

    def test_snapshot_rejects_duplicate_or_unknown_interfaces(self):
        mock = '''
mw_interfaces() { printf 'cpe_4|3|eth1|online\\n'; }
uci() { case "$3" in
    nradio_multiwan.main.interfaces) printf '%s' "$SELECTED" ;;
    nradio_multiwan.l_cpe_4.weight) echo 1 ;;
    *) return 1 ;;
esac; }
'''
        for selected in ['cpe_4 cpe_4', 'wan2']:
            self.assertNotEqual(shell('SELECTED=' + shlex.quote(selected) + '\nmw_snapshot', mock).returncode, 0)
        self.assertEqual(shell('SELECTED=cpe_4\nmw_snapshot', mock).stdout.strip(), 'cpe_4|3|eth1|online|1')


if __name__ == '__main__':
    unittest.main(verbosity=2)
