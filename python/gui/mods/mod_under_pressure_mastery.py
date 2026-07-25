# -*- coding: utf-8 -*-
import cPickle
import functools
import json
import logging
import os
import time
import zlib
from collections import deque

import BigWorld
import constants
from Account import PlayerAccount
from CurrentVehicle import g_currentVehicle
from PlayerEvents import g_playerEvents
from gui.Scaleform.framework import g_entitiesFactories, ScopeTemplates, ViewSettings
from gui.Scaleform.framework.entities.View import View
from gui.Scaleform.framework.managers.loaders import SFViewLoadParams
from gui.Scaleform.lobby_entry import getLobbyStateMachine
from gui.shared.personality import ServicesLocator
from frameworks.wulf import WindowLayer

try:
    from messenger.proto.events import g_messengerEvents
except ImportError:
    g_messengerEvents = None

try:
    from messenger.formatters.service_channel import SYS_MESSAGE_TYPE
except ImportError:
    SYS_MESSAGE_TYPE = None

try:
    from gui.shared import g_eventBus, EVENT_BUS_SCOPE
    from gui.shared.events import AppLifeCycleEvent
    from gui.app_loader.settings import APP_NAME_SPACE
except ImportError:
    g_eventBus = None
    EVENT_BUS_SCOPE = None
    AppLifeCycleEvent = None
    APP_NAME_SPACE = None

try:
    from account_helpers import getAccountDatabaseID
except ImportError:
    getAccountDatabaseID = None

try:
    from items import vehicles as _vehiclesModule
except ImportError:
    _vehiclesModule = None

_DEBUG = os.path.isfile('.debug_mods')
logger = logging.getLogger('under_pressure.masters')
logger.setLevel(logging.DEBUG if _DEBUG else logging.ERROR)
__version__ = '0.2.0'

_LINKAGE_HANGAR = 'MasteryPanelHangar'
_SWF_HANGAR = 'MasteryPanelHangar.swf'
_L10N_DIR = 'mods/under_pressure.mastery'
_L10N_FALLBACK = 'en'
_l10n = {}

_API_APP_ID = 'bce57ac20af6b67b08be09fd66847ed9'
_API_URL_TEMPLATE = ('https://api.worldoftanks.%s/wot/tanks/mastery/'
                     '?application_id=' + _API_APP_ID +
                     '&distribution=%s&percentile=%s&tank_id=%s')
_XP_PERCENTILES_QUERY = u'50%2C80%2C95%2C99'
_MOE_PERCENTILES_QUERY = u'20%2C40%2C55%2C60%2C65%2C70%2C75%2C85%2C95%2C100'
_PERCENTILE_TO_KEY = ((u'50', 'thirdClass'), (u'80', 'secondClass'),
                      (u'95', 'firstClass'), (u'99', 'aceTanker'))
_MOE_PERCENTILE_TO_KEY = ((u'20', 'p20'), (u'40', 'p40'), (u'55', 'p55'),
                          (u'60', 'p60'), (u'65', 'p65'), (u'70', 'p70'),
                          (u'75', 'p75'), (u'85', 'p85'), (u'95', 'p95'),
                          (u'100', 'p100'))
_MOE_KEYS = ('p20', 'p40', 'p55', 'p60', 'p65', 'p70', 'p75', 'p85', 'p95', 'p100')
_INJECT_RETRY_DELAY = 0.5
_INJECT_MAX_ATTEMPTS = 30
_API_TIMEOUT = 5.0
_API_MAX_ATTEMPTS = 3
_API_RETRY_BASE_DELAY = 2.0
_MAX_HISTORY = 200
_MIN_TANK_LEVEL = 5
_DEFAULT_VIEW_MODE = 0

try:
    _prefsFilePath = BigWorld.wg_getPreferencesFilePath()
except AttributeError:
    _prefsFilePath = BigWorld.getPreferencesFilePath()
_CACHE_DIR = os.path.normpath(os.path.join(os.path.dirname(_prefsFilePath), 'mods', 'mastery'))
_CACHE_FILE = os.path.join(_CACHE_DIR, 'cache.dat')
_CACHE_VERSION = 11
_CACHE_TTL_SECONDS = 3 * 24 * 3600
_CACHE_SAVE_DEBOUNCE = 3.0


def _cancelCallbackSafe(cbid):
    try:
        if cbid is not None:
            BigWorld.cancelCallback(cbid)
    except (AttributeError, ValueError):
        pass


def _safeFloat(value):
    try:
        return float(value)
    except Exception:
        return None


def _tankKey(tankID):
    if tankID is None:
        return None
    try:
        return int(tankID)
    except (TypeError, ValueError):
        return tankID


