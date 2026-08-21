# -*- coding: utf-8 -*-
"""Filter MASTERS statistics vehicles the same way MARKS filters its stats list."""
import logging

from gui.shared.personality import ServicesLocator

_logger = logging.getLogger('under_pressure.masters.stats.filter')
_ORIGINAL_ALL_VEHICLE_ITEMS = None


def _stats_module():
    try:
        from gui.mods import mod_under_pressure_mastery_stats as stats
        return stats
    except Exception:
        return None


def _controller():
    stats = _stats_module()
    if stats is None:
        return None
    try:
        return stats._controller()
    except Exception:
        return None


def _tank_ids(container, safe_int):
    result = set()
    if not isinstance(container, dict):
        return result
    try:
        keys = container.iterkeys()
    except Exception:
        try:
            keys = container.keys()
        except Exception:
            keys = ()
    for key in keys:
        tankID = safe_int(key, 0)
        if tankID > 0:
            result.add(tankID)
    return result


def _reasonable_name(stats, item, tankID):
    name = stats._vehicle_name(item, tankID)
    if not name or name == u'—' or name.startswith(u'#'):
        return False
    text = name.lower().strip()
    if name.count('/') >= 2:
        return False
    for token in (u'unknown', u'placeholder', u'default vehicle', u'test vehicle'):
        if token in text:
            return False
    return True


def _bool_attr(source, name):
    if source is None:
        return False
    try:
        value = getattr(source, name, False)
        return bool(value() if callable(value) else value)
    except Exception:
        return False


def _sources(item):
    descriptor = getattr(item, 'descriptor', None)
    return (item, descriptor, getattr(descriptor, 'type', None))


def _is_supertest_vehicle(item):
    for source in _sources(item):
        if _bool_attr(source, 'isOnlyForSupertest'):
            return True
    return False


def _is_hidden_vehicle(item):
    for source in _sources(item):
        if source is None:
            continue
        for attr in ('isHidden', 'isSecret', 'isOnlyForSupertest'):
            if _bool_attr(source, attr):
                return True
    return False


def _has_real_mastery_data(stats, ctrl, item, tankID):
    """Require actual mastery values; mere dossier existence is not evidence."""
    try:
        xp = stats._xp_for(ctrl, tankID) if ctrl is not None else {}
        if any(stats._safe_int(xp.get(key), 0) > 0
               for key in ('thirdClass', 'secondClass', 'firstClass', 'aceTanker')):
            return True
    except Exception:
        pass

    try:
        if stats._read_mastery(item, tankID) > 0:
            return True
    except Exception:
        pass
    return False


class _RegistryVehicle(object):
    def __init__(self, descriptor, compactDescr, nationID):
        self.descriptor = descriptor
        self.compactDescr = int(compactDescr)
        self.intCD = int(compactDescr)
        self.nationID = int(nationID)

    def __getattr__(self, name):
        return getattr(self.descriptor, name)


def _vehicle_from_compact_descr(tankID):
    try:
        from items import vehicles
        descriptor = vehicles.getVehicleType(int(tankID))
        if descriptor is None:
            return None
        try:
            _itemType, nationID, _innationID = vehicles.parseIntCompactDescr(int(tankID))
        except Exception:
            nationID = getattr(descriptor, 'nationID', 0)
        return _RegistryVehicle(descriptor, int(tankID), int(nationID))
    except Exception:
        return None


def _dedupe_key(stats, item, tankID):
    try:
        name = stats._vehicle_name(item, tankID).strip().lower()
    except Exception:
        name = u''
    try:
        nation = stats._nation(item)
    except Exception:
        nation = u''
    try:
        level = stats._safe_int(getattr(item, 'level', 0), 0)
    except Exception:
        level = 0
    try:
        vehicleType = stats._vehicle_type(item)
    except Exception:
        vehicleType = u''
    return (name, nation, level, vehicleType)


