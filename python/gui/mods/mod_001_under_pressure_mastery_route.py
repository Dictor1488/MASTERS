# -*- coding: utf-8 -*-
"""Use an exact root-hangar route check for the Masters panel.

Loadout pages are children of the hangar route, for example:
``subScope/subLayer/hangar/loadout/equipment``.  A loose substring check for
``hangar`` therefore keeps the panel visible on equipment and other setup
pages.  This patch accepts only the actual ``hangar/{root}`` route.
"""

import sys

import BigWorld

try:
    from gui.Scaleform.lobby_entry import getLobbyStateMachine
except ImportError:
    getLobbyStateMachine = None


_RETRY_DELAY = 0.25
_MAX_RETRIES = 80


def _cancelCallbackSafe(callbackID):
    if callbackID is None:
        return
    try:
        BigWorld.cancelCallback(callbackID)
    except Exception:
        pass


def _findMasteryController():
    for name, module in list(sys.modules.items()):
        if not name.endswith('mod_under_pressure_mastery'):
            continue
        mainMod = getattr(module, '_g_mod', None) if module is not None else None
        controller = getattr(mainMod, '_controller', None)
        if controller is not None:
            return controller
    return None


def _routeText(routeInfo):
    parts = []
    for value in (routeInfo, getattr(routeInfo, 'state', None),
                  getattr(routeInfo, 'name', None), getattr(routeInfo, 'path', None)):
        if value is None:
            continue
        try:
            parts.append(unicode(value).lower())
        except Exception:
            try:
                parts.append(str(value).lower())
            except Exception:
                pass
    return u' '.join(parts)


def _isRootHangarRoute(routeInfo):
    text = _routeText(routeInfo)
    if not text:
        return False
    # Equipment, ammunition, consumables and other loadout pages contain the
    # word "hangar" in their parent path.  Only the root marker is a real
    # hangar screen on which the panel is allowed to be visible.
    return '/hangar/{root}' in text or '/garage/{root}' in text


class _RoutePatch(object):
    def __init__(self):
        self._callbackID = None

    def init(self):
        self._tryPatch(0)

    def fini(self):
        _cancelCallbackSafe(self._callbackID)
        self._callbackID = None

    def _tryPatch(self, attempt):
        self._callbackID = None
        controller = _findMasteryController()
        if controller is None:
            if attempt < _MAX_RETRIES:
                self._callbackID = BigWorld.callback(
                    _RETRY_DELAY, lambda: self._tryPatch(attempt + 1))
            return

        controllerClass = controller.__class__
        controllerClass._isHangarRoute = staticmethod(_isRootHangarRoute)
        controllerClass._masteryExactRootHangarRoutePatched = True

        # Synchronize immediately in case the route was already entered before
        # this compatibility module found the main controller.
        if getLobbyStateMachine is not None:
            try:
                stateMachine = getLobbyStateMachine()
                routeInfo = getattr(stateMachine, 'visibleRouteInfo', None)
                if routeInfo is not None:
                    controller._onVisibleRouteChanged(routeInfo)
            except Exception:
                try:
                    controller._lastVisibleState = None
                    controller._updateVisibility()
                except Exception:
                    pass


_g_patch = _RoutePatch()


def init():
    _g_patch.init()


def fini():
    _g_patch.fini()
