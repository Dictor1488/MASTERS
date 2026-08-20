# -*- coding: utf-8 -*-
"""Clean GameFace statistics window for Under Pressure Masters."""
import json
import logging

import BigWorld
from gui.shared.personality import ServicesLocator

try:
    import GUI
except Exception:
    GUI = None

try:
    from helpers import i18n
except Exception:
    i18n = None

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


def _safe_int(value, default=0):
    try:
        return int(round(float(value)))
    except Exception:
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


def _controller():
    try:
        return _core._g_mod._controller if _core is not None else None
    except Exception:
        return None


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
    value = _safe_text(getattr(item, 'type', u''), u'').lower()
    for key in ('lighttank', 'mediumtank', 'heavytank', 'at-spg', 'spg'):
        if key in value:
            return key
    return u'unknown'


def _nation(item):
    for source in (getattr(item, 'nationName', None),
                   getattr(getattr(item, 'descriptor', None), 'nationName', None)):
        text = _safe_text(source, u'').strip().lower()
        if text:
            return text
    try:
        from nations import NAMES
        return _safe_text(NAMES[int(getattr(item, 'nationID', -1))], u'unknown').lower()
    except Exception:
        return u'unknown'


def _vehicle_type_descr(item, tankID):
    descriptor = getattr(item, 'descriptor', None)
    vehicleType = getattr(descriptor, 'type', None) if descriptor is not None else None
    if vehicleType is not None:
        return vehicleType
    try:
        from items import vehicles
        return vehicles.getVehicleType(int(tankID))
    except Exception:
        return None


def _localized(raw):
    text = _safe_text(raw, u'').strip()
    if not text:
        return u''
    if text.startswith('#') and i18n is not None:
        try:
            localized = _safe_text(i18n.makeString(text), u'').strip()
            if localized and not localized.startswith('#'):
                return localized
        except Exception:
            pass
    return text if not text.startswith('#') else u''


def _vehicle_name(item, tankID):
    """Return a visible tank name without relying on GameFace to resolve i18n keys."""
    for attr in ('userName', 'shortUserName', 'getUserName', 'getShortUserName'):
        try:
            value = getattr(item, attr, u'')
            value = value() if callable(value) else value
        except Exception:
            value = u''
        text = _localized(value)
        if text:
            return text

    vehicleType = _vehicle_type_descr(item, tankID)
    if vehicleType is not None:
        for attr in ('userString', 'shortUserString'):
            text = _localized(getattr(vehicleType, attr, u''))
            if text:
                return text

    for source in (getattr(item, 'name', u''),
                   getattr(vehicleType, 'name', u'') if vehicleType is not None else u''):
        text = _safe_text(source, u'').strip()
        if not text:
            continue
        if ':' in text:
            text = text.split(':', 1)[1]
        text = text.replace('_', ' ').strip()
        if text:
            return text
    return u'#%d' % int(tankID)


def _is_owned(item):
    for attr in ('isInInventory',):
        try:
            value = getattr(item, attr, False)
            value = value() if callable(value) else value
            if value:
                return True
        except Exception:
            pass
    for attr in ('inventoryCount', 'invID'):
        if _safe_int(getattr(item, attr, 0), 0) > 0:
            return True
    return False


def _all_vehicle_items():
    try:
        items = ServicesLocator.itemsCache.items
        try:
            from gui.shared.utils.requesters import REQ_CRITERIA
            vehicles = items.getVehicles(REQ_CRITERIA.EMPTY)
        except Exception:
            vehicles = items.getVehicles()
        return list(vehicles.itervalues()) if isinstance(vehicles, dict) else list(vehicles or ())
    except Exception:
        _logger.exception('Failed to enumerate vehicles for mastery statistics')
        return []


def _dossier_for_item(item, tankID):
    if tankID <= 0:
        return None
    try:
        from CurrentVehicle import g_currentVehicle
        if g_currentVehicle.isPresent():
            current = g_currentVehicle.item
            currentID = _safe_int(getattr(current, 'intCD', getattr(current, 'compactDescr', 0)))
            if currentID == tankID:
                dossier = g_currentVehicle.getDossier()
                if dossier is not None:
                    return dossier
    except Exception:
        pass
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
            dossier = getter()
            if dossier is not None:
                return dossier
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
        if 0 <= value <= 4:
            return value
    except Exception:
        pass
    return 0


def _xp_for(ctrl, tankID):
    return _tank_cache_get(getattr(ctrl, '_xpCache', {}), tankID, {}) or {}


def _build_rows():
    ctrl = _controller()
    if ctrl is None:
        return []
    rows = []
    seen = set()
    for item in _all_vehicle_items():
        tankID = _safe_int(getattr(item, 'intCD', getattr(item, 'compactDescr', 0)))
        if tankID <= 0 or tankID in seen:
            continue
        seen.add(tankID)
        level = _safe_int(getattr(item, 'level', 0))
        if level < 5:
            continue
        name = _vehicle_name(item, tankID)
        xp = _xp_for(ctrl, tankID)
        rows.append({
            'id': tankID,
            'name': name,
            'vehicleName': name,
            'level': level,
            'type': _vehicle_type(item),
            'nation': _nation(item),
            'owned': _is_owned(item),
            'mastery': _read_mastery(item, tankID),
            'thirdClass': _safe_int(xp.get('thirdClass'), 0),
            'secondClass': _safe_int(xp.get('secondClass'), 0),
            'firstClass': _safe_int(xp.get('firstClass'), 0),
            'aceTanker': _safe_int(xp.get('aceTanker'), 0),
        })
    rows.sort(key=lambda row: (-row['level'], row['nation'], row['name'].lower()))
    return rows


