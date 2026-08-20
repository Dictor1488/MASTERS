# -*- coding: utf-8 -*-
"""GameFace-only renderer for the Under Pressure Mastery hangar panel.

Keeps the original three-mode garage panel and adds only a separate statistics
button which opens the mastery tank statistics window.
"""
import logging
import time

import BigWorld

try:
    import GUI
    import Keys
except Exception:
    GUI = None
    Keys = None

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
PANEL_WIDTH = 345
PANEL_HEIGHT_BOTH = 70
PANEL_HEIGHT_SINGLE = 44
SURFACE_WIDTH = 385
BOUNDARY_GAP = 10
DRAG_DELAY = 0.150
DRAG_THRESHOLD_SQ = 20 * 20

_active = None
_position = (40, 140)
_mode_handler = None
_drag_handler = None
_dragCallbackId = None
_dragCursorStart = None
_dragWindowStart = None
_dragStartedAt = 0.0
_dragActivated = False


def _safe_int(value, default=0):
    try:
        return int(value)
    except Exception:
        return default


def _controller():
    try:
        return _core._g_mod._controller if _core is not None else None
    except Exception:
        return None


def _mode(ctrl):
    mode = _safe_int(getattr(ctrl, '_viewMode', 0), 0)
    return mode if mode in (0, 1, 2) else 0


def _panel_height(ctrl):
    return PANEL_HEIGHT_BOTH if _mode(ctrl) == 0 else PANEL_HEIGHT_SINGLE


def _screen_resolution():
    try:
        r = GUI.screenResolution()
        return int(r[0]), int(r[1])
    except Exception:
        return 1920, 1080


def _base_position(ctrl):
    sw, sh = _screen_resolution()
    try:
        px, py = int(ctrl._position[0]), int(ctrl._position[1])
    except Exception:
        px, py = -1, -1
    if px < 0 or py < 0:
        px = int(max(BOUNDARY_GAP, (sw - PANEL_WIDTH) * 0.5))
        py = int(max(BOUNDARY_GAP, sh * 0.32 - _panel_height(ctrl) * 0.5))
    return px, py


def _visible(ctrl):
    return bool(getattr(ctrl, '_enabled', False) and
                getattr(ctrl, '_lobbyReady', False) and
                not getattr(ctrl, '_awaitingRouteEvent', True) and
                getattr(ctrl, '_hangarVisible', False) and
                getattr(ctrl, '_visibleByData', False))


def _cache_record(container, tankID):
    try:
        value = _core._dictGetTank(container, tankID)
        return value if isinstance(value, dict) else None
    except Exception:
        return None


def _open_stats():
    try:
        from gui.mods import mod_under_pressure_mastery_stats as stats
        stats.open_stats()
    except Exception:
        _logger.exception('Failed to open mastery statistics')


def _close_stats():
    try:
        from gui.mods import mod_under_pressure_mastery_stats as stats
        stats.close_stats()
    except Exception:
        pass


