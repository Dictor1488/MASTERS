# -*- coding: utf-8 -*-
"""Finish failed mastery API requests with N/A instead of endless loading."""

try:
    from gui.mods import mod_under_pressure_mastery as _mastery
except ImportError:
    import mod_under_pressure_mastery as _mastery


def _selectedTankID():
    try:
        if not _mastery.g_currentVehicle.isPresent():
            return None
        return _mastery._tankKey(
            getattr(_mastery.g_currentVehicle.item, 'intCD', None))
    except Exception:
        return None


def _showUnavailable(controller, tankID, distribution):
    """Replace loading with N/A only for the currently selected uncached tank."""
    if not (controller._panelReady and controller._injectorView):
        return
    if _selectedTankID() != _mastery._tankKey(tankID):
        return

    cache = controller._xpCache if distribution == 'xp' else controller._moeCache
    if _mastery._dictGetTank(cache, tankID) is not None:
        # Keep showing stale cached values when a refresh request fails.
        return

    try:
        flash = controller._injectorView.flashObject
        if distribution == 'xp':
            flash.as_setMasteryData(0, 0, 0, 0)
        else:
            flash.as_setMoeData(0, 0, 0, 0)
    except Exception:
        _mastery.logger.exception('failed to show unavailable API data')


def _installFix():
    if getattr(_mastery, '_NA_FIX_INSTALLED', False):
        return

    originalApiFailure = _mastery.MasteryController._apiFailure
    originalOnApiResponse = _mastery.MasteryController._onApiResponse

    def apiFailure(self, tankID, distribution, attempt):
        originalApiFailure(self, tankID, distribution, attempt)
        pending = self._pendingXp if distribution == 'xp' else self._pendingMoe
        if attempt >= _mastery._API_MAX_ATTEMPTS and tankID not in pending:
            _showUnavailable(self, tankID, distribution)

    def onApiResponse(self, tankID, distribution, response, attempt):
        originalOnApiResponse(self, tankID, distribution, response, attempt)
        pending = self._pendingXp if distribution == 'xp' else self._pendingMoe
        cache = self._xpCache if distribution == 'xp' else self._moeCache
        if tankID not in pending and _mastery._dictGetTank(cache, tankID) is None:
            _showUnavailable(self, tankID, distribution)

    _mastery.MasteryController._apiFailure = apiFailure
    _mastery.MasteryController._onApiResponse = onApiResponse
    _mastery._NA_FIX_INSTALLED = True


_installFix()


def init():
    _installFix()


def fini():
    pass
