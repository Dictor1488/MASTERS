# -*- coding: utf-8 -*-
"""GameFace mastery statistics rebuilt from the current MARKS statistics bridge."""
import json
import logging
import re

import BigWorld
from gui.shared.personality import ServicesLocator

try:
    import GUI
except Exception:
    GUI = None

try:
    from frameworks.wulf import (ViewModel, ViewSettings, ViewFlags,
                                 WindowFlags, WindowLayer, PositionAnchor)
    from gui.impl.pub import ViewImpl, WindowImpl
    from openwg_gameface import ModDynAccessor
    _AVAILABLE = True
except Exception:
    _AVAILABLE = False

try:
    from gui.mods import mod_under_pressure_mastery as _core
except Exception:
    _core = None

_logger = logging.getLogger('under_pressure.masters.stats')
STATS_RES_ID = 'UnderPressureMasteryTankStatsView'
_statsActive = None
_refreshCallbacks = []
_statsSampleLogged = False


def _controller():
    try:
        return _core._g_mod._controller if _core is not None else None
    except Exception:
        return None


def _safe_int(value, default=0):
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return default


def _safe_text(value, default=u''):
    if value is None:
        return default
    try:
        return unicode(value)
    except Exception:
        try:
            return unicode(str(value), 'utf-8', 'ignore')
        except Exception:
            return default


def _clean_vehicle_name(value):
    text = _safe_text(value, u'')
    if not text:
        return u''
    text = re.sub(u'<[^>]*>', u'', text)
    return text.replace(u'&nbsp;', u' ').strip()


def _tank_cache_get(container, tankID, default=None):
    if not isinstance(container, dict):
        return default
    for key in (tankID, str(tankID), unicode(tankID)):
        try:
            if key in container:
                return container.get(key)
        except Exception:
            pass
    return default


def _vehicle_type(item):
    tags = getattr(item, 'tags', None)
    if tags:
        for src, dst in (('lightTank', 'lighttank'), ('mediumTank', 'mediumtank'),
                         ('heavyTank', 'heavytank'), ('AT-SPG', 'at-spg'), ('SPG', 'spg')):
            try:
                if src in tags:
                    return dst
            except Exception:
                pass
    for attr in ('type', 'vehicleType', 'classTag'):
        value = _safe_text(getattr(item, attr, u'')).lower()
        for key in ('lighttank', 'mediumtank', 'heavytank', 'at-spg', 'spg'):
            if key in value:
                return key
    return u'unknown'


def _nation(item):
    value = getattr(item, 'nationName', None)
    if value:
        return _safe_text(value).lower()
    descriptor = getattr(item, 'descriptor', None)
    value = getattr(descriptor, 'nationName', None) if descriptor is not None else None
    if value:
        return _safe_text(value).lower()
    nationID = getattr(item, 'nationID', None)
    try:
        from nations import NAMES
        return _safe_text(NAMES[int(nationID)]).lower()
    except Exception:
        return u'unknown'


def _vehicle_name(item, tankID=0):
    # Kept intentionally identical to current MARKS resolver.
    for attr in ('userName', 'shortUserName', 'getUserName', 'getShortUserName', 'getName', 'name'):
        value = getattr(item, attr, None)
        try:
            value = value() if callable(value) else value
        except Exception:
            value = None
        text = _clean_vehicle_name(value) if value else u''
        if text:
            if attr == 'name':
                text = text.split(':')[-1].replace('_', ' ')
            return text
    descriptor = getattr(item, 'descriptor', None)
    value = getattr(descriptor, 'userString', None) if descriptor is not None else None
    if not value and descriptor is not None:
        value = getattr(getattr(descriptor, 'type', None), 'userString', None)
    if not value and tankID:
        try:
            from items import vehicles
            vehicleType = vehicles.getVehicleType(int(tankID))
            for attr in ('shortUserString', 'userString', 'name'):
                value = getattr(vehicleType, attr, None)
                if value:
                    break
        except Exception:
            value = None
    text = _clean_vehicle_name(value)
    if not text:
        try:
            text = _safe_text(getattr(item, 'name', u'')).split(':')[-1].replace('_', ' ').strip()
        except Exception:
            text = u''
    return text or (u'#%d' % int(tankID) if tankID else u'—')


