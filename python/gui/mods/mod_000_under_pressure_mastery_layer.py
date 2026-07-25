# -*- coding: utf-8 -*-
"""Keep the Masters hangar panel below lobby windows and dialogs."""

from frameworks.wulf import WindowLayer
from gui.Scaleform.framework import g_entitiesFactories, ScopeTemplates, ViewSettings

try:
    from gui.mods import mod_under_pressure_mastery as _mastery
except ImportError:
    import mod_under_pressure_mastery as _mastery


_PANEL_LAYER = getattr(WindowLayer, 'SUB_VIEW', WindowLayer.VIEW)


def _registerFlashBelowWindows():
    """Register the panel above the hangar view, but below normal windows."""
    try:
        g_entitiesFactories.removeSettings(_mastery._LINKAGE_HANGAR)
    except Exception:
        pass

    g_entitiesFactories.addSettings(ViewSettings(
        _mastery._LINKAGE_HANGAR,
        _mastery.MasteryPanelHangarView,
        _mastery._SWF_HANGAR,
        _PANEL_LAYER,
        None,
        ScopeTemplates.GLOBAL_SCOPE))


# Patch the function itself so the result is correct regardless of whether this
# module is initialized before or after the main Masters module.
_mastery._registerFlash = _registerFlashBelowWindows


def init():
    _registerFlashBelowWindows()


def fini():
    pass