def _dictGetTank(container, tankID, default=None):
    if not isinstance(container, dict):
        return default
    key = _tankKey(tankID)
    for candidate in (key, tankID, str(key), unicode(key)):
        try:
            if candidate in container:
                return container.get(candidate)
        except Exception:
            pass
    return default


def _dictPopTank(container, tankID, default=None):
    if not isinstance(container, dict):
        return default
    key = _tankKey(tankID)
    for candidate in (key, tankID, str(key), unicode(key)):
        try:
            if candidate in container:
                return container.pop(candidate)
        except Exception:
            pass
    return default


def _ensureCacheDir():
    if not os.path.isdir(_CACHE_DIR):
        try:
            os.makedirs(_CACHE_DIR)
        except OSError:
            pass


def _loadLocalization():
    global _l10n
    try:
        from helpers import getClientLanguage
        lang = getClientLanguage() or _L10N_FALLBACK
    except Exception:
        lang = _L10N_FALLBACK
    for tryLang in (lang, _L10N_FALLBACK):
        try:
            import ResMgr
            section = ResMgr.openSection(_L10N_DIR + '/' + tryLang + '.json')
            if section is not None:
                _l10n = json.loads(section.asBinary)
                return
        except Exception:
            pass


def _tr(key, default=u''):
    return _l10n.get(key, default)


def _getApiDomain():
    realm = unicode(getattr(constants, 'AUTH_REALM', u'EU')).upper()
    if 'NA' in realm:
        return 'com'
    if 'ASIA' in realm:
        return 'asia'
    return 'eu'


def _buildApiUrl(tankID, distribution, query):
    return _API_URL_TEMPLATE % (_getApiDomain(), distribution, query, tankID)


def _parseApiResponse(payload, tankID, mapping):
    if not isinstance(payload, dict):
        return None
    data = payload.get('data')
    if not isinstance(data, dict):
        return None
    distribution = data.get('distribution')
    if not isinstance(distribution, dict):
        distribution = data
    record = None
    for key in (tankID, str(tankID), unicode(tankID)):
        if key in distribution:
            record = distribution.get(key)
            break
    if not isinstance(record, dict):
        return None
    result = {}
    for percentile, name in mapping:
        result[name] = None
        for key in (percentile, str(percentile)):
            if key in record:
                try:
                    result[name] = int(record.get(key))
                except (TypeError, ValueError):
                    pass
                break
    if all(value is None for value in result.itervalues()):
        return None
    return result


def _hasFullMoeRequirements(moe):
    return isinstance(moe, dict) and all((_safeFloat(moe.get(key)) or 0) > 0 for key in _MOE_KEYS)


def _getVehicleDossier(tankID):
    try:
        return ServicesLocator.itemsCache.items.getVehicleDossier(int(tankID))
    except Exception:
        return None


def _readMarkFromDossier(dossier):
    if dossier is None:
        return None
    try:
        number = _safeFloat(dossier.getRecordValue('achievements', 'damageRating'))
        if number is not None and number >= 0:
            value = number / 100.0
            if 0 <= value <= 100:
                return round(value, 2)
    except Exception:
        pass
    try:
        number = _safeFloat(getattr(dossier.getAchievements(), 'damageRating', None))
        if number is not None and number >= 0:
            value = number / 100.0
            if 0 <= value <= 100:
                return round(value, 2)
    except Exception:
        pass
    return None


def _readMarkForTankID(tankID):
    return _readMarkFromDossier(_getVehicleDossier(tankID))


def _readMovingAverage(tankID):
    dossier = _getVehicleDossier(tankID)
    if dossier is None:
        return 0
    try:
        value = _safeFloat(dossier.getRecordValue('achievements', 'movingAvgDamage'))
        if value is not None and value > 0:
            return int(round(value))
    except Exception:
        pass
    return 0


def _readBattlesCount(tankID):
    dossier = _getVehicleDossier(tankID)
    if dossier is None:
        return 0
    for section in ('a15x15', 'a15x15_2', 'total', 'random'):
        try:
            value = dossier.getRecordValue(section, 'battlesCount')
            if value:
                return int(value)
        except Exception:
            pass
    return 0


def _getTankLevelByCD(compactDescr):
    if _vehiclesModule is None or compactDescr is None:
        return 0
    try:
        _, nationID, innationID = _vehiclesModule.parseIntCompactDescr(int(compactDescr))
        return int(_vehiclesModule.g_cache.vehicle(nationID, innationID).level)
    except Exception:
        return 0


def _getActiveAccountDBID():
    if getAccountDatabaseID is not None:
        try:
            value = int(getAccountDatabaseID() or 0)
            if value:
                return value
        except Exception:
            pass
    try:
        return int(getattr(BigWorld.player(), 'databaseID', 0) or 0)
    except Exception:
        return 0