def _candidate_score(stats, ctrl, item, tankID):
    score = 0
    try:
        if stats._is_owned(item):
            score += 100
    except Exception:
        pass
    hidden = _is_hidden_vehicle(item)
    supertest = _is_supertest_vehicle(item)
    realData = _has_real_mastery_data(stats, ctrl, item, tankID)
    if not hidden:
        score += 40
    if realData:
        score += 20
    if supertest:
        score += 10
    return score


def _append_best(stats, ctrl, selected, item, tankID):
    key = _dedupe_key(stats, item, tankID)
    current = selected.get(key)
    score = _candidate_score(stats, ctrl, item, tankID)
    if current is None or score > current[0]:
        selected[key] = (score, tankID, item)


def _filtered_vehicle_items():
    stats = _stats_module()
    if stats is None:
        return []
    ctrl = _controller()
    xpBucket = getattr(ctrl, '_xpCache', {}) or {} if ctrl is not None else {}
    backedIDs = _tank_ids(xpBucket, stats._safe_int)

    try:
        items = ServicesLocator.itemsCache.items
        try:
            from gui.shared.utils.requesters import REQ_CRITERIA
            vehiclesMap = items.getVehicles(REQ_CRITERIA.EMPTY)
        except Exception:
            vehiclesMap = items.getVehicles()
        baseItems = list(vehiclesMap.itervalues()) if isinstance(vehiclesMap, dict) else list(vehiclesMap or ())
    except Exception:
        _logger.exception('Failed to enumerate normal client vehicles')
        baseItems = []

    selected = {}
    seenIDs = set()
    skippedHidden = 0

    for item in baseItems:
        tankID = stats._safe_int(getattr(item, 'intCD', getattr(item, 'compactDescr', 0)), 0)
        if tankID <= 0 or tankID in seenIDs:
            continue
        seenIDs.add(tankID)
        if not stats._is_regular_stats_vehicle(item):
            continue
        if not _reasonable_name(stats, item, tankID):
            continue
        hidden = _is_hidden_vehicle(item)
        supertest = _is_supertest_vehicle(item)
        if hidden and not supertest and not _has_real_mastery_data(stats, ctrl, item, tankID):
            skippedHidden += 1
            continue
        _append_best(stats, ctrl, selected, item, tankID)

    addedHidden = 0
    for tankID in sorted(backedIDs):
        if tankID <= 0 or tankID in seenIDs:
            continue
        item = _vehicle_from_compact_descr(tankID)
        if item is None:
            continue
        if not stats._is_regular_stats_vehicle(item):
            continue
        if not _reasonable_name(stats, item, tankID):
            continue
        if not _has_real_mastery_data(stats, ctrl, item, tankID):
            continue
        seenIDs.add(tankID)
        _append_best(stats, ctrl, selected, item, tankID)
        addedHidden += 1

    result = [entry[2] for entry in selected.values()]
    _logger.warning(
        'MASTERS stats filter: rows=%d hiddenAdded=%d hiddenSkipped=%d duplicatesCollapsed=%d xp=%d',
        len(result), addedHidden, skippedHidden,
        max(0, len(seenIDs) - len(result)), len(xpBucket))
    return result


def _install():
    global _ORIGINAL_ALL_VEHICLE_ITEMS
    stats = _stats_module()
    if stats is None:
        return False
    if _ORIGINAL_ALL_VEHICLE_ITEMS is None:
        _ORIGINAL_ALL_VEHICLE_ITEMS = stats._all_vehicle_items
    stats._all_vehicle_items = _filtered_vehicle_items
    _logger.warning('MASTERS stats vehicle filter installed')
    return True


def init():
    _install()


def fini():
    global _ORIGINAL_ALL_VEHICLE_ITEMS
    stats = _stats_module()
    if stats is not None and _ORIGINAL_ALL_VEHICLE_ITEMS is not None:
        try:
            stats._all_vehicle_items = _ORIGINAL_ALL_VEHICLE_ITEMS
        except Exception:
            pass
    _ORIGINAL_ALL_VEHICLE_ITEMS = None
