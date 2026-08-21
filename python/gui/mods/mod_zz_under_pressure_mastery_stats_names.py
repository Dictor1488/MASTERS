# -*- coding: utf-8 -*-
"""Keep Masters stats vehicle source and names identical to the working MARKS build."""

try:
    from gui.mods import mod_under_pressure_mastery_stats as stats
except Exception:
    stats = None


def _vehicle_name(item, tankID=0):
    if stats is None:
        return u'#%d' % int(tankID) if tankID else u'—'

    for attr in ('userName', 'shortUserName', 'getUserName', 'getShortUserName', 'getName', 'name'):
        value = getattr(item, attr, None)
        try:
            value = value() if callable(value) else value
        except Exception:
            value = None
        text = stats._clean_vehicle_name(value) if value else u''
        if text:
            if attr == 'name':
                text = text.split(':')[-1].replace('_', ' ')
            return text

    descriptor = getattr(item, 'descriptor', None)
    value = getattr(descriptor, 'userString', None) if descriptor is not None else None
    if not value and descriptor is not None:
        value = getattr(getattr(descriptor, 'type', None), 'userString', None)

    if not value and tankID:
        try:
            from items import vehicles
            vehicleType = vehicles.getVehicleType(int(tankID))
            for attr in ('shortUserString', 'userString', 'name'):
                value = getattr(vehicleType, attr, None)
                if value:
                    break
        except Exception:
            value = None

    text = stats._clean_vehicle_name(value)
    if not text:
        try:
            text = stats._safe_text(getattr(item, 'name', u'')).split(':')[-1].replace('_', ' ').strip()
        except Exception:
            text = u''
    return text or (u'#%d' % int(tankID) if tankID else u'—')


def _all_vehicle_items():
    """Use the same vehicle source as the working MARKS GameFace build.

    Do not enumerate items.vehicles.g_list: that registry also contains internal,
    mode-only and duplicate descriptors. itemsCache still contains client-visible
    hidden/supertest vehicles, so unreleased random-battle tanks are preserved.
    """
    if stats is None:
        return []
    try:
        items = stats.ServicesLocator.itemsCache.items
        try:
            from gui.shared.utils.requesters import REQ_CRITERIA
            vehicles = items.getVehicles(REQ_CRITERIA.EMPTY)
        except Exception:
            vehicles = items.getVehicles()
        return list(vehicles.itervalues()) if isinstance(vehicles, dict) else list(vehicles or ())
    except Exception:
        try:
            stats._logger.exception('Failed to enumerate client vehicles')
        except Exception:
            pass
        return []


def _apply():
    if stats is not None:
        stats._vehicle_name = _vehicle_name
        stats._all_vehicle_items = _all_vehicle_items


_apply()


def init():
    _apply()


def fini():
    pass
