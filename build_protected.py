# -*- coding: utf-8 -*-
"""Run the normal MASTERS build with staged GameFace protection.

Python bytecode protection is intentionally reserved for PjOrion. Until an
automatable PjOrion CLI/wrapper is configured, this script refuses to label
plain Python bytecode as protected.
"""
from __future__ import annotations

import os
import pathlib
import sys

import build
from tools.protect_output import protect_tree


_original_zip_folder = build.zip_folder
_protected_once = False


def _require_pjorion_hook():
    command = os.environ.get('PJORION_CMD', '').strip()
    if not command:
        raise RuntimeError(
            'PjOrion Python protection is not configured. Set PJORION_CMD to '
            'an automated PjOrion wrapper/CLI that performs Bytecode -> '
            'Obfuscate -> Compile py-file before using build_protected.py.'
        )
    return command


def _protected_zip_folder(source, destination, mode='w', compression=None):
    global _protected_once
    dest = pathlib.Path(destination)
    if dest.suffix.lower() == '.wotmod' and not _protected_once:
        _require_pjorion_hook()
        build.logger.info('PjOrion hook configured; protecting staged GameFace files...')
        protect_tree(pathlib.Path(source))
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