def _extractMapName(common):
    try:
        from gui.battle_control.arena_info.arena_vos import getArenaTypeName
        return unicode(getArenaTypeName(common.get('arenaTypeID')) or u'')
    except Exception:
        return u''


def _readMaxRecursive(source, keys, depth=0):
    if source is None or depth > 5:
        return 0
    best = 0
    try:
        if isinstance(source, dict):
            for key in keys:
                try:
                    best = max(best, int(source.get(key, 0) or 0))
                except Exception:
                    pass
            for value in source.itervalues():
                best = max(best, _readMaxRecursive(value, keys, depth + 1))
        elif isinstance(source, (list, tuple)):
            for value in source:
                best = max(best, _readMaxRecursive(value, keys, depth + 1))
    except Exception:
        pass
    return best


def _extractMarkDamage(source):
    direct = _readMaxRecursive(source, ('damageDealt', 'damage', 'damageDone', 'piercingDamage'))
    assist = _readMaxRecursive(source, ('damageAssistedRadio', 'damageAssistedSpot',
                                        'damageAssistedTrack', 'damageAssistedStun',
                                        'damageAssisted'))
    return int(direct + assist)


class MasterySessionHistory(object):
    def __init__(self):
        self._snapshots = {}

    def snapshotBeforeBattle(self, tankID, mark, movingAvgDamage=None):
        if tankID is not None and mark is not None:
            self._snapshots[_tankKey(tankID)] = {
                'mark': float(mark), 'movingAvgDamage': float(movingAvgDamage or 0)}

    def consumeSnapshot(self, tankID):
        return _dictPopTank(self._snapshots, tankID)

    def peekSnapshot(self, tankID):
        return _dictGetTank(self._snapshots, tankID)

    def reset(self):
        self._snapshots.clear()


class MasteryPanelInjectorView(View):
    _g_controller = None

    def _populate(self):
        super(MasteryPanelInjectorView, self)._populate()
        if self._g_controller:
            self._g_controller._onInjectorReady(self)

    def _dispose(self):
        if self._g_controller:
            self._g_controller._onInjectorDisposed(self)
        super(MasteryPanelInjectorView, self)._dispose()

    def py_onPanelReady(self):
        if self._g_controller:
            self._g_controller._onPanelReady(self)

    def py_onDragEnd(self, offset):
        if self._g_controller:
            self._g_controller._onDragEnd(offset)

    def py_onViewModeChanged(self, mode):
        if self._g_controller:
            self._g_controller._onViewModeChanged(mode)

    def py_onExpandToggle(self):
        pass


class MasteryPanelHangarView(MasteryPanelInjectorView):
    pass


def _registerFlash():
    g_entitiesFactories.addSettings(ViewSettings(
        _LINKAGE_HANGAR, MasteryPanelHangarView, _SWF_HANGAR,
        WindowLayer.WINDOW, None, ScopeTemplates.GLOBAL_SCOPE))


def _unregisterFlash():
    try:
        g_entitiesFactories.removeSettings(_LINKAGE_HANGAR)
    except Exception:
        pass