def _is_owned(item):
    try:
        value = getattr(item, 'isInInventory', False)
        return bool(value() if callable(value) else value)
    except Exception:
        return False


class _RegistryVehicle(object):
    """Adapter copied from MARKS for vehicles absent from itemsCache."""
    def __init__(self, descriptor, compactDescr, nationID):
        self.descriptor = descriptor
        self.compactDescr = int(compactDescr)
        self.intCD = int(compactDescr)
        self.nationID = int(nationID)

    def __getattr__(self, name):
        return getattr(self.descriptor, name)


def _registry_vehicle_items(knownIDs):
    result = []
    try:
        from items import vehicles
        from nations import NAMES
        registry = getattr(vehicles, 'g_list', None)
        if registry is None:
            return result
        for nationID in xrange(len(NAMES)):
            try:
                nationList = registry.getList(nationID)
            except Exception:
                continue
            if isinstance(nationList, dict):
                entries = nationList.iteritems()
            else:
                try:
                    entries = enumerate(nationList or ())
                except Exception:
                    continue
            for itemID, descriptor in entries:
                if descriptor is None:
                    continue
                if isinstance(descriptor, (tuple, list)) and descriptor:
                    descriptor = descriptor[-1]
                compactDescr = _safe_int(getattr(descriptor, 'compactDescr', getattr(descriptor, 'intCD', 0)))
                if compactDescr <= 0:
                    try:
                        compactDescr = int(vehicles.makeIntCompactDescrByID('vehicle', int(nationID), int(itemID)))
                    except Exception:
                        continue
                if not any(hasattr(descriptor, attr) for attr in ('tags', 'userString', 'level')):
                    try:
                        descriptor = vehicles.getVehicleType(compactDescr)
                    except Exception:
                        continue
                if compactDescr in knownIDs:
                    continue
                knownIDs.add(compactDescr)
                result.append(_RegistryVehicle(descriptor, compactDescr, nationID))
    except Exception:
        _logger.exception('Failed to enumerate full vehicle registry')
    return result


def _vehicle_tags(item):
    tags = set()
    sources = (item, getattr(item, 'descriptor', None), getattr(getattr(item, 'descriptor', None), 'type', None))
    for source in sources:
        if source is None:
            continue
        try:
            for value in (getattr(source, 'tags', ()) or ()):
                tags.add(_safe_text(value).lower().replace('-', '_'))
        except Exception:
            pass
    return tags


def _is_regular_stats_vehicle(item):
    for attr in ('isOnlyForBattleRoyale', 'isOnlyForEpicBattles', 'isOnlyForEventBattles', 'isOnlyForMapsTraining'):
        try:
            value = getattr(item, attr, False)
            if bool(value() if callable(value) else value):
                return False
        except Exception:
            pass
    modeTags = {'battle_royale','battle_royale_vehicles','epic_battle','epic_battles','event_battle','event_battles','maps_training','mapbox','fun_random','battleroyale','epicbattle','eventbattle','mapstraining','funrandom','comp7','onslaught','wt_boss','wt_hunter','observer','bot'}
    tags = _vehicle_tags(item)
    if tags.intersection(modeTags):
        return False
    for tag in tags:
        if ('battle_royale' in tag or 'battleroyale' in tag or 'event_battle' in tag or
                'eventbattle' in tag or 'maps_training' in tag or 'mapstraining' in tag or 'wt_' in tag):
            return False
    return True


