# -*- coding: utf-8 -*-
"""GameFace migration layer for the Under Pressure Mastery hangar panel.

The legacy Scaleform/AS3 renderer intentionally stays untouched and active.  This
module mirrors the same controller data into a GameFace view beside the SWF so the
new renderer can be compared pixel-for-pixel while it is being tuned.

Only the three requested GameFace modes exist here:
    0 - mastery + marks
    1 - mastery only
    2 - marks only
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
    from gui.mods import mod_under_pressure_mastery as _legacy
except Exception:
    _legacy = None

_logger = logging.getLogger('under_pressure.masters.gameface')

RES_MAP_ITEM_ID = 'UnderPressureMasteryGamefaceView'
PANEL_WIDTH = 345
PANEL_HEIGHT_BOTH = 70
PANEL_HEIGHT_SINGLE = 44
SURFACE_WIDTH = 355
SURFACE_HEIGHT = 80
COMPARE_GAP = 20
COMPARE_DX = PANEL_WIDTH + COMPARE_GAP
BOUNDARY_GAP = 10
DRAG_DELAY = 0.150
DRAG_THRESHOLD_SQ = 20 * 20

_active = None
_position = (40, 140)
_controller_ref = None
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


def _safe_bool(value):
    try:
        return bool(value)
    except Exception:
        return False


if _AVAILABLE:
    class MasteryGamefaceVM(ViewModel):
        __slots__ = ('onDrag', 'onNextMode')

        def __init__(self):
            super(MasteryGamefaceVM, self).__init__(properties=14, commands=2)

        def _initialize(self):
            super(MasteryGamefaceVM, self)._initialize()
            self._addBoolProperty('visible', False)      # 0
            self._addBoolProperty('loading', False)      # 1
            self._addNumberProperty('mode', 0)           # 2
            self._addBoolProperty('hasXp', False)        # 3
            self._addBoolProperty('hasMoe', False)       # 4
            self._addNumberProperty('thirdClass', 0)     # 5
            self._addNumberProperty('secondClass', 0)    # 6
            self._addNumberProperty('firstClass', 0)     # 7
            self._addNumberProperty('aceTanker', 0)      # 8
            self._addNumberProperty('p65', 0)            # 9
            self._addNumberProperty('p85', 0)            # 10
            self._addNumberProperty('p95', 0)            # 11
            self._addNumberProperty('p100', 0)           # 12
            self._addStringProperty('noData', 'N/A')     # 13
            self.onDrag = self._addCommand('onDrag')
            self.onNextMode = self._addCommand('onNextMode')

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
                    (self.viewModel.onNextMode, self._onNextMode))

        def _onDrag(self, args=None, *unused, **kwargs):
            try:
                phase = args.get('phase') if isinstance(args, dict) else None
                if phase == 'start':
                    _drag_start()
                elif phase == 'end':
                    _drag_end(True)
            except Exception:
                _logger.exception('GameFace Mastery drag command failed')

        def _onNextMode(self, *args, **kwargs):
            try:
                if _mode_handler is not None:
                    _mode_handler()
            except Exception:
                _logger.exception('GameFace Mastery mode command failed')


    class MasteryGamefaceWindow(WindowImpl):
        def __init__(self, content):
            super(MasteryGamefaceWindow, self).__init__(
                WindowFlags.WINDOW, content=content, layer=WindowLayer.WINDOW)

        def _onReady(self):
            self.show(focus=False)
            _apply_position(self)


def available():
    return bool(_AVAILABLE)


def set_handlers(mode_handler=None, drag_handler=None):
    global _mode_handler, _drag_handler
    _mode_handler = mode_handler
    _drag_handler = drag_handler


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


def _apply_position(window):
    try:
        x, y = _position
        window.move(int(x), int(y),
                    xAnchor=PositionAnchor.LEFT,
                    yAnchor=PositionAnchor.TOP)
    except Exception:
        _logger.exception('GameFace Mastery position failed')


def set_position(x, y):
    global _position
    try:
        _position = (max(0, int(x)), max(0, int(y)))
    except Exception:
        return
    if _active is not None:
        _apply_position(_active[0])


def _cursor_position_px():
    if GUI is None:
        raise RuntimeError('GUI module unavailable')
    resolution = GUI.screenResolution()
    width = float(resolution[0])
    height = float(resolution[1])
    pos = GUI.mcursor().position
    return ((pos.x * 0.5 + 0.5) * width,
            (0.5 - pos.y * 0.5) * height)


def _left_mouse_down():
    if Keys is None:
        return True
    try:
        return bool(BigWorld.isKeyDown(Keys.KEY_LEFTMOUSE))
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
    if _active is None:
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
        _logger.exception('GameFace Mastery drag start failed')


def _drag_tick():
    global _dragCallbackId, _position, _dragActivated
    _dragCallbackId = None
    if _active is None or _dragCursorStart is None or _dragWindowStart is None:
        return
    if not _left_mouse_down():
        _drag_end(True)
        return
    try:
        cursorX, cursorY = _cursor_position_px()
        dx = cursorX - _dragCursorStart[0]
        dy = cursorY - _dragCursorStart[1]
        if not _dragActivated:
            if dx * dx + dy * dy >= DRAG_THRESHOLD_SQ or time.time() - _dragStartedAt >= DRAG_DELAY:
                _dragActivated = True
        if _dragActivated:
            x = max(BOUNDARY_GAP, int(_dragWindowStart[0] + dx))
            y = max(BOUNDARY_GAP, int(_dragWindowStart[1] + dy))
            _position = (x, y)
            _active[0].move(x, y,
                            xAnchor=PositionAnchor.LEFT,
                            yAnchor=PositionAnchor.TOP)
    except Exception:
        _logger.exception('GameFace Mastery drag tick failed')
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
        try:
            pos = _window_position()
            if pos is not None:
                _drag_handler(int(pos[0]), int(pos[1]))
        except Exception:
            _logger.exception('GameFace Mastery drag-end callback failed')


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
        _logger.exception('GameFace Mastery view failed to open')
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
        _logger.exception('GameFace Mastery view failed to close')


def update(visible, loading, mode, hasXp, hasMoe,
           thirdClass, secondClass, firstClass, aceTanker,
           p65, p85, p95, p100, noData=u'N/A'):
    view = open_view()
    if view is None:
        return False
    try:
        with view.viewModel.transaction() as vm:
            vm.setAll(visible, loading, mode, hasXp, hasMoe,
                      thirdClass, secondClass, firstClass, aceTanker,
                      p65, p85, p95, p100, noData)
        return True
    except Exception:
        _logger.exception('GameFace Mastery model update failed')
        return False


def set_visible(value):
    if _active is None:
        return False
    try:
        with _active[1].viewModel.transaction() as vm:
            vm._setBool(0, bool(value))
        return True
    except Exception:
        return False


def _controller():
    if _legacy is None:
        return None
    try:
        return _legacy._g_mod._controller
    except Exception:
        return None


def _mode(ctrl):
    value = _safe_int(getattr(ctrl, '_viewMode', 0), 0)
    return value if value in (0, 1, 2) else 0


def _panel_height(ctrl):
    return PANEL_HEIGHT_BOTH if _mode(ctrl) == 0 else PANEL_HEIGHT_SINGLE


def _screen_resolution():
    try:
        resolution = GUI.screenResolution()
        return int(resolution[0]), int(resolution[1])
    except Exception:
        return 1920, 1080


def _legacy_base_position(ctrl):
    sw, sh = _screen_resolution()
    position = getattr(ctrl, '_position', [-1, -1])
    try:
        px, py = int(position[0]), int(position[1])
    except Exception:
        px, py = -1, -1
    if px < 0 or py < 0:
        px = int(max(BOUNDARY_GAP, (sw - PANEL_WIDTH) * 0.5))
        py = int(max(BOUNDARY_GAP, sh * 0.32 - _panel_height(ctrl) * 0.5))
    return px, py


def _place_for_compare(ctrl):
    sw, unused = _screen_resolution()
    baseX, baseY = _legacy_base_position(ctrl)
    rightX = baseX + COMPARE_DX
    if rightX + SURFACE_WIDTH + BOUNDARY_GAP <= sw:
        deltaX = COMPARE_DX
    else:
        deltaX = -COMPARE_DX
    ctrl._gfCompareDeltaX = deltaX
    set_position(baseX + deltaX, baseY)


def _visible(ctrl):
    return bool(getattr(ctrl, '_enabled', False) and
                getattr(ctrl, '_lobbyReady', False) and
                not getattr(ctrl, '_awaitingRouteEvent', True) and
                getattr(ctrl, '_hangarVisible', False) and
                getattr(ctrl, '_visibleByData', False))


def _cache_record(container, tankID):
    if tankID is None:
        return None
    try:
        value = _legacy._dictGetTank(container, tankID)
        return value if isinstance(value, dict) else None
    except Exception:
        return None


def _push(ctrl):
    if not _AVAILABLE or ctrl is None:
        return
    if not (getattr(ctrl, '_panelReady', False) and getattr(ctrl, '_injectorView', None)):
        set_visible(False)
        return
    tankID = getattr(ctrl, '_displayedTankID', None)
    xp = _cache_record(getattr(ctrl, '_xpCache', {}), tankID)
    moe = _cache_record(getattr(ctrl, '_moeCache', {}), tankID)
    loading = xp is None and moe is None
    hasXp = bool(xp and any(_safe_int(xp.get(k), 0) > 0 for k in
                           ('thirdClass', 'secondClass', 'firstClass', 'aceTanker')))
    hasMoe = bool(moe and any(_safe_int(moe.get(k), 0) > 0 for k in
                             ('p65', 'p85', 'p95', 'p100')))
    try:
        noData = _legacy._tr('noData', u'N/A')
    except Exception:
        noData = u'N/A'
    update(
        _visible(ctrl), loading, _mode(ctrl), hasXp, hasMoe,
        _safe_int((xp or {}).get('thirdClass'), 0),
        _safe_int((xp or {}).get('secondClass'), 0),
        _safe_int((xp or {}).get('firstClass'), 0),
        _safe_int((xp or {}).get('aceTanker'), 0),
        _safe_int((moe or {}).get('p65'), 0),
        _safe_int((moe or {}).get('p85'), 0),
        _safe_int((moe or {}).get('p95'), 0),
        _safe_int((moe or {}).get('p100'), 0),
        noData)


def _open_for(ctrl):
    if not _AVAILABLE or ctrl is None:
        return
    set_handlers(lambda: _next_mode(ctrl),
                 lambda x, y: _gameface_drag_end(ctrl, x, y))
    _place_for_compare(ctrl)
    if open_view() is not None:
        ctrl._gfActive = True
        _push(ctrl)


def _next_mode(ctrl):
    mode = (_mode(ctrl) + 1) % 3
    try:
        ctrl._onViewModeChanged(mode)
    except Exception:
        ctrl._viewMode = mode
        try:
            ctrl._scheduleSaveCache()
        except Exception:
            pass
    try:
        if getattr(ctrl, '_injectorView', None):
            ctrl._injectorView.flashObject.as_setViewMode(mode)
    except Exception:
        pass
    _push(ctrl)


def _gameface_drag_end(ctrl, x, y):
    deltaX = _safe_int(getattr(ctrl, '_gfCompareDeltaX', COMPARE_DX), COMPARE_DX)
    base = [int(x) - deltaX, int(y)]
    ctrl._position = base
    try:
        ctrl._scheduleSaveCache()
    except Exception:
        pass
    try:
        if getattr(ctrl, '_injectorView', None):
            ctrl._injectorView.flashObject.as_setPosition(base)
    except Exception:
        pass


def _ensure_state(ctrl):
    if ctrl is None:
        return
    if not hasattr(ctrl, '_gfActive'):
        ctrl._gfActive = False
    if not hasattr(ctrl, '_gfCompareDeltaX'):
        ctrl._gfCompareDeltaX = COMPARE_DX


_PATCHED = False
_ORIG = {}


def _install_hooks():
    global _PATCHED
    if _PATCHED or _legacy is None:
        return
    cls = _legacy.MasteryController

    for name in ('_onPanelReady', '_updateVisibility', '_refresh', '_pushMastery',
                 '_pushMoe', '_onDragEnd', '_onViewModeChanged', 'disable',
                 '_resetInjectorState'):
        _ORIG[name] = getattr(cls, name)

    def onPanelReady(self, view):
        result = _ORIG['_onPanelReady'](self, view)
        _ensure_state(self)
        if getattr(self, '_panelReady', False):
            _open_for(self)
        return result

    def updateVisibility(self):
        result = _ORIG['_updateVisibility'](self)
        if getattr(self, '_gfActive', False):
            set_visible(_visible(self))
        return result

    def refresh(self):
        result = _ORIG['_refresh'](self)
        if getattr(self, '_gfActive', False):
            _push(self)
        return result

    def pushMastery(self, xp):
        result = _ORIG['_pushMastery'](self, xp)
        if getattr(self, '_gfActive', False):
            _push(self)
        return result

    def pushMoe(self, moe):
        result = _ORIG['_pushMoe'](self, moe)
        if getattr(self, '_gfActive', False):
            _push(self)
        return result

    def onDragEnd(self, offset):
        result = _ORIG['_onDragEnd'](self, offset)
        if getattr(self, '_gfActive', False):
            _place_for_compare(self)
        return result

    def onViewModeChanged(self, mode):
        result = _ORIG['_onViewModeChanged'](self, mode)
        if getattr(self, '_gfActive', False):
            _place_for_compare(self)
            _push(self)
        return result

    def disable(self):
        if getattr(self, '_gfActive', False):
            close_view()
            self._gfActive = False
        return _ORIG['disable'](self)

    def resetInjectorState(self, hideView=False):
        if hideView and getattr(self, '_gfActive', False):
            close_view()
            self._gfActive = False
        return _ORIG['_resetInjectorState'](self, hideView)

    cls._onPanelReady = onPanelReady
    cls._updateVisibility = updateVisibility
    cls._refresh = refresh
    cls._pushMastery = pushMastery
    cls._pushMoe = pushMoe
    cls._onDragEnd = onDragEnd
    cls._onViewModeChanged = onViewModeChanged
    cls.disable = disable
    cls._resetInjectorState = resetInjectorState
    _PATCHED = True
    _ensure_state(_controller())


_install_hooks()


def init():
    try:
        _install_hooks()
        ctrl = _controller()
        _ensure_state(ctrl)
        if ctrl is not None and getattr(ctrl, '_panelReady', False):
            _open_for(ctrl)
    except Exception:
        _logger.exception('GameFace Mastery init failed')


def fini():
    try:
        close_view()
        set_handlers(None, None)
        ctrl = _controller()
        if ctrl is not None:
            ctrl._gfActive = False
    except Exception:
        _logger.exception('GameFace Mastery fini failed')
