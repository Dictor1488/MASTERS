# -*- coding: utf-8 -*-
"""GameFace-only Masters hangar card."""
import logging

import BigWorld
from CurrentVehicle import g_currentVehicle
from gui.shared.personality import ServicesLocator

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

_logger = logging.getLogger('under_pressure.masters.gameface')
RES_MAP_ITEM_ID = 'UnderPressureMasteryGamefaceView'
PANEL_WIDTH = 210
PANEL_HEIGHT = 132

_active = None
_position = (110, 115)
_positionInitialized = False
_dragPosition = [None, None]
_dragStartMouse = [None, None]


def _safe_int(value, default=0):
    try:
        return int(round(float(value)))
    except Exception:
        return default


def _safe_float(value, default=0.0):
    try:
        return float(value)
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


def _cache_record(container, tankID):
    try:
        value = _core._dictGetTank(container, tankID)
        return value if isinstance(value, dict) else None
    except Exception:
        return None


def _vehicle_name(item, tankID=0):
    for attr in ('userName', 'shortUserName', 'getUserName', 'getShortUserName', 'name'):
        value = getattr(item, attr, None)
        try:
            value = value() if callable(value) else value
        except Exception:
            value = None
        text = _safe_text(value).strip() if value else u''
        if text:
            if attr == 'name':
                text = text.split(':')[-1].replace('_', ' ')
            return text
    return u'#%d' % int(tankID) if tankID else u'—'


def _read_mastery(tankID):
    try:
        dossier = ServicesLocator.itemsCache.items.getVehicleDossier(int(tankID))
    except Exception:
        dossier = None
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


def _visible(ctrl):
    return bool(ctrl is not None and getattr(ctrl, '_enabled', False) and
                getattr(ctrl, '_lobbyReady', False) and
                not getattr(ctrl, '_awaitingRouteEvent', True) and
                getattr(ctrl, '_hangarVisible', False) and
                getattr(ctrl, '_visibleByData', False))


def _garage_position():
    global _position, _positionInitialized
    if _positionInitialized:
        return _position
    ctrl = _controller()
    if ctrl is not None:
        value = getattr(ctrl, '_position', None)
        if isinstance(value, (list, tuple)) and len(value) >= 2:
            x, y = _safe_int(value[0], -1), _safe_int(value[1], -1)
            if x >= 0 and y >= 0:
                _position = (x, y)
                _positionInitialized = True
                return _position
    _positionInitialized = True
    return _position


def _move_garage(x, y):
    global _position, _positionInitialized
    if _active is None:
        return
    try:
        x, y = max(0, _safe_int(x)), max(0, _safe_int(y))
        _active[0].move(x, y, xAnchor=PositionAnchor.LEFT, yAnchor=PositionAnchor.TOP)
        _position = (x, y)
        _positionInitialized = True
    except Exception:
        pass


def _apply_position():
    x, y = _garage_position()
    _move_garage(x, y)


def _save_position(x, y):
    global _position, _positionInitialized
    ctrl = _controller()
    pos = [max(0, _safe_int(x)), max(0, _safe_int(y))]
    _position = (pos[0], pos[1])
    _positionInitialized = True
    if ctrl is None:
        return
    ctrl._position = pos
    try:
        ctrl._scheduleSaveCache()
    except Exception:
        pass


def _handle_drag(args):
    action = args.get('action', '') if isinstance(args, dict) else ''
    if action == 'start':
        x, y = _garage_position()
        _dragPosition[0], _dragPosition[1] = x, y
        _dragStartMouse[0] = _safe_float(args.get('mouseX'), 0.0)
        _dragStartMouse[1] = _safe_float(args.get('mouseY'), 0.0)
        return
    if action == 'move':
        if _dragPosition[0] is None:
            x, y = _garage_position()
            _dragPosition[0], _dragPosition[1] = x, y
        mx = _safe_float(args.get('mouseX'), _dragStartMouse[0])
        my = _safe_float(args.get('mouseY'), _dragStartMouse[1])
        _move_garage(_dragPosition[0] + mx - _dragStartMouse[0],
                     _dragPosition[1] + my - _dragStartMouse[1])
        return
    if action == 'end':
        if _dragPosition[0] is not None:
            mx = _safe_float(args.get('mouseX'), _dragStartMouse[0])
            my = _safe_float(args.get('mouseY'), _dragStartMouse[1])
            _save_position(_dragPosition[0] + mx - _dragStartMouse[0],
                           _dragPosition[1] + my - _dragStartMouse[1])
        _dragPosition[0] = _dragPosition[1] = None
        _dragStartMouse[0] = _dragStartMouse[1] = None


