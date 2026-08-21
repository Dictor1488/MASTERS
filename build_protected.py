# -*- coding: utf-8 -*-
"""Run the normal MASTERS build with staged output protection enabled."""
from __future__ import annotations

import json
import pathlib
import sys

import build
from tools.protect_output import protect_tree


_original_zip_folder = build.zip_folder
_protected_once = False
_python27_command = None


def _load_python27_command():
    global _python27_command
    if _python27_command is not None:
        return _python27_command
    configured = None
    config_path = pathlib.Path('build.json')
    if config_path.is_file():
        with config_path.open('r', encoding='utf-8') as fh:
            data = json.load(fh)
        configured = (data.get('software') or {}).get('python')
    _python27_command = build._find_python27(configured)
    return _python27_command


def _protected_zip_folder(source, destination, mode='w', compression=None):
    global _protected_once
    dest = pathlib.Path(destination)
    if dest.suffix.lower() == '.wotmod' and not _protected_once:
        build.logger.info('Protecting staged JS/CSS/HTML/PYC before packaging...')
        protect_tree(pathlib.Path(source), _load_python27_command())
        _protected_once = True
    if compression is None:
        return _original_zip_folder(source, destination, mode)
    return _original_zip_folder(source, destination, mode, compression)


def main():
    build.zip_folder = _protected_zip_folder
    build.logger = build.setup_logger()
    try:
        build.main()
    except Exception as exc:
        build.logger.exception('Protected build failed: %s', exc)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