class MasteryController(object):
    def __init__(self, session):
        self._session = session
        self._injectorView = None
        self._panelReady = False
        self._injectPending = False
        self._enabled = False
        self._hangarVisible = False
        self._visibleByData = False
        self._lastVisibleState = None
        self._position = [100, 100]
        self._viewMode = _DEFAULT_VIEW_MODE
        self._refreshCallbackId = None
        self._saveCallbackId = None
        self._saveRev = 0
        self._xpCache = {}
        self._moeCache = {}
        self._xpCacheTs = {}
        self._moeCacheTs = {}
        self._pendingXp = set()
        self._pendingMoe = set()
        self._markHistory = {}
        self._lastKnownMark = {}
        self._lastKnownStats = {}
        self._currentAccountDBID = 0
        self._loadCache()

    def setActiveAccount(self, accountDBID):
        try:
            self._currentAccountDBID = int(accountDBID or 0)
        except Exception:
            self._currentAccountDBID = 0

    def clearActiveAccount(self):
        self._currentAccountDBID = 0

    def enable(self):
        if self._enabled:
            return
        self._enabled = True
        g_currentVehicle.onChanged += self._onVehicleChanged
        lsm = getLobbyStateMachine()
        if lsm is not None:
            try:
                lsm.onVisibleRouteChanged += self._onVisibleRouteChanged
                self._hangarVisible = self._isHangarRoute(lsm.visibleRouteInfo)
            except Exception:
                self._hangarVisible = True
        else:
            self._hangarVisible = True
        if self._hangarVisible:
            self._injectFlash()

    def disable(self):
        if not self._enabled:
            return
        self._enabled = False
        try:
            g_currentVehicle.onChanged -= self._onVehicleChanged
        except Exception:
            pass
        lsm = getLobbyStateMachine()
        if lsm is not None:
            try:
                lsm.onVisibleRouteChanged -= self._onVisibleRouteChanged
            except Exception:
                pass
        _cancelCallbackSafe(self._refreshCallbackId)
        self._refreshCallbackId = None
        if self._injectorView is not None:
            try:
                self._injectorView.flashObject.as_setVisible(False)
            except Exception:
                pass

    @staticmethod
    def _isHangarRoute(routeInfo):
        text = u' '.join(unicode(value).lower() for value in (
            routeInfo, getattr(routeInfo, 'state', None),
            getattr(routeInfo, 'name', None), getattr(routeInfo, 'path', None))
                         if value is not None)
        if any(value in text for value in ('postbattle', 'post_battle', 'battle_result',
                                            'battlepass', 'battle_pass', 'store', 'shop',
                                            'research', 'techtree', 'tech_tree', 'crew', 'mission')):
            return False
        return 'hangar' in text or 'garage' in text

    def _onVisibleRouteChanged(self, routeInfo):
        self._hangarVisible = self._isHangarRoute(routeInfo)
        self._lastVisibleState = None
        if self._hangarVisible and self._injectorView is None:
            self._injectFlash()
        self._updateVisibility()

    def _injectFlash(self, attempt=0):
        if not self._enabled or self._injectorView is not None:
            return
        if self._injectPending and attempt == 0:
            return
        self._injectPending = True
        try:
            app = ServicesLocator.appLoader.getDefLobbyApp()
            if app and app.initialized:
                app.loadView(SFViewLoadParams(_LINKAGE_HANGAR))
                return
        except Exception:
            pass
        if attempt < _INJECT_MAX_ATTEMPTS:
            BigWorld.callback(_INJECT_RETRY_DELAY, lambda: self._injectFlash(attempt + 1))
        else:
            self._injectPending = False

    def _onInjectorReady(self, view):
        self._injectorView = view
        self._panelReady = False
        self._injectPending = False
        # Force the next _updateVisibility() call to actually push the
        # visibility flag to this (possibly brand new) panel instance,
        # instead of assuming it already matches a stale cached state.
        self._lastVisibleState = None

    def _onInjectorDisposed(self, view):
        if view == self._injectorView:
            self._injectorView = None
            self._panelReady = False
            self._injectPending = False
            self._lastVisibleState = None

    def _onPanelReady(self, view):
        if view != self._injectorView:
            return
        self._panelReady = True
        try:
            flash = self._injectorView.flashObject
            flash.as_setLocalization({
                'loading': _tr('loading', u'...'), 'noData': _tr('noData', u'N/A'),
                'lastBattle': _tr('lastBattle', u'Last battle'),
                'bestBattle': _tr('bestBattle', u'Best battle'),
                'dynamics': _tr('dynamics', u'Battle dynamics'),
                'record': _tr('record', u'RECORD'), 'last10': _tr('last10', u'Last 10'),
                'last25': _tr('last25', u'Last 25'),
                'progress': _tr('progress', u'Marks progress'),
                'battles': _tr('battles', u'Battles')})
            flash.as_setPosition(self._position)
            flash.as_setViewMode(int(self._viewMode))
            flash.as_setPanelBodyVisible(True)
            flash.as_setMarkBadgeEnabled(False)
            flash.as_setVisible(False)
        except Exception:
            logger.exception('panel init failed')
        self._refresh()

    def _onDragEnd(self, offset):
        try:
            self._position = [int(offset[0]), int(offset[1])]
            self._scheduleSaveCache()
        except Exception:
            pass

    def _onViewModeChanged(self, mode):
        try:
            self._viewMode = int(mode)
        except Exception:
            self._viewMode = _DEFAULT_VIEW_MODE
        self._scheduleSaveCache()

    def _onVehicleChanged(self):
        self._lastVisibleState = None
        self._scheduleRefresh(0.2)

    def _scheduleRefresh(self, delay=0.5):
        _cancelCallbackSafe(self._refreshCallbackId)
        self._refreshCallbackId = BigWorld.callback(delay, self._doRefresh)

    def _doRefresh(self):
        self._refreshCallbackId = None
        self._refresh()

    def _updateVisibility(self):
        if not (self._panelReady and self._injectorView):
            return
        visible = bool(self._enabled and self._hangarVisible and self._visibleByData)
        if visible == self._lastVisibleState:
            return
        self._lastVisibleState = visible
        try:
            self._injectorView.flashObject.as_setVisible(visible)
        except Exception:
            pass

    def _refresh(self):
        if not (self._panelReady and self._injectorView):
            return
        if not g_currentVehicle.isPresent():
            self._visibleByData = False
            self._updateVisibility()
            return
        tankID = _tankKey(getattr(g_currentVehicle.item, 'intCD', None))
        level = getattr(g_currentVehicle.item, 'level', 0) or _getTankLevelByCD(tankID)
        if tankID is None or (level and level < _MIN_TANK_LEVEL):
            self._visibleByData = False
            self._updateVisibility()
            try:
                self._injectorView.flashObject.as_clearData()
            except Exception:
                pass
            return
        self._visibleByData = True
        self._updateVisibility()
        self._captureCurrentStats(tankID)
        xp = _dictGetTank(self._xpCache, tankID)
        moe = _dictGetTank(self._moeCache, tankID)
        if xp is None and moe is None:
            try:
                self._injectorView.flashObject.as_setLoading()
            except Exception:
                pass
        if xp is not None:
            self._pushMastery(xp)
        if moe is not None:
            self._pushMoe(moe)
        if xp is None or not self._isFresh(tankID, 'xp'):
            self._requestDistribution(tankID, 'xp')
        if moe is None or not self._isFresh(tankID, 'damage'):
            self._requestDistribution(tankID, 'damage')
        self._pushHistory(tankID)

    def _readLiveMark(self, tankID):
        try:
            if g_currentVehicle.isPresent() and getattr(g_currentVehicle.item, 'intCD', None) == tankID:
                value = _readMarkFromDossier(g_currentVehicle.getDossier())
                if value is not None:
                    return value
        except Exception:
            pass
        return _readMarkForTankID(tankID)

    def _captureCurrentStats(self, tankID):
        mark = self._readLiveMark(tankID)
        if mark is None:
            return
        account = self._currentAccountDBID or _getActiveAccountDBID()
        if not account:
            return
        self._currentAccountDBID = account
        key = _tankKey(tankID)
        self._lastKnownMark.setdefault(account, {})[key] = float(mark)
        self._lastKnownStats.setdefault(account, {})[key] = {
            'damageRating': float(mark), 'movingAvgDamage': int(_readMovingAverage(tankID) or 0)}
        self._scheduleSaveCache()

    def snapshotForBattle(self, tankID):
        self._captureCurrentStats(tankID)
        mark = self._getLastKnownMark(tankID)
        if mark is not None:
            self._session.snapshotBeforeBattle(
                tankID, mark, self._getLastKnownStats(tankID).get('movingAvgDamage'))

    def _getLastKnownMark(self, tankID):
        return _dictGetTank(self._lastKnownMark.get(self._currentAccountDBID, {}), tankID)

    def _getLastKnownStats(self, tankID):
        value = _dictGetTank(self._lastKnownStats.get(self._currentAccountDBID, {}), tankID, {})
        return value if isinstance(value, dict) else {}

    def _getHistory(self, tankID):
        return _dictGetTank(self._markHistory.get(self._currentAccountDBID, {}), tankID, [])

    def recordBattle(self, tankID, mark, damage=0, mapName=u'', arenaID=None):
        if not self._currentAccountDBID:
            self._currentAccountDBID = _getActiveAccountDBID()
        if not self._currentAccountDBID or mark is None:
            return
        snapshot = self._session.consumeSnapshot(tankID) or {}
        previous = _safeFloat(snapshot.get('mark'))
        if previous is None:
            previous = self._getLastKnownMark(tankID)
        delta = float(mark) - float(previous) if previous is not None else 0.0
        historyBucket = self._markHistory.setdefault(self._currentAccountDBID, {})
        history = _dictGetTank(historyBucket, tankID)
        if history is None:
            history = []
            historyBucket[_tankKey(tankID)] = history
        entry = {'value': float(mark), 'delta': float(delta), 'damage': int(damage or 0),
                 'map': unicode(mapName or u''), 'ts': int(time.time()),
                 'num': _readBattlesCount(tankID)}
        if arenaID is not None:
            entry['arenaID'] = arenaID
        history.append(entry)
        if len(history) > _MAX_HISTORY:
            del history[:-_MAX_HISTORY]
        key = _tankKey(tankID)
        self._lastKnownMark.setdefault(self._currentAccountDBID, {})[key] = float(mark)
        self._lastKnownStats.setdefault(self._currentAccountDBID, {})[key] = {
            'damageRating': float(mark), 'movingAvgDamage': int(_readMovingAverage(tankID) or 0)}
        self._scheduleSaveCache()
        if g_currentVehicle.isPresent() and getattr(g_currentVehicle.item, 'intCD', None) == tankID:
            self._refresh()

    def _pushMastery(self, xp):
        try:
            self._injectorView.flashObject.as_setMasteryData(
                int(xp.get('thirdClass') or 0), int(xp.get('secondClass') or 0),
                int(xp.get('firstClass') or 0), int(xp.get('aceTanker') or 0))
        except Exception:
            pass

    def _pushMoe(self, moe):
        try:
            self._injectorView.flashObject.as_setMoeData(
                int(moe.get('p65') or 0), int(moe.get('p85') or 0),
                int(moe.get('p95') or 0), int(moe.get('p100') or 0))
        except Exception:
            pass

    def _pushHistory(self, tankID):
        values = []
        for entry in self._getHistory(tankID)[-_MAX_HISTORY:]:
            try:
                values.append(float(entry.get('value') if isinstance(entry, dict) else entry))
            except Exception:
                pass
        current = self._readLiveMark(tankID)
        if current is None:
            current = self._getLastKnownMark(tankID)
        if current is not None and (not values or abs(values[-1] - float(current)) > 0.0001):
            values.append(float(current))
        try:
            flash = self._injectorView.flashObject
            flash.as_setBattleHistory(values, float(current or 0.0))
            flash.as_setLastBattleDamage(int(_readMovingAverage(tankID) or 0))
        except Exception:
            pass

    def _isFresh(self, tankID, distribution):
        timestamps = self._xpCacheTs if distribution == 'xp' else self._moeCacheTs
        if distribution != 'xp':
            moe = _dictGetTank(self._moeCache, tankID)
            if moe is not None and not _hasFullMoeRequirements(moe):
                return False
        try:
            return time.time() - float(_dictGetTank(timestamps, tankID, 0)) < _CACHE_TTL_SECONDS
        except Exception:
            return False

    def _requestDistribution(self, tankID, distribution, attempt=1):
        isXp = distribution == 'xp'
        pending = self._pendingXp if isXp else self._pendingMoe
        if attempt == 1:
            if tankID in pending:
                return
            pending.add(tankID)
        query = _XP_PERCENTILES_QUERY if isXp else _MOE_PERCENTILES_QUERY
        try:
            BigWorld.fetchURL(
                _buildApiUrl(tankID, distribution, query),
                lambda response, t=tankID, d=distribution, a=attempt:
                    self._onApiResponse(t, d, response, a),
                None, _API_TIMEOUT, 'GET', None)
        except Exception:
            self._apiFailure(tankID, distribution, attempt)

    def _apiFailure(self, tankID, distribution, attempt):
        pending = self._pendingXp if distribution == 'xp' else self._pendingMoe
        if attempt < _API_MAX_ATTEMPTS:
            delay = _API_RETRY_BASE_DELAY * (2 ** (attempt - 1))
            BigWorld.callback(delay, lambda: self._requestDistribution(
                tankID, distribution, attempt + 1))
        else:
            pending.discard(tankID)

    def _onApiResponse(self, tankID, distribution, response, attempt):
        isXp = distribution == 'xp'
        pending = self._pendingXp if isXp else self._pendingMoe
        mapping = _PERCENTILE_TO_KEY if isXp else _MOE_PERCENTILE_TO_KEY
        parsed = None
        status = 0
        try:
            status = getattr(response, 'responseCode', 0)
            body = getattr(response, 'body', None)
            if body and status and status < 400:
                parsed = _parseApiResponse(json.loads(body), tankID, mapping)
        except Exception:
            pass
        if parsed is None:
            if ((not status) or status >= 500 or status == 429) and attempt < _API_MAX_ATTEMPTS:
                self._apiFailure(tankID, distribution, attempt)
                return
            pending.discard(tankID)
            return
        pending.discard(tankID)
        key = _tankKey(tankID)
        if isXp:
            self._xpCache[key] = parsed
            self._xpCacheTs[key] = int(time.time())
            self._pushMastery(parsed)
        else:
            self._moeCache[key] = parsed
            self._moeCacheTs[key] = int(time.time())
            self._pushMoe(parsed)
        self._scheduleSaveCache()

    def _loadCache(self):
        _ensureCacheDir()
        if not os.path.isfile(_CACHE_FILE):
            return
        try:
            with open(_CACHE_FILE, 'rb') as stream:
                cached, _version = cPickle.loads(zlib.decompress(stream.read()))
            if not isinstance(cached, dict):
                return
            self._xpCache = cached.get('xp', {}) or {}
            self._moeCache = cached.get('moe', {}) or {}
            self._xpCacheTs = cached.get('xpTs', {}) or {}
            self._moeCacheTs = cached.get('moeTs', {}) or {}
            self._markHistory = cached.get('markHistory', {}) or {}
            self._lastKnownMark = cached.get('lastKnownMark', {}) or {}
            self._lastKnownStats = cached.get('lastKnownMarkStats', {}) or {}
            position = cached.get('position')
            if isinstance(position, (list, tuple)) and len(position) >= 2:
                self._position = [int(position[0]), int(position[1])]
            self._viewMode = int(cached.get('viewMode', _DEFAULT_VIEW_MODE))
        except Exception:
            logger.exception('cache load failed')

    def _scheduleSaveCache(self):
        self._saveRev += 1
        revision = self._saveRev
        _cancelCallbackSafe(self._saveCallbackId)
        self._saveCallbackId = BigWorld.callback(
            _CACHE_SAVE_DEBOUNCE, lambda: self._saveCache(revision))

    def _saveCache(self, revision=None):
        self._saveCallbackId = None
        if revision is not None and revision != self._saveRev:
            return
        try:
            _ensureCacheDir()
            payload = {'xp': self._xpCache, 'moe': self._moeCache,
                       'xpTs': self._xpCacheTs, 'moeTs': self._moeCacheTs,
                       'position': list(self._position), 'viewMode': self._viewMode,
                       'markHistory': self._markHistory,
                       'lastKnownMark': self._lastKnownMark,
                       'lastKnownMarkStats': self._lastKnownStats}
            raw = zlib.compress(cPickle.dumps(
                (payload, _CACHE_VERSION), cPickle.HIGHEST_PROTOCOL), 1)
            with open(_CACHE_FILE, 'wb') as stream:
                stream.write(raw)
        except Exception:
            logger.exception('cache save failed')


