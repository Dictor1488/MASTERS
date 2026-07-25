# -*- coding: utf-8 -*-
"""Keep the Masters panel visible only in the actual hangar.

The lobby application and LobbyStateMachine are recreated after a battle.  The
main mod used to stay subscribed to the destroyed state machine, so its cached
``_hangarVisible`` flag remained True and the panel leaked into battle results,
storage, shop and other lobby screens.

This compatibility module keeps the controller subscribed to the current state
machine and validates the live route before every visibility change.  The panel
remains on WindowLayer.WINDOW; moving a parentless Scaleform view to SUB_VIEW
would replace and repeatedly recreate the hangar route.
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

try:
    from gui.Scaleform.lobby_entry import getLobbyStateMachine
except ImportError:
    getLobbyStateMachine = None


_RETRY_DELAY = 0.25
_MAX_RETRIES = 80
_REBIND_DELAY = 0.05

# Permanent hangar infrastructure which must not hide the panel.  Any other
# loaded lobby window is treated as an overlay and temporarily hides it.
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
    viewKey = (_safeValue(window, 'viewKey') or _safeValue(loadParams, 'viewKey') or
               _safeValue(loadParams, '_viewKey'))
    for value in (window, content, loadParams, viewKey):
        _appendObjectText(parts, value)
    return u' '.join(parts)


class _MasteryHangarWatcher(object):
    def __init__(self):
        self._controller = None
        self._lobbyStateMachine = None
        self._windowsManager = None
        self._overlayIDs = set()
        self._retryCallbackID = None
        self._rebindCallbackID = None
        self._windowsSubscribed = False

    def init(self):
        self._tryInit(0)

    def fini(self):
        _cancelCallbackSafe(self._retryCallbackID)
        _cancelCallbackSafe(self._rebindCallbackID)
        self._retryCallbackID = None
        self._rebindCallbackID = None
        self._unbindRouteListener()
        self._unbindWindowsManager()
        self._overlayIDs.clear()
        self._applyVisibility()
        self._controller = None

    def hasOverlay(self):
        return bool(self._overlayIDs)

    def _tryInit(self, attempt):
        self._retryCallbackID = None
        if not self._patchController():
            self._scheduleRetry(attempt)
            return

        routeReady = self._bindRouteListener()
        windowsReady = self._bindWindowsManager()
        self._syncCurrentRoute()
        if not (routeReady and windowsReady):
            self._scheduleRetry(attempt)

    def _scheduleRetry(self, attempt):
        if attempt >= _MAX_RETRIES:
            return
        _cancelCallbackSafe(self._retryCallbackID)
        self._retryCallbackID = BigWorld.callback(
            _RETRY_DELAY, lambda: self._tryInit(attempt + 1))

    def _scheduleRebind(self, delay=_REBIND_DELAY):
        _cancelCallbackSafe(self._retryCallbackID)
        _cancelCallbackSafe(self._rebindCallbackID)
        self._retryCallbackID = None
        self._rebindCallbackID = BigWorld.callback(delay, self._runRebind)

    def _runRebind(self):
        self._rebindCallbackID = None
        self._overlayIDs.clear()
        self._unbindRouteListener()
        self._unbindWindowsManager()
        self._tryInit(0)

    def _stopRuntimeBindings(self):
        _cancelCallbackSafe(self._retryCallbackID)
        _cancelCallbackSafe(self._rebindCallbackID)
        self._retryCallbackID = None
        self._rebindCallbackID = None
        self._overlayIDs.clear()
        self._unbindRouteListener()
        self._unbindWindowsManager()

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
        if getattr(controllerClass, '_masteryHangarLifecyclePatched', False):
            return True

        originalUpdateVisibility = controllerClass._updateVisibility
        originalEnable = controllerClass.enable
        originalDisable = controllerClass.disable
        originalLobbyInitialized = controllerClass.onLobbyInitialized

        controllerClass._masteryOriginalUpdateVisibility = originalUpdateVisibility
        controllerClass._masteryOriginalEnable = originalEnable
        controllerClass._masteryOriginalDisable = originalDisable
        controllerClass._masteryOriginalLobbyInitialized = originalLobbyInitialized

        def _updateVisibilityOnlyInHangar(instance):
            watcher = _g_watcher
            watcher._controller = instance
            watcher._syncRouteFlags(instance)
            if watcher.hasOverlay() or not getattr(instance, '_hangarVisible', False):
                watcher._forceHidden(instance)
                return
            return controllerClass._masteryOriginalUpdateVisibility(instance)

        def _enableWithCurrentLobby(instance):
            result = controllerClass._masteryOriginalEnable(instance)
            watcher = _g_watcher
            watcher._controller = instance
            watcher._scheduleRebind(0.0)
            return result

        def _disableWithCurrentLobby(instance):
            watcher = _g_watcher
            watcher._stopRuntimeBindings()
            return controllerClass._masteryOriginalDisable(instance)

        def _lobbyInitializedWithCurrentStateMachine(instance):
            result = controllerClass._masteryOriginalLobbyInitialized(instance)
            watcher = _g_watcher
            watcher._controller = instance
            # Run after every INITIALIZED listener for this lobby has completed.
            watcher._scheduleRebind(_REBIND_DELAY)
            return result

        controllerClass._updateVisibility = _updateVisibilityOnlyInHangar
        controllerClass.enable = _enableWithCurrentLobby
        controllerClass.disable = _disableWithCurrentLobby
        controllerClass.onLobbyInitialized = _lobbyInitializedWithCurrentStateMachine
        controllerClass._masteryHangarLifecyclePatched = True
        return True

    def _bindRouteListener(self):
        if getLobbyStateMachine is None or self._controller is None:
            return False
        try:
            stateMachine = getLobbyStateMachine()
        except Exception:
            stateMachine = None
        if stateMachine is None:
            return False

        if self._lobbyStateMachine is not None and self._lobbyStateMachine is not stateMachine:
            self._unbindRouteListener()

        # Remove first so repeated binding can never duplicate the callback.
        try:
            stateMachine.onVisibleRouteChanged -= self._controller._onVisibleRouteChanged
        except Exception:
            pass
        try:
            stateMachine.onVisibleRouteChanged += self._controller._onVisibleRouteChanged
        except Exception:
            return False
        self._lobbyStateMachine = stateMachine
        return True

    def _unbindRouteListener(self):
        stateMachine = self._lobbyStateMachine
        self._lobbyStateMachine = None
        if stateMachine is None or self._controller is None:
            return
        try:
            stateMachine.onVisibleRouteChanged -= self._controller._onVisibleRouteChanged
        except Exception:
            pass

    def _syncRouteFlags(self, controller):
        stateMachine = self._lobbyStateMachine
        if stateMachine is None and getLobbyStateMachine is not None:
            try:
                stateMachine = getLobbyStateMachine()
            except Exception:
                stateMachine = None
        routeInfo = _safeValue(stateMachine, 'visibleRouteInfo')
        try:
            controller._lobbyReady = controller._isLobbyAppReady()
        except Exception:
            pass
        if routeInfo is None:
            controller._awaitingRouteEvent = True
            controller._hangarVisible = False
        else:
            controller._awaitingRouteEvent = False
            try:
                controller._hangarVisible = bool(controller._isHangarRoute(routeInfo))
            except Exception:
                controller._hangarVisible = False

    def _syncCurrentRoute(self):
        controller = self._controller
        if controller is None:
            return
        self._syncRouteFlags(controller)
        controller._lastVisibleState = None
        if getattr(controller, '_hangarVisible', False):
            try:
                if getattr(controller, '_injectorView', None) is None:
                    controller._scheduleInject()
                else:
                    controller._scheduleRefresh(0.05)
            except Exception:
                pass
        self._applyVisibility()

    @staticmethod
    def _forceHidden(controller):
        if not (getattr(controller, '_panelReady', False) and
                getattr(controller, '_injectorView', None)):
            controller._lastVisibleState = None
            return
        try:
            controller._injectorView.flashObject.as_setVisible(False)
            controller._lastVisibleState = False
        except Exception:
            controller._lastVisibleState = None

    def _bindWindowsManager(self):
        manager = self._getWindowsManager()
        if manager is None:
            return False
        if self._windowsSubscribed and self._windowsManager is manager:
            return True
        self._unbindWindowsManager()
        try:
            manager.onWindowStatusChanged += self._onWindowStatusChanged
        except Exception:
            return False
        self._windowsManager = manager
        self._windowsSubscribed = True
        return True

    def _unbindWindowsManager(self):
        manager = self._windowsManager
        self._windowsManager = None
        if self._windowsSubscribed and manager is not None:
            try:
                manager.onWindowStatusChanged -= self._onWindowStatusChanged
            except Exception:
                pass
        self._windowsSubscribed = False

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

        controller = self._controller
        if controller is None:
            return
        self._syncRouteFlags(controller)
        if not getattr(controller, '_hangarVisible', False):
            self._forceHidden(controller)
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
            self._forceHidden(controller)


_g_watcher = _MasteryHangarWatcher()


def init():
    _g_watcher.init()


def fini():
    _g_watcher.fini()