def _payload():
    rows = _build_rows()
    return json.dumps({'rows': rows, 'total': len(rows)}, ensure_ascii=False, separators=(',', ':'))


if _AVAILABLE:
    class StatsVM(ViewModel):
        __slots__ = ('onClose', 'onNeedThresholds')

        def __init__(self):
            super(StatsVM, self).__init__(properties=3, commands=2)

        def _initialize(self):
            super(StatsVM, self)._initialize()
            self._addStringProperty('payload', '{"rows":[],"total":0}')
            self._addNumberProperty('surfaceWidth', 1240)
            self._addNumberProperty('surfaceHeight', 760)
            self.onClose = self._addCommand('onClose')
            self.onNeedThresholds = self._addCommand('onNeedThresholds')

        def setPayload(self, payload):
            self._setString(0, _safe_text(payload))

        def setSurfaceSize(self, width, height):
            self._setNumber(1, int(width))
            self._setNumber(2, int(height))


    class StatsView(ViewImpl):
        _layoutID = ModDynAccessor(STATS_RES_ID)

        def __init__(self):
            super(StatsView, self).__init__(ViewSettings(self._layoutID(), ViewFlags.VIEW, StatsVM()))

        @property
        def viewModel(self):
            return super(StatsView, self).getViewModel()

        def _getEvents(self):
            return ((self.viewModel.onClose, self._onClose),
                    (self.viewModel.onNeedThresholds, self._onNeedThresholds))

        def _onClose(self, *args, **kwargs):
            close_stats()

        def _onNeedThresholds(self, args=None, *unused, **kwargs):
            request_thresholds(args.get('ids', '') if isinstance(args, dict) else '')


    class StatsWindow(WindowImpl):
        def __init__(self, content):
            super(StatsWindow, self).__init__(WindowFlags.WINDOW, content=content, layer=WindowLayer.WINDOW)

        def _onReady(self):
            self.show(focus=True)
            try:
                self.move(0, 0, xAnchor=PositionAnchor.LEFT, yAnchor=PositionAnchor.TOP)
            except Exception:
                pass
            try:
                BigWorld.callback(0.0, refresh_stats)
            except Exception:
                refresh_stats()


def _surface_size():
    try:
        width, height = GUI.screenResolution()
        return max(1240, int(width)), max(760, int(height))
    except Exception:
        return 1240, 760


def open_stats():
    global _statsActive
    ctrl = _controller()
    if not _AVAILABLE or ctrl is None or not getattr(ctrl, '_hangarVisible', False):
        return None
    if _statsActive is None:
        try:
            layout = StatsView._layoutID()
            if layout is None or layout < 0:
                return None
            view = StatsView()
            window = StatsWindow(view)
            _statsActive = (window, view)
            window.load()
        except Exception:
            _statsActive = None
            _logger.exception('Failed to open mastery statistics')
            return None
    else:
        refresh_stats()
    return _statsActive[1]


def close_stats():
    global _statsActive
    if _statsActive is None:
        return
    window = _statsActive[0]
    _statsActive = None
    try:
        window.destroy()
    except Exception:
        pass


def refresh_stats():
    if _statsActive is None:
        return
    try:
        width, height = _surface_size()
        with _statsActive[1].viewModel.transaction() as vm:
            vm.setPayload(_payload())
            vm.setSurfaceSize(width, height)
    except Exception:
        _logger.exception('Mastery statistics refresh failed')


def _scheduled_refresh(holder):
    try:
        if holder[0] in _refreshCallbacks:
            _refreshCallbacks.remove(holder[0])
    except Exception:
        pass
    refresh_stats()


def _schedule_refresh(delay):
    try:
        holder = [None]
        holder[0] = BigWorld.callback(delay, lambda: _scheduled_refresh(holder))
        _refreshCallbacks.append(holder[0])
    except Exception:
        pass


def request_thresholds(rawIDs):
    ctrl = _controller()
    if ctrl is None:
        return
    requested = 0
    for token in _safe_text(rawIDs).split(','):
        tankID = _safe_int(token.strip())
        if tankID <= 0:
            continue
        xp = _xp_for(ctrl, tankID)
        if all(_safe_int(xp.get(k), 0) > 0 for k in
               ('thirdClass', 'secondClass', 'firstClass', 'aceTanker')):
            continue
        try:
            ctrl._requestDistribution(tankID, 'xp', generation=getattr(ctrl, '_vehicleGeneration', 0))
            requested += 1
        except Exception:
            pass
        if requested >= 50:
            break
    if requested:
        for delay in (1.0, 2.5, 5.0):
            _schedule_refresh(delay)


def init():
    pass


def fini():
    for cbid in _refreshCallbacks[:]:
        try:
            BigWorld.cancelCallback(cbid)
        except Exception:
            pass
    del _refreshCallbacks[:]
    close_stats()