def _all_vehicle_items():
    try:
        items = ServicesLocator.itemsCache.items
        try:
            from gui.shared.utils.requesters import REQ_CRITERIA
            vehicles = items.getVehicles(REQ_CRITERIA.EMPTY)
        except Exception:
            vehicles = items.getVehicles()
        result = list(vehicles.itervalues()) if isinstance(vehicles, dict) else list(vehicles or ())
        knownIDs = set()
        for item in result:
            tankID = _safe_int(getattr(item, 'intCD', getattr(item, 'compactDescr', 0)))
            if tankID > 0:
                knownIDs.add(tankID)
        result.extend(_registry_vehicle_items(knownIDs))
        return result
    except Exception:
        _logger.exception('Failed to enumerate client vehicles')
        return []


def _dossier_for_item(item, tankID):
    if tankID <= 0:
        return None
    try:
        getter = getattr(ServicesLocator.itemsCache.items, 'getVehicleDossier', None)
        if callable(getter):
            dossier = getter(int(tankID))
            if dossier is not None:
                return dossier
    except Exception:
        pass
    try:
        getter = getattr(item, 'getDossier', None)
        if callable(getter):
            return getter()
    except Exception:
        pass
    return None


def _read_mastery(item, tankID):
    dossier = _dossier_for_item(item, tankID)
    if dossier is None:
        return 0
    for section in ('achievements', 'total', 'a15x15'):
        for key in ('markOfMastery', 'mastery'):
            try:
                value = _safe_int(dossier.getRecordValue(section, key), -1)
                if 0 <= value <= 4:
                    return value
            except Exception:
                pass
    try:
        value = _safe_int(getattr(dossier.getAchievements(), 'markOfMastery', 0), 0)
        return value if 0 <= value <= 4 else 0
    except Exception:
        return 0


def _xp_for(ctrl, tankID):
    return _tank_cache_get(getattr(ctrl, '_xpCache', {}), tankID, {}) or {}


def _build_rows():
    ctrl = _controller()
    if ctrl is None:
        return []
    rows, seen = [], set()
    for item in _all_vehicle_items():
        tankID = _safe_int(getattr(item, 'intCD', getattr(item, 'compactDescr', 0)))
        if tankID <= 0 or tankID in seen:
            continue
        seen.add(tankID)
        level = _safe_int(getattr(item, 'level', 0))
        if level < 5 or not _is_regular_stats_vehicle(item):
            continue
        name = _vehicle_name(item, tankID)
        xp = _xp_for(ctrl, tankID)
        rows.append({'id':tankID,'name':name,'vehicleName':name,'level':level,
                     'type':_vehicle_type(item),'nation':_nation(item),'owned':_is_owned(item),
                     'mastery':_read_mastery(item,tankID),
                     'thirdClass':_safe_int(xp.get('thirdClass'),0),
                     'secondClass':_safe_int(xp.get('secondClass'),0),
                     'firstClass':_safe_int(xp.get('firstClass'),0),
                     'aceTanker':_safe_int(xp.get('aceTanker'),0)})
    rows.sort(key=lambda row: (-row['level'], row['nation'], row['name'].lower()))
    return rows


def _payload():
    global _statsSampleLogged
    rows = _build_rows()
    if rows and not _statsSampleLogged:
        _statsSampleLogged = True
        sample = rows[0]
        _logger.warning('Stats payload sample: id=%s name=%r vehicleName=%r', sample.get('id'), sample.get('name'), sample.get('vehicleName'))
    return json.dumps({'rows': rows, 'total': len(rows)}, ensure_ascii=False, separators=(',', ':'))