if _AVAILABLE:
    class MasteryGamefaceVM(ViewModel):
        __slots__ = ('onDrag', 'onNextMode', 'onOpenStats')

        def __init__(self):
            super(MasteryGamefaceVM, self).__init__(properties=14, commands=3)

        def _initialize(self):
            super(MasteryGamefaceVM, self)._initialize()
            self._addBoolProperty('visible', False)
            self._addBoolProperty('loading', False)
            self._addNumberProperty('mode', 0)
            self._addBoolProperty('hasXp', False)
            self._addBoolProperty('hasMoe', False)
            self._addNumberProperty('thirdClass', 0)
            self._addNumberProperty('secondClass', 0)
            self._addNumberProperty('firstClass', 0)
            self._addNumberProperty('aceTanker', 0)
            self._addNumberProperty('p65', 0)
            self._addNumberProperty('p85', 0)
            self._addNumberProperty('p95', 0)
            self._addNumberProperty('p100', 0)
            self._addStringProperty('noData', 'N/A')
            self.onDrag = self._addCommand('onDrag')
            self.onNextMode = self._addCommand('onNextMode')
            self.onOpenStats = self._addCommand('onOpenStats')

        def setAll(self, visible, loading, mode, hasXp, hasMoe,
                   thirdClass, secondClass, firstClass, aceTanker,
                   p65, p85, p95, p100, noData):
            self._setBool(0, bool(visible))
            self._setBool(1, bool(loading))
            self._setNumber(2, int(mode))
            self._setBool(3, bool(hasXp))
            self._setBool(4, bool(hasMoe))
            self._setNumber(5, int(thirdClass))
            self._setNumber(6, int(secondClass))
            self._setNumber(7, int(firstClass))
            self._setNumber(8, int(aceTanker))
            self._setNumber(9, int(p65))
            self._setNumber(10, int(p85))
            self._setNumber(11, int(p95))
            self._setNumber(12, int(p100))
            self._setString(13, unicode(noData))


    class MasteryGamefaceView(ViewImpl):
        _layoutID = ModDynAccessor(RES_MAP_ITEM_ID)

        def __init__(self):
            super(MasteryGamefaceView, self).__init__(
                ViewSettings(self._layoutID(), ViewFlags.VIEW, MasteryGamefaceVM()))

        @property
        def viewModel(self):
            return super(MasteryGamefaceView, self).getViewModel()

        def _getEvents(self):
            return ((self.viewModel.onDrag, self._onDrag),
                    (self.viewModel.onNextMode, self._onNextMode),
                    (self.viewModel.onOpenStats, self._onOpenStats))

        def _onDrag(self, args=None, *unused, **kwargs):
            phase = args.get('phase') if isinstance(args, dict) else None
            if phase == 'start':
                _drag_start()
            elif phase == 'end':
                _drag_end(True)

        def _onNextMode(self, *args, **kwargs):
            if _mode_handler is not None:
                _mode_handler()

        def _onOpenStats(self, *args, **kwargs):
            _open_stats()


    class MasteryGamefaceWindow(WindowImpl):
        def __init__(self, content):
            super(MasteryGamefaceWindow, self).__init__(
                WindowFlags.WINDOW, content=content, layer=WindowLayer.WINDOW)

        def _onReady(self):
            self.show(focus=False)
            _apply_position(self)


class _NoopFlash(object):
    def __getattr__(self, name):
        if name.startswith('as_'):
            return lambda *args, **kwargs: None
        raise AttributeError(name)


class _NoopInjector(object):
    def __init__(self):
        self.flashObject = _NoopFlash()


def _apply_position(window):
    try:
        window.move(int(_position[0]), int(_position[1]),
                    xAnchor=PositionAnchor.LEFT,
                    yAnchor=PositionAnchor.TOP)
    except Exception:
        _logger.exception('Mastery GameFace position failed')


def set_position(x, y):
    global _position
    _position = (max(0, int(x)), max(0, int(y)))
    if _active is not None:
        _apply_position(_active[0])


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
    _drag_end(False)
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
    moe = _cache_record(getattr(ctrl, '_moeCache', {}), tankID)
    loading = xp is None and moe is None
    hasXp = bool(xp and any(_safe_int(xp.get(k)) > 0 for k in
                           ('thirdClass', 'secondClass', 'firstClass', 'aceTanker')))
    hasMoe = bool(moe and any(_safe_int(moe.get(k)) > 0 for k in
                             ('p65', 'p85', 'p95', 'p100')))
    try:
        noData = _core._tr('noData', u'N/A')
    except Exception:
        noData = u'N/A'
    view = open_view()
    if view is None:
        return
    try:
        with view.viewModel.transaction() as vm:
            vm.setAll(_visible(ctrl), loading, _mode(ctrl), hasXp, hasMoe,
                      _safe_int((xp or {}).get('thirdClass')),
                      _safe_int((xp or {}).get('secondClass')),
                      _safe_int((xp or {}).get('firstClass')),
                      _safe_int((xp or {}).get('aceTanker')),
                      _safe_int((moe or {}).get('p65')),
                      _safe_int((moe or {}).get('p85')),
                      _safe_int((moe or {}).get('p95')),
                      _safe_int((moe or {}).get('p100')),
                      noData)
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
    ctrl._viewMode = _mode(ctrl)
    x, y = _base_position(ctrl)
    set_position(x, y)
    global _mode_handler, _drag_handler
    _mode_handler = lambda: _next_mode(ctrl)
    _drag_handler = lambda px, py: _save_position(ctrl, px, py)
    if open_view() is not None:
        _push(ctrl)
        try:
            ctrl._scheduleRefresh(0.0)
        except Exception:
            pass


def _next_mode(ctrl):
    mode = (_mode(ctrl) + 1) % 3
    ctrl._viewMode = mode
    try:
        ctrl._scheduleSaveCache()
    except Exception:
        pass
    _push(ctrl)