def _open_stats():
    try:
        from gui.mods import mod_under_pressure_mastery_stats as stats
        stats.open_stats()
    except Exception:
        _logger.exception('Failed to open mastery stats')


def _close_stats():
    try:
        from gui.mods import mod_under_pressure_mastery_stats as stats
        stats.close_stats()
    except Exception:
        pass


if _AVAILABLE:
    class MasteryGamefaceVM(ViewModel):
        __slots__ = ('onOpenStats', 'onDrag')

        def __init__(self):
            super(MasteryGamefaceVM, self).__init__(properties=9, commands=2)

        def _initialize(self):
            super(MasteryGamefaceVM, self)._initialize()
            self._addBoolProperty('visible', False)
            self._addBoolProperty('loading', False)
            self._addStringProperty('tankName', '')
            self._addNumberProperty('mastery', 0)
            self._addBoolProperty('hasXp', False)
            self._addNumberProperty('thirdClass', 0)
            self._addNumberProperty('secondClass', 0)
            self._addNumberProperty('firstClass', 0)
            self._addNumberProperty('aceTanker', 0)
            self.onOpenStats = self._addCommand('onOpenStats')
            self.onDrag = self._addCommand('onDrag')

        def setAll(self, visible, loading, tankName, mastery, hasXp,
                   thirdClass, secondClass, firstClass, aceTanker):
            self._setBool(0, bool(visible))
            self._setBool(1, bool(loading))
            self._setString(2, _safe_text(tankName))
            self._setNumber(3, int(mastery))
            self._setBool(4, bool(hasXp))
            self._setNumber(5, int(thirdClass))
            self._setNumber(6, int(secondClass))
            self._setNumber(7, int(firstClass))
            self._setNumber(8, int(aceTanker))


    class MasteryGamefaceView(ViewImpl):
        _layoutID = ModDynAccessor(RES_MAP_ITEM_ID)

        def __init__(self):
            super(MasteryGamefaceView, self).__init__(
                ViewSettings(self._layoutID(), ViewFlags.VIEW, MasteryGamefaceVM()))

        @property
        def viewModel(self):
            return super(MasteryGamefaceView, self).getViewModel()

        def _getEvents(self):
            return ((self.viewModel.onOpenStats, self._onOpenStats),
                    (self.viewModel.onDrag, self._onDrag))

        def _onOpenStats(self, *args, **kwargs):
            _open_stats()

        def _onDrag(self, args=None, *unused, **kwargs):
            _handle_drag(args or {})


    class MasteryGamefaceWindow(WindowImpl):
        def __init__(self, content):
            super(MasteryGamefaceWindow, self).__init__(
                WindowFlags.WINDOW, content=content, layer=WindowLayer.WINDOW)

        def _onReady(self):
            self.show(focus=False)
            _apply_position()


class _NoopFlash(object):
    def __getattr__(self, name):
        if name.startswith('as_'):
            return lambda *args, **kwargs: None
        raise AttributeError(name)


class _NoopInjector(object):
    def __init__(self):
        self.flashObject = _NoopFlash()


def open_view():
    global _active
    if not _AVAILABLE:
        return None
    if _active is not None:
        return _active[1]
    try:
        layout = MasteryGamefaceView._layoutID()
        if layout is None or layout < 0:
            return None
        view = MasteryGamefaceView()
        window = MasteryGamefaceWindow(view)
        _active = (window, view)
        window.load()
        return view
    except Exception:
        _active = None
        _logger.exception('Mastery GameFace open failed')
        return None