if _AVAILABLE:
    class StatsVM(ViewModel):
        __slots__ = ('onClose','onNeedThresholds')
        def __init__(self):
            super(StatsVM,self).__init__(properties=3,commands=2)
        def _initialize(self):
            super(StatsVM,self)._initialize()
            self._addStringProperty('payload','{"rows":[],"total":0}')
            self._addNumberProperty('surfaceWidth',1280)
            self._addNumberProperty('surfaceHeight',720)
            self.onClose=self._addCommand('onClose')
            self.onNeedThresholds=self._addCommand('onNeedThresholds')
        def setPayload(self,payload): self._setString(0,_safe_text(payload))
        def setSurfaceSize(self,w,h): self._setNumber(1,int(w)); self._setNumber(2,int(h))

    class StatsView(ViewImpl):
        _layoutID=ModDynAccessor(STATS_RES_ID)
        def __init__(self):
            super(StatsView,self).__init__(ViewSettings(self._layoutID(),ViewFlags.VIEW,StatsVM()))
        @property
        def viewModel(self): return super(StatsView,self).getViewModel()
        def _getEvents(self):
            return ((self.viewModel.onClose,self._onClose),(self.viewModel.onNeedThresholds,self._onNeedThresholds))
        def _onClose(self,*args,**kwargs): close_stats()
        def _onNeedThresholds(self,args=None,*unused,**kwargs):
            request_thresholds(args.get('ids','') if isinstance(args,dict) else '')

    class StatsWindow(WindowImpl):
        def __init__(self,content):
            super(StatsWindow,self).__init__(WindowFlags.WINDOW,content=content,layer=WindowLayer.WINDOW)
        def _onReady(self):
            self.show(focus=True)
            try: self.move(0,0,xAnchor=PositionAnchor.LEFT,yAnchor=PositionAnchor.TOP)
            except Exception: pass
            try: BigWorld.callback(0.0,refresh_stats)
            except Exception: refresh_stats()


def _surface_size():
    try:
        w,h=GUI.screenResolution()
        return max(1240,int(w)),max(760,int(h))
    except Exception:
        return 1240,760


def open_stats():
    global _statsActive
    ctrl=_controller()
    if not _AVAILABLE or ctrl is None or not getattr(ctrl,'_hangarVisible',False): return None
    if _statsActive is None:
        try:
            view=StatsView(); window=StatsWindow(view); _statsActive=(window,view); window.load()
        except Exception:
            _statsActive=None; _logger.exception('Failed to open mastery statistics'); return None
    else: refresh_stats()
    return _statsActive[1]


def close_stats():
    global _statsActive
    if _statsActive is None: return
    window=_statsActive[0]; _statsActive=None
    try: window.destroy()
    except Exception: pass


def refresh_stats():
    if _statsActive is None: return
    try:
        w,h=_surface_size()
        with _statsActive[1].viewModel.transaction() as vm:
            vm.setPayload(_payload()); vm.setSurfaceSize(w,h)
    except Exception:
        _logger.exception('Mastery statistics refresh failed')


def _scheduled_refresh(holder):
    try:
        if holder[0] in _refreshCallbacks: _refreshCallbacks.remove(holder[0])
    except Exception: pass
    refresh_stats()


def _schedule_refresh(delay):
    try:
        holder=[None]; holder[0]=BigWorld.callback(delay,lambda:_scheduled_refresh(holder)); _refreshCallbacks.append(holder[0])
    except Exception: pass


def request_thresholds(rawIDs):
    ctrl=_controller()
    if ctrl is None: return
    requested=0
    for token in _safe_text(rawIDs).split(','):
        tankID=_safe_int(token.strip())
        if tankID<=0: continue
        xp=_xp_for(ctrl,tankID)
        if all(_safe_int(xp.get(k),0)>0 for k in ('thirdClass','secondClass','firstClass','aceTanker')): continue
        try:
            ctrl._requestDistribution(tankID,'xp',generation=getattr(ctrl,'_vehicleGeneration',0)); requested+=1
        except Exception: pass
        if requested>=50: break
    if requested:
        for delay in (1.0,2.5,5.0): _schedule_refresh(delay)


def init():
    pass


def fini():
    for cbid in _refreshCallbacks[:]:
        try: BigWorld.cancelCallback(cbid)
        except Exception: pass
    del _refreshCallbacks[:]
    close_stats()
