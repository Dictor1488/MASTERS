#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'python/gui/mods/mod_under_pressure_mastery.py'
text = TARGET.read_text(encoding='utf-8-sig')
original = text

text = text.replace(
    "logging.getLogger('under_pressure.mastery')",
    "logging.getLogger('under_pressure.masters')",
)

# Masters may capture the pre-battle garage snapshot for its history, but it
# must never enter live battle mode. Marks owns battle UI, damage tracking and
# feedback subscriptions.
enter_pattern = re.compile(r'^\s{8}self\._ctrl\.enterBattle\(tankID\)\s*$', re.MULTILINE)
enter_replacement = (
    "        # Masters is hangar-only. Keep the baseline snapshot for history,\n"
    "        # but do not enter battle mode or bind battle feedback/UI.\n"
    "        logger.debug('masters: baseline snapshot captured for tankID=%s', tankID)\n"
    "        return"
)
text, enter_count = enter_pattern.subn(enter_replacement, text, count=1)

# Remove all runtime installation/uninstallation of battle hooks. The helper
# functions can remain temporarily as unreachable compatibility code; this
# avoids a risky large-file rewrite while guaranteeing no duplicate hooks when
# Masters and Marks are installed together.
init_pattern = re.compile(
    r'def init\(\):\n'
    r'    try:\n'
    r'(?:        .*\n)*?'
    r'        _g_mod_mastery_moe\.init\(\)\n'
    r'    except Exception:\n'
    r"        logger\.exception\('init failed'\)\n\n\n"
    r'def fini\(\):\n'
    r'    try:\n'
    r'(?:        .*\n)*?'
    r'    except Exception:\n'
    r"        logger\.exception\('fini failed'\)",
    re.MULTILINE,
)
new_init = '''def init():
    try:
        # Masters is hangar-only. Marks owns all live-battle tracking.
        _g_mod_mastery_moe.init()
    except Exception:
        logger.exception('init failed')


def fini():
    try:
        _g_mod_mastery_moe.fini()
    except Exception:
        logger.exception('fini failed')'''
text, init_count = init_pattern.subn(new_init, text, count=1)

required = [
    "return {'mode': 'mastery', 'badgeStyle': 'classic'}",
    '_configMarkBadge = False',
    '_battleBadgeEnabled = False',
    'masters: baseline snapshot captured',
    '# Masters is hangar-only. Marks owns all live-battle tracking.',
]
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit('Missing expected Masters guards: ' + ', '.join(missing))

# Check the actual public lifecycle functions, not merely the presence of guard
# strings elsewhere in the file.
init_tail = text[text.rfind('\ndef init():') + 1:]
for forbidden in (
    '_installBattleSummaryHook()',
    '_installVehicleDamageHooks()',
    '_installShowExtendedInfoHook()',
    '_uninstallVehicleDamageHooks()',
    '_uninstallBattleSummaryHook()',
    '_uninstallShowExtendedInfoHook()',
):
    if forbidden in init_tail:
        raise SystemExit('Active battle hook remains in Masters lifecycle: ' + forbidden)

if re.search(r'^\s{8}self\._ctrl\.enterBattle\(tankID\)\s*$', text, re.MULTILINE):
    raise SystemExit('Active enterBattle call remains in Masters')

if text == original:
    print('Masters Python already finalized; no changes needed')
else:
    TARGET.write_text(text, encoding='utf-8')
    print('Masters Python finalized successfully (enterBattle=%d, lifecycle=%d)' % (
        enter_count, init_count))