class BattleResultsCollector(object):
    def __init__(self, controller):
        self._controller = controller
        self._queue = deque()
        self._tickCallbackId = None
        self._installed = False
        self._available = False

    def init(self):
        if self._installed or g_messengerEvents is None or SYS_MESSAGE_TYPE is None:
            return
        g_messengerEvents.serviceChannel.onChatMessageReceived += self._onMessage
        self._installed = True
        self._scheduleTick()

    def fini(self):
        _cancelCallbackSafe(self._tickCallbackId)
        if self._installed:
            try:
                g_messengerEvents.serviceChannel.onChatMessageReceived -= self._onMessage
            except Exception:
                pass
        self._installed = False
        self._queue.clear()

    def onAccountShowGUI(self):
        self._available = True

    def _onMessage(self, _client, message):
        try:
            if str(SYS_MESSAGE_TYPE[getattr(message, 'type', None)]) != 'battleResults':
                return
            arenaID = int((getattr(message, 'data', None) or {}).get('arenaUniqueID', 0) or 0)
            if arenaID > 0:
                self._queue.append((arenaID, 0))
        except Exception:
            pass

    def _scheduleTick(self):
        self._tickCallbackId = BigWorld.callback(1.0, self._tick)

    def _tick(self):
        self._tickCallbackId = None
        try:
            if self._available and self._queue:
                arenaID, attempt = self._queue.popleft()
                self._process(arenaID, attempt)
        finally:
            self._scheduleTick()

    def _process(self, arenaID, attempt):
        player = BigWorld.player()
        if not isinstance(player, PlayerAccount):
            if attempt < 30:
                self._queue.append((arenaID, attempt + 1))
            return
        cache = getattr(player, 'battleResultsCache', None)
        if cache is not None:
            cache.get(arenaID, functools.partial(self._onResults, arenaID, attempt))

    def _onResults(self, arenaID, attempt, responseCode, results=None):
        if responseCode is None or responseCode < 0 or not results:
            if attempt < 30:
                self._queue.append((arenaID, attempt + 1))
            return
        try:
            self._apply(arenaID, results)
        except Exception:
            logger.exception('battle result processing failed')

    def _apply(self, arenaID, results):
        common = results.get('common', {}) or {}
        allowed = [getattr(constants.ARENA_GUI_TYPE, name, None) for name in ('RANDOM', 'MAPBOX')]
        allowed = [value for value in allowed if value is not None]
        if allowed and common.get('guiType', 0) not in allowed:
            return
        accountDBID = _getActiveAccountDBID()
        tankID = None
        damage = 0
        for vehicleInfo in (results.get('vehicles', {}) or {}).itervalues():
            entry = vehicleInfo[0] if isinstance(vehicleInfo, list) else vehicleInfo
            if not isinstance(entry, dict):
                continue
            if int(entry.get('accountDBID', 0) or 0) != accountDBID:
                continue
            tankID = int(entry.get('typeCompDescr', 0) or 0)
            damage = _extractMarkDamage(entry)
            break
        if not tankID:
            return
        for value in (results.get('personal', {}) or {}).itervalues():
            if isinstance(value, dict):
                damage = max(damage, _extractMarkDamage(value))
        self._readDossier(tankID, damage, _extractMapName(common), arenaID, 0)

    def _readDossier(self, tankID, damage, mapName, arenaID, attempt):
        mark = _readMarkForTankID(tankID)
        snapshot = self._controller._session.peekSnapshot(tankID) or {}
        previous = _safeFloat(snapshot.get('mark'))
        if mark is None or (previous is not None and abs(mark - previous) < 0.0001):
            if attempt < 20:
                BigWorld.callback(1.5, lambda: self._readDossier(
                    tankID, damage, mapName, arenaID, attempt + 1))
            return
        self._controller.recordBattle(tankID, mark, damage, mapName, arenaID)


