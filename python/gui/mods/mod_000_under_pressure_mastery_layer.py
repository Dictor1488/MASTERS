# -*- coding: utf-8 -*-
"""Hide the Masters panel while real lobby windows or dialogs are open.

The panel must stay on WindowLayer.WINDOW. Registering it as SUB_VIEW destroys
and recreates the hangar route because a parentless sub-view is treated as a
replacement for the current hangar view.
"""

import sys

import BigWorld

try:
    from frameworks.wulf import IWindowsManager, WindowStatus
    from gui.shared.personality import ServicesLocator
except ImportError:
    IWindowsManager = None
    WindowStatus = None
    ServicesLocator = None


_RETRY_DELAY = 0.5
_MAX_RETRIES = 40

# Permanent lobby infrastructure which must not hide the panel.
_IGNORE_TOKENS = (
    'masterypanelhangar', 'under_pressure',
    'mainwindow', 'mainview',
    'lobbyvehiclemarkerview', 'pethousemarkerview',
    'modslistbutton', 'gunmarkslebwalobby', 'guiflash',
    'hangarwindow', 'randomhangar',
    'alias=hangar', 'name=hangar',
    'alias=lobby', 'name=lobby',
    'tooltip', 'hint', 'cursor', 'bubble', 'notification',
    'alert', 'tutorial', 'loading', 'waiting', 'login'
)


def _cancelCallbackSafe(callbackID):
    if callbackID is None:
        return
    try:
        BigWorld.cancelCallback(callbackID)
    except Exception:
        pass


def _findMasteryModule():
    for name, module in list(sys.modules.items()):
        if not name.endswith('mod_under_pressure_mastery'):
            continue
        if module is not None and hasattr(module, '_g_mod'):
            return module
    return None


def _safeValue(source, name):
    if source is None:
        return None
    try:
        return getattr(source, name, None)
    except Exception:
        return None


def _appendObjectText(parts, value):
    if value is None:
        return
    try:
        parts.append(unicode(value).lower())
    except Exception:
        try:
            parts.append(str(value).lower())
        except Exception:
            pass
    try:
        parts.append(value.__class__.__name__.lower())
    except Exception:
        pass
    for attr in ('uniqueName', 'alias', 'name', 'path'):
        nested = _safeValue(value, attr)
        if nested is not None:
            try:
                parts.append(unicode(nested).lower())
            except Exception:
                pass


def _windowText(window):
    parts = []
    content = _safeValue(window, 'content')
    loadParams = _safeValue(window, 'loadParams') or _safeValue(window, '_loadParams')
    viewKey = _safeValue(window, 'viewKey') or _safeValue(loadParams, 'viewKey') or _safeValue(loadParams, '_viewKey')
    for value in (window, content, loadParams, viewKey):
        _appendObjectText(parts, value)
    return u' '.join(parts)


class _MasteryWindowWatcher(object):
    def __init__(self):
        self._controller = None
        self._windowsManager = None
        self._overlayIDs = set()
        self._retryCallbackID = None
        self._subscribed = False

    def init(self):
        self._tryInit(0)

    def fini(self):
        _cancelCallbackSafe(self._retryCallbackID)
        self._retryCallbackID = None
        if self._subscribed and self._windowsManager is not None:
            try:
                self._windowsManager.onWindowStatusChanged -= self._onWindowStatusChanged
            except Exception:
                pass
        self._subscribed = False
        self._windowsManager = None
        self._overlayIDs.clear()
        self._applyVisibility()

    def hasOverlay(self):
        return bool(self._overlayIDs)

    def _tryInit(self, attempt):
        self._retryCallbackID = None
        if self._subscribed:
            return
        if not self._patchController():
            self._scheduleRetry(attempt)
            return
        manager = self._getWindowsManager()
        if manager is None:
            self._scheduleRetry(attempt)
            return
        try:
            manager.onWindowStatusChanged += self._onWindowStatusChanged
        except Exception:
            self._scheduleRetry(attempt)
            return
        self._windowsManager = manager
        self._subscribed = True

    def _scheduleRetry(self, attempt):
        if attempt >= _MAX_RETRIES:
            return
        self._retryCallbackID = BigWorld.callback(
            _RETRY_DELAY, lambda: self._tryInit(attempt + 1))

    def _patchController(self):
        module = _findMasteryModule()
        if module is None:
            return False
        mainMod = getattr(module, '_g_mod', None)
        controller = getattr(mainMod, '_controller', None)
        if controller is None:
            return False
        self._controller = controller
        controllerClass = controller.__class__
        if getattr(controllerClass, '_masteryWindowsVisibilityPatched', False):
            return True

        original = controllerClass._updateVisibility
        controllerClass._masteryOriginalUpdateVisibility = original

        def _updateVisibilityWithWindows(instance):
            watcher = _g_watcher
            if watcher.hasOverlay():
                if getattr(instance, '_panelReady', False) and getattr(instance, '_injectorView', None):
                    try:
                        instance._injectorView.flashObject.as_setVisible(False)
                        instance._lastVisibleState = False
                    except Exception:
                        instance._lastVisibleState = None
                return
            return controllerClass._masteryOriginalUpdateVisibility(instance)

        controllerClass._updateVisibility = _updateVisibilityWithWindows
        controllerClass._masteryWindowsVisibilityPatched = True
        return True

    @staticmethod
    def _getWindowsManager():
        if IWindowsManager is None or ServicesLocator is None:
            return None
        try:
            controllers = ServicesLocator.appControllersManager.getControllersMap()
            return controllers.get(IWindowsManager)
        except Exception:
            return None

    def _onWindowStatusChanged(self, uniqueID, flags):
        loadedFlag = int(getattr(WindowStatus, 'LOADED', 2)) if WindowStatus is not None else 2
        try:
            isLoaded = bool(int(flags) & loadedFlag)
        except Exception:
            isLoaded = False

        if not isLoaded:
            if uniqueID in self._overlayIDs:
                self._overlayIDs.discard(uniqueID)
                self._applyVisibility()
            return

        if self._controller is None or not getattr(self._controller, '_hangarVisible', False):
            return
        try:
            window = self._windowsManager.findWindowById(uniqueID)
        except Exception:
            window = None
        if window is None:
            return

        text = _windowText(window)
        if not text or any(token in text for token in _IGNORE_TOKENS):
            return

        self._overlayIDs.add(uniqueID)
        self._applyVisibility()

    def _applyVisibility(self):
        controller = self._controller
        if controller is None:
            return
        controller._lastVisibleState = None
        try:
            controller._updateVisibility()
        except Exception:
            pass


_g_watcher = _MasteryWindowWatcher()


def init():
    _g_watcher.init()


def fini():
    _g_watcher.fini()
