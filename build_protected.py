# -*- coding: utf-8 -*-
"""Build MASTERS with PjOrion Python obfuscation and GameFace protection."""
from __future__ import annotations

import os
import pathlib
import subprocess
import sys

import build
from tools.protect_output import protect_tree


_original_zip_folder = build.zip_folder
_protected_once = False


def _pjorion_exe() -> pathlib.Path:
    value = os.environ.get('PJORION_EXE', '').strip()
    if not value:
        raise RuntimeError('PJORION_EXE is not set')
    path = pathlib.Path(value).resolve()
    if not path.is_file():
        raise RuntimeError('PjOrion executable not found: %s' % path)
    return path


def _remove_old_pyc(source: pathlib.Path) -> pathlib.Path:
    target = source.with_suffix('.pyc')
    try:
        target.unlink()
    except FileNotFoundError:
        pass
    return target


def _check_python27_pyc(path: pathlib.Path) -> None:
    if not path.is_file() or path.stat().st_size <= 8:
        raise RuntimeError('PjOrion did not create bytecode: %s' % path)
    magic = path.read_bytes()[:4]
    if magic != b'\x03\xf3\x0d\x0a':
        raise RuntimeError('Unexpected PYC magic for %s: %r' % (path, magic))


def build_python_pjorion(config: build.AppConfig) -> None:
    """Compile every repository Python source through PjOrion bytecode obfuscation."""
    exe = _pjorion_exe()
    sources = sorted(pathlib.Path('python').rglob('*.py'))
    if not sources:
        build.logger.warning('No Python sources found for PjOrion')
        return

    build.logger.info('Using PjOrion: %s', exe)
    for source in sources:
        target = _remove_old_pyc(source)
        absolute_source = source.resolve()
        args = [
            str(exe),
            '--obfuscate-bytecode-file=%s' % str(absolute_source),
            '/exit',
        ]
        build.logger.info('PjOrion obfuscating: %s', source)
        try:
            completed = subprocess.run(
                args,
                cwd=str(exe.parent),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding='utf-8',
                errors='replace',
                timeout=180,
            )
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError('PjOrion timed out for %s' % source) from exc

        if completed.returncode != 0:
            raise RuntimeError(
                'PjOrion failed for %s (exit %s):\n%s' %
                (source, completed.returncode, completed.stdout)
            )
        _check_python27_pyc(target)
        build.logger.info('PjOrion bytecode created: %s (%d bytes)', target, target.stat().st_size)


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
    build.build_python = build_python_pjorion
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