class MainMod(object):
    def __init__(self):
        self._session = MasterySessionHistory()
        self._controller = MasteryController(self._session)
        self._results = BattleResultsCollector(self._controller)
        self._lobbyEventBound = False
        MasteryPanelInjectorView._g_controller = self._controller

    def init(self):
        _loadLocalization()
        _registerFlash()
        g_playerEvents.onAccountShowGUI += self._onAccountShowGUI
        g_playerEvents.onAvatarBecomePlayer += self._onAvatarBecomePlayer
        g_playerEvents.onAccountBecomeNonPlayer += self._onAccountBecomeNonPlayer
        g_playerEvents.onDisconnected += self._onDisconnected
        self._results.init()
        self._bindLobbyEvent()
        if isinstance(BigWorld.player(), PlayerAccount):
            self._onAccountShowGUI()

    def fini(self):
        try:
            g_playerEvents.onAccountShowGUI -= self._onAccountShowGUI
            g_playerEvents.onAvatarBecomePlayer -= self._onAvatarBecomePlayer
            g_playerEvents.onAccountBecomeNonPlayer -= self._onAccountBecomeNonPlayer
            g_playerEvents.onDisconnected -= self._onDisconnected
        except Exception:
            pass
        self._unbindLobbyEvent()
        self._results.fini()
        self._controller.disable()
        MasteryPanelInjectorView._g_controller = None
        _unregisterFlash()

    def _onAccountShowGUI(self, _=None):
        dbid = _getActiveAccountDBID()
        if dbid:
            self._controller.setActiveAccount(dbid)
        self._results.onAccountShowGUI()
        self._controller.enable()

    def _onAvatarBecomePlayer(self):
        tankID = None
        try:
            descriptor = getattr(BigWorld.player(), 'vehicleTypeDescriptor', None)
            if descriptor is not None:
                tankID = int(descriptor.type.compactDescr)
        except Exception:
            pass
        if tankID is not None:
            self._controller.snapshotForBattle(tankID)

    def _onAccountBecomeNonPlayer(self):
        if not isinstance(BigWorld.player(), PlayerAccount):
            self._controller.disable()

    def _onDisconnected(self):
        self._controller.disable()
        self._controller.clearActiveAccount()
        self._session.reset()

    def _bindLobbyEvent(self):
        if g_eventBus is None or AppLifeCycleEvent is None or EVENT_BUS_SCOPE is None:
            return
        try:
            g_eventBus.addListener(AppLifeCycleEvent.INITIALIZED, self._onLobbyInitialized,
                                   scope=EVENT_BUS_SCOPE.GLOBAL)
            self._lobbyEventBound = True
        except Exception:
            pass

    def _unbindLobbyEvent(self):
        if not self._lobbyEventBound:
            return
        try:
            g_eventBus.removeListener(AppLifeCycleEvent.INITIALIZED, self._onLobbyInitialized,
                                      scope=EVENT_BUS_SCOPE.GLOBAL)
        except Exception:
            pass

    def _onLobbyInitialized(self, event):
        if APP_NAME_SPACE is not None and event.ns != APP_NAME_SPACE.SF_LOBBY:
            return
        controller = self._controller
        # If a panel already exists or an injection is already in flight
        # (e.g. triggered a moment earlier by onAccountShowGUI/enable()),
        # do NOT force another loadView() here. Doing so races with the
        # in-flight injection and can create a second, orphaned
        # MasteryPanelHangar view that never receives further position/
        # visibility updates - it stays stuck on screen at its default
        # position, while the "real" panel the controller talks to can end
        # up hidden. Only (re)inject if we genuinely have nothing pending.
        if controller._injectorView is not None or controller._injectPending:
            return
        controller._panelReady = False
        controller._injectFlash()


_g_mod = MainMod()


def init():
    try:
        _g_mod.init()
    except Exception:
        logger.exception('init failed')


def fini():
    try:
        _g_mod.fini()
    except Exception:
        logger.exception('fini failed')
