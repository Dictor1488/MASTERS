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


def _showMasteryUnavailable(controller, tankID):
    """Replace mastery loading with N/A for the selected uncached tank."""
    if not (controller._panelReady and controller._injectorView):
        return
    if _selectedTankID() != _mastery._tankKey(tankID):
        return
    if _mastery._dictGetTank(controller._xpCache, tankID) is not None:
        # Keep showing stale cached mastery values when refresh fails.
        return

    try:
        controller._injectorView.flashObject.as_setMasteryData(0, 0, 0, 0)
    except Exception:
        _mastery.logger.exception('failed to show unavailable mastery data')


def _installFix():
    if getattr(_mastery, '_MASTERY_NA_FIX_INSTALLED', False):
        return

    originalApiFailure = _mastery.MasteryController._apiFailure
    originalOnApiResponse = _mastery.MasteryController._onApiResponse

    def apiFailure(self, tankID, distribution, attempt):
        originalApiFailure(self, tankID, distribution, attempt)
        if distribution != 'xp':
            return
        if attempt >= _mastery._API_MAX_ATTEMPTS and tankID not in self._pendingXp:
            _showMasteryUnavailable(self, tankID)

    def onApiResponse(self, tankID, distribution, response, attempt):
        originalOnApiResponse(self, tankID, distribution, response, attempt)
        if distribution != 'xp':
            return
        if (tankID not in self._pendingXp and
                _mastery._dictGetTank(self._xpCache, tankID) is None):
            _showMasteryUnavailable(self, tankID)

    _mastery.MasteryController._apiFailure = apiFailure
    _mastery.MasteryController._onApiResponse = onApiResponse
    _mastery._MASTERY_NA_FIX_INSTALLED = True


_installFix()


def init():
    _installFix()


def fini():
    pass
