# -*- coding: utf-8 -*-
"""Build MASTERS with headless Python 2.7 packing and GameFace protection."""
from __future__ import annotations

import pathlib
import subprocess
import sys

import build
from tools.protect_output import protect_tree


_original_zip_folder = build.zip_folder
_protected_once = False
_PY27_MAGIC = b'\x03\xf3\x0d\x0a'
_PACKER = pathlib.Path('tools/orion_like_packer27.py').resolve()


def _remove_file(path: pathlib.Path) -> None:
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def _check_python27_pyc(path: pathlib.Path) -> None:
    if not path.is_file() or path.stat().st_size <= 8:
        raise RuntimeError('Protected PYC was not created: %s' % path)
    magic = path.read_bytes()[:4]
    if magic != _PY27_MAGIC:
        raise RuntimeError('Unexpected Python 2.7 PYC magic for %s: %r' % (path, magic))


def build_python_protected(config: build.AppConfig) -> None:
    """Pack every Python source into an encoded loader PYC using Python 2.7."""
    if not _PACKER.is_file():
        raise RuntimeError('Protected packer not found: %s' % _PACKER)

    python27 = build._find_python27(config.software.python)
    sources = sorted(pathlib.Path('python').rglob('*.py'))
    if not sources:
        build.logger.warning('No Python sources found for protected build')
        return

    build.logger.info('Using Python 2.7 protected packer: %s', ' '.join(python27))
    for source in sources:
        target = source.with_suffix('.pyc')
        _remove_file(target)
        build.logger.info('Protecting Python: %s', source)

        command = python27 + [str(_PACKER), str(source.resolve()), str(target.resolve())]
        completed = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding='utf-8',
            errors='replace',
            timeout=120,
        )
        output = (completed.stdout or '').strip()
        if completed.returncode != 0:
            raise RuntimeError(
                'Protected Python packer failed for %s (exit %s):\n%s' %
                (source, completed.returncode, output)
            )

        _check_python27_pyc(target)
        build.logger.info('Protected PYC created: %s (%d bytes)', target, target.stat().st_size)


def _protected_zip_folder(source, destination, mode='w', compression=None):
    global _protected_once
    dest = pathlib.Path(destination)
    if dest.suffix.lower() == '.wotmod' and not _protected_once:
        build.logger.info('Protecting staged JS/CSS/HTML before WOTMOD packaging...')
        protect_tree(pathlib.Path(source))
        _protected_once = True
    if compression is None:
        return _original_zip_folder(source, destination, mode)
    return _original_zip_folder(source, destination, mode, compression)


def main() -> int:
    build.build_python = build_python_protected
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
