from pathlib import Path
import argparse, shutil, re


def copy_source(source, dest):
    source, dest = Path(source), Path(dest)
    for item in source.iterdir():
        if item.name == '.git':
            continue
        target = dest / item.name
        if target.exists():
            if target.is_dir(): shutil.rmtree(target)
            else: target.unlink()
        if item.is_dir(): shutil.copytree(item, target)
        else: shutil.copy2(item, target)


def masters(root):
    root=Path(root)
    py=root/'python/gui/mods/mod_under_pressure_mastery.py'
    s=py.read_text(encoding='utf-8')
    a=s.index('def _loadConfigFile():'); b=s.index('\ndef _isCloseBrowserMethod',a)
    s=s[:a]+"def _loadConfigFile():\n    return {'mode': 'mastery', 'badgeStyle': 'classic'}\n\n\n"+s[b+1:]
    a=s.index('def _registerFlash():'); b=s.index('\n\nclass MasteryController',a)
    s=s[:a]+'''def _registerFlash():
    g_entitiesFactories.addSettings(ViewSettings(
        _LINKAGE_HANGAR, MasteryPanelHangarView, _SWF_HANGAR,
        WindowLayer.WINDOW, None, ScopeTemplates.GLOBAL_SCOPE
    ))


def _unregisterFlash():
    try:
        g_entitiesFactories.removeSettings(_LINKAGE_HANGAR)
    except Exception:
        pass


'''+s[b+2:]
    a=s.index('    def _loadConfig(self):'); b=s.index('\n    def _scheduleSaveCache',a)
    s=s[:a]+'''    def _loadConfig(self):
        self._configEnabled = True
        self._configGaragePanelMode = _DEFAULT_VIEW_MODE
        self._configMarkBadge = False
        self._configPanelBodyVisible = True
        self._viewMode = _DEFAULT_VIEW_MODE
        self._configBadgeStyle = 0
        self._markBadgeOpen = False
        self._battleBadgeEnabled = False
        self._detailOpen = False

'''+s[b:]
    pat=re.compile(r'    def _onExpandToggle\(self\):\n.*?(?=\n    def )',re.S)
    m=pat.search(s)
    if m:
        s=s[:m.start()]+'''    def _onExpandToggle(self):
        self._detailOpen = False
        try:
            if self._injectorView:
                self._injectorView.flashObject.as_showDetail(False)
        except Exception:
            pass

'''+s[m.end():]
    py.write_text(s,encoding='utf-8')
    for rel in ['as3/src_flash/MasteryPanelBattle.as3proj','as3/src_flash/MasteryPanelResults.as3proj','as3/src_flash/MasteryPanel.as3proj','as3/src_flash/src/com/under_pressure/mastery/MasteryPanelBattle.as','as3/src_flash/src/com/under_pressure/mastery/MasteryPanelResults.as','as3/src_flash/src/com/under_pressure/mastery/MasteryBattleResultBadge.as']:
        p=root/rel
        if p.exists(): p.unlink()
    (root/'README.md').write_text('# Masters\n\nGarage mastery panel, mastery thresholds and progress graph. Marks configuration and the old best-battle/results panels are disabled.\n',encoding='utf-8')
    wf=root/'.github/workflows/release.yml'
    t=wf.read_text(encoding='utf-8').replace("default: 'mastery_under_inq'","default: 'me.under_pressure.masters'").replace('$modId = "me.under_pressure.mastery"','$modId = "me.under_pressure.masters"').replace('$modName = "mastery"','$modName = "masters"').replace('$modDescription = "mastery"','$modDescription = "Masters"')
    wf.write_text(t,encoding='utf-8')