def _save_position(ctrl, x, y):
    ctrl._position = [int(x), int(y)]
    try:
        ctrl._scheduleSaveCache()
    except Exception:
        pass


def _window_position():
    if _active is None:
        return None
    try:
        pos = _active[0].position
        try:
            return float(pos.x), float(pos.y)
        except Exception:
            return float(pos[0]), float(pos[1])
    except Exception:
        return _position


def _cursor_position_px():
    r = GUI.screenResolution()
    pos = GUI.mcursor().position
    return ((pos.x * 0.5 + 0.5) * float(r[0]),
            (0.5 - pos.y * 0.5) * float(r[1]))


def _left_mouse_down():
    try:
        return Keys is None or bool(BigWorld.isKeyDown(Keys.KEY_LEFTMOUSE))
    except Exception:
        return True


def _cancel_drag_callback():
    global _dragCallbackId
    if _dragCallbackId is not None:
        try:
            BigWorld.cancelCallback(_dragCallbackId)
        except Exception:
            pass
        _dragCallbackId = None


def _drag_start():
    global _dragCursorStart, _dragWindowStart, _dragStartedAt, _dragActivated
    if _active is None or GUI is None:
        return
    try:
        _dragCursorStart = _cursor_position_px()
        _dragWindowStart = _window_position()
        _dragStartedAt = time.time()
        _dragActivated = False
        _cancel_drag_callback()
        _drag_tick()
    except Exception:
        _dragCursorStart = None
        _dragWindowStart = None
        _dragActivated = False


def _drag_tick():
    global _dragCallbackId, _position, _dragActivated
    _dragCallbackId = None
    if _active is None or _dragCursorStart is None or _dragWindowStart is None:
        return
    if not _left_mouse_down():
        _drag_end(True)
        return
    try:
        cx, cy = _cursor_position_px()
        dx = cx - _dragCursorStart[0]
        dy = cy - _dragCursorStart[1]
        if not _dragActivated and (dx * dx + dy * dy >= DRAG_THRESHOLD_SQ or
                                   time.time() - _dragStartedAt >= DRAG_DELAY):
            _dragActivated = True
        if _dragActivated:
            sw, sh = _screen_resolution()
            x = int(max(BOUNDARY_GAP,
                        min(sw - SURFACE_WIDTH - BOUNDARY_GAP, _dragWindowStart[0] + dx)))
            y = int(max(BOUNDARY_GAP,
                        min(sh - _panel_height(_controller()) - BOUNDARY_GAP,
                            _dragWindowStart[1] + dy)))
            _position = (x, y)
            _active[0].move(x, y,
                            xAnchor=PositionAnchor.LEFT,
                            yAnchor=PositionAnchor.TOP)
    except Exception:
        return
    try:
        _dragCallbackId = BigWorld.callback(0.0, _drag_tick)
    except Exception:
        pass


def _drag_end(notify=False):
    global _dragCursorStart, _dragWindowStart, _dragActivated
    moved = bool(_dragActivated)
    _cancel_drag_callback()
    _dragCursorStart = None
    _dragWindowStart = None
    _dragActivated = False
    if notify and moved and _drag_handler is not None:
        pos = _window_position()
        if pos is not None:
            _drag_handler(int(pos[0]), int(pos[1]))


_PATCHED = False
_ORIG = {}


def _install_hooks():
    global _PATCHED
    if _PATCHED or _core is None:
        return
    cls = _core.MasteryController
    for name in ('_resetInjectorState', '_updateVisibility', '_refresh',
                 '_pushMastery', '_pushMoe', '_onViewModeChanged', 'disable'):
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

    def pushMoe(self, moe):
        result = _ORIG['_pushMoe'](self, moe)
        _push(self)
        return result

    def onViewModeChanged(self, mode):
        mode = _safe_int(mode, 0)
        if mode not in (0, 1, 2):
            mode = 0
        self._viewMode = mode
        try:
            self._scheduleSaveCache()
        except Exception:
            pass
        _push(self)

    def resetInjectorState(self, hideView=False):
        if hideView:
            _close_stats()
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
    cls._pushMoe = pushMoe
    cls._onViewModeChanged = onViewModeChanged
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
    global _mode_handler, _drag_handler
    _close_stats()
    close_view()
    _mode_handler = None
    _drag_handler = None