def close_view():
    global _active
    if _active is None:
        return
    window = _active[0]
    _active = None
    try:
        window.destroy()
    except Exception:
        pass


def set_visible(value):
    if _active is None:
        return False
    try:
        with _active[1].viewModel.transaction() as vm:
            vm._setBool(0, bool(value))
        return True
    except Exception:
        return False


def _push(ctrl):
    if ctrl is None or not getattr(ctrl, '_panelReady', False):
        set_visible(False)
        return
    tankID = getattr(ctrl, '_displayedTankID', None)
    xp = _cache_record(getattr(ctrl, '_xpCache', {}), tankID)
    loading = xp is None
    hasXp = bool(xp and any(_safe_int(xp.get(k)) > 0 for k in
                           ('thirdClass', 'secondClass', 'firstClass', 'aceTanker')))
    item = None
    try:
        if g_currentVehicle.isPresent():
            item = g_currentVehicle.item
    except Exception:
        pass
    name = _vehicle_name(item, tankID) if item is not None else u''
    mastery = _read_mastery(tankID) if tankID else 0
    view = open_view()
    if view is None:
        return
    try:
        with view.viewModel.transaction() as vm:
            vm.setAll(_visible(ctrl), loading, name, mastery, hasXp,
                      _safe_int((xp or {}).get('thirdClass')),
                      _safe_int((xp or {}).get('secondClass')),
                      _safe_int((xp or {}).get('firstClass')),
                      _safe_int((xp or {}).get('aceTanker')))
    except Exception:
        _logger.exception('Mastery GameFace update failed')


def _activate(ctrl):
    if ctrl is None or not _AVAILABLE:
        return
    if getattr(ctrl, '_injectorView', None) is None:
        ctrl._injectorView = _NoopInjector()
    ctrl._injectPending = False
    ctrl._panelReady = True
    ctrl._lastVisibleState = None
    if open_view() is not None:
        _apply_position()
        _push(ctrl)
        try:
            ctrl._scheduleRefresh(0.0)
        except Exception:
            pass


_PATCHED = False
_ORIG = {}


def _install_hooks():
    global _PATCHED
    if _PATCHED or _core is None:
        return
    cls = _core.MasteryController
    for name in ('_resetInjectorState', '_updateVisibility', '_refresh',
                 '_pushMastery', 'disable'):
        _ORIG[name] = getattr(cls, name)

    def scheduleInject(self, delay=0.0, attempt=0):
        if delay and delay > 0:
            try:
                self._injectCallbackId = BigWorld.callback(delay, lambda: _activate(self))
                return
            except Exception:
                pass
        _activate(self)

    def updateVisibility(self):
        result = _ORIG['_updateVisibility'](self)
        set_visible(_visible(self))
        return result

    def refresh(self):
        result = _ORIG['_refresh'](self)
        _push(self)
        return result

    def pushMastery(self, xp):
        result = _ORIG['_pushMastery'](self, xp)
        _push(self)
        return result

    def resetInjectorState(self, hideView=False):
        if hideView:
            close_view()
        return _ORIG['_resetInjectorState'](self, hideView)

    def disable(self):
        _close_stats()
        close_view()
        return _ORIG['disable'](self)

    cls._scheduleInject = scheduleInject
    cls._updateVisibility = updateVisibility
    cls._refresh = refresh
    cls._pushMastery = pushMastery
    cls._resetInjectorState = resetInjectorState
    cls.disable = disable
    _PATCHED = True


_install_hooks()


def init():
    try:
        _install_hooks()
        ctrl = _controller()
        if ctrl is not None and getattr(ctrl, '_hangarVisible', False):
            _activate(ctrl)
    except Exception:
        _logger.exception('Mastery GameFace init failed')


def fini():
    _close_stats()
    close_view()