def marks(root):
    root=Path(root)
    old=root/'python/gui/mods/mod_under_pressure_mastery.py'; new=root/'python/gui/mods/mod_under_pressure_marks.py'
    s=old.read_text(encoding='utf-8')
    s=s.replace("logger = logging.getLogger('under_pressure.mastery')","logger = logging.getLogger('under_pressure.marks')").replace("_L10N_DIR = 'mods/under_pressure.mastery'","_L10N_DIR = 'mods/under_pressure.marks'").replace("'mods', 'mastery'","'mods', 'marks'").replace("'mods', 'configs', 'mastery'","'mods', 'configs', 'marks'").replace("'mastery.json'","'marks.json'")
    for x,y in [('MasteryPanelHangar','MarksPanelHangar'),('MasteryPanelBattle','MarksPanelBattle'),('MasteryPanelResults','MarksPanelResults')]: s=s.replace(x,y)
    a=s.index('_CONFIG_DEFAULTS = {'); b=s.index('\n_CONFIG_MODES =',a)
    s=s[:a]+'''_CONFIG_DEFAULTS = {
    'garageBadgeStyle': 'classic',
    'battleBadgeStyle': 'classic',
    'garageBadgeStyles': {'classic':'garage style 1','compact':'garage style 2','polaroid':'garage style 3'},
    'battleBadgeStyles': {'classic':'battle style 1','compact':'battle style 2','polaroid':'battle style 3','neer':'battle style 4','minimal':'battle style 5'},
}
'''+s[b:]
    a=s.index('def _loadConfigFile():'); b=s.index('\ndef _isCloseBrowserMethod',a)
    s=s[:a]+'''def _loadConfigFile():
    _ensureConfigDir()
    loaded = {}
    changed = False
    if os.path.isfile(_CONFIG_FILE):
        try:
            with open(_CONFIG_FILE, 'rb') as fh: loaded = json.load(fh)
            if not isinstance(loaded, dict): loaded = {}; changed = True
        except Exception: loaded = {}; changed = True
    else: changed = True
    garage = _safeLower(loaded.get('garageBadgeStyle'))
    battle = _safeLower(loaded.get('battleBadgeStyle'))
    if garage not in ('classic','compact','polaroid'): garage='classic'; changed=True
    if battle not in _CONFIG_BADGE_STYLES: battle='classic'; changed=True
    config=dict(_CONFIG_DEFAULTS); config['garageBadgeStyle']=garage; config['battleBadgeStyle']=battle
    if loaded != config: changed=True
    if changed:
        try:
            with open(_CONFIG_FILE,'wb') as fh: json.dump(config,fh,indent=4,sort_keys=True)
        except Exception: logger.exception('config: failed to write defaults')
    return config


'''+s[b+1:]
    a=s.index('def _registerFlash():'); b=s.index('\n\nclass MasteryController',a)
    s=s[:a]+'''def _registerFlash():
    for linkage, viewCls, swf in ((_LINKAGE_HANGAR, MarksPanelHangarView, _SWF_HANGAR),(_LINKAGE_BATTLE, MarksPanelBattleView, _SWF_BATTLE)):
        g_entitiesFactories.addSettings(ViewSettings(linkage, viewCls, swf, WindowLayer.WINDOW, None, ScopeTemplates.GLOBAL_SCOPE))


def _unregisterFlash():
    for linkage in (_LINKAGE_HANGAR, _LINKAGE_BATTLE):
        try: g_entitiesFactories.removeSettings(linkage)
        except Exception: pass


'''+s[b+2:]
    a=s.index('    def _loadConfig(self):'); b=s.index('\n    def _scheduleSaveCache',a)
    s=s[:a]+'''    def _loadConfig(self):
        config = _loadConfigFile()
        self._configEnabled = True
        self._configGaragePanelMode = 2
        self._configMarkBadge = True
        self._configPanelBodyVisible = False
        self._viewMode = 2
        garageName = _safeLower(config.get('garageBadgeStyle'))
        battleName = _safeLower(config.get('battleBadgeStyle'))
        if garageName not in ('classic','compact','polaroid'): garageName='classic'
        if battleName not in _CONFIG_BADGE_STYLES: battleName='classic'
        self._configBadgeStyle = int(_CONFIG_BADGE_STYLES.get(garageName,0))
        self._configBattleBadgeStyle = int(_CONFIG_BADGE_STYLES.get(battleName,0))
        self._markBadgeOpen = True
        self._battleBadgeEnabled = True
        self._detailOpen = False

'''+s[b:]
    s=s.replace('        self._configBadgeStyle = 0\n        self._cachedBadgeStyle = None','        self._configBadgeStyle = 0\n        self._configBattleBadgeStyle = 0\n        self._cachedBadgeStyle = None').replace('as_setBattleBadgeStyle(int(self._configBadgeStyle))','as_setBattleBadgeStyle(int(self._configBattleBadgeStyle))')
    new.write_text(s,encoding='utf-8'); old.unlink()
    d=root/'as3/src_flash/src/com/under_pressure/mastery'
    for p in list(d.glob('*.as'))+list((root/'as3/src_flash').glob('*.as3proj')):
        t=p.read_text(encoding='utf-8')
        for x,y in [('MasteryPanelHangar','MarksPanelHangar'),('MasteryPanelBattle','MarksPanelBattle'),('MasteryPanelResults','MarksPanelResults')]: t=t.replace(x,y)
        p.write_text(t,encoding='utf-8')
    for x,y in [('MasteryPanelHangar.as','MarksPanelHangar.as'),('MasteryPanelBattle.as','MarksPanelBattle.as'),('MasteryPanelResults.as','MarksPanelResults.as')]:
        p=d/x
        if p.exists(): p.rename(d/y)
    for x,y in [('MasteryPanelHangar.as3proj','MarksPanelHangar.as3proj'),('MasteryPanelBattle.as3proj','MarksPanelBattle.as3proj'),('MasteryPanelResults.as3proj','MarksPanelResults.as3proj')]:
        p=root/'as3/src_flash'/x
        if p.exists(): p.rename(p.with_name(y))
    for rel in ['as3/src_flash/MarksPanelResults.as3proj','as3/src_flash/MasteryPanel.as3proj','as3/src_flash/src/com/under_pressure/mastery/MarksPanelResults.as','as3/src_flash/src/com/under_pressure/mastery/MasteryBattleResultBadge.as','as3/src_flash/src/com/under_pressure/mastery/MasteryDetailPanel.as']:
        p=root/rel
        if p.exists(): p.unlink()
    oldres=root/'resources/in/mods/under_pressure.mastery'; newres=root/'resources/in/mods/under_pressure.marks'
    if oldres.exists(): oldres.rename(newres)
    (root/'README.md').write_text('# Marks\n\nStandalone marks-of-excellence mod. Config: `<game>/mods/configs/marks/marks.json`.\n\nGarage styles: `classic`, `compact`, `polaroid`. Battle styles: `classic`, `compact`, `polaroid`, `neer`, `minimal`.\n',encoding='utf-8')
    wf=root/'.github/workflows/release.yml'
    t=wf.read_text(encoding='utf-8').replace("default: 'mastery_under_inq'","default: 'me.under_pressure.marks'").replace('$modId = "me.under_pressure.mastery"','$modId = "me.under_pressure.marks"').replace('$modName = "mastery"','$modName = "marks"').replace('$modDescription = "mastery"','$modDescription = "Marks"')
    wf.write_text(t,encoding='utf-8')

if __name__=='__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--target',choices=['masters','marks'],required=True); ap.add_argument('--root',default='.'); ap.add_argument('--source')
    a=ap.parse_args()
    if a.source: copy_source(a.source,a.root)
    (masters if a.target=='masters' else marks)(a.root)
