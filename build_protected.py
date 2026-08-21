# -*- coding: utf-8 -*-
"""Build MASTERS with PjOrion Python obfuscation and GameFace protection."""
from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

import build
from tools.protect_output import protect_tree


_original_zip_folder = build.zip_folder
_protected_once = False
_PY27_MAGIC = b'\x03\xf3\x0d\x0a'


def _pjorion_exe() -> pathlib.Path:
    value = os.environ.get('PJORION_EXE', '').strip()
    if not value:
        raise RuntimeError('PJORION_EXE is not set')
    path = pathlib.Path(value).resolve()
    if not path.is_file():
        raise RuntimeError('PjOrion executable not found: %s' % path)
    return path


def _remove_file(path: pathlib.Path) -> None:
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def _wait_for_pyc(path: pathlib.Path, timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if path.is_file() and path.stat().st_size > 8:
            return
        time.sleep(0.20)
    raise RuntimeError('PjOrion did not create bytecode: %s' % path)


def _check_python27_pyc(path: pathlib.Path) -> None:
    _wait_for_pyc(path)
    magic = path.read_bytes()[:4]
    if magic != _PY27_MAGIC:
        raise RuntimeError('Unexpected PYC magic for %s: %r' % (path, magic))


def _run_pjorion(exe: pathlib.Path, staged_source: pathlib.Path) -> pathlib.Path:
    """Run one PjOrion operation using its documented WIN32 command syntax."""
    staged_pyc = staged_source.with_suffix('.pyc')
    _remove_file(staged_pyc)

    # PjOrion 1.3.5 is an old GUI application. Keep both the source and the
    # working directory beside the executable and use one command-line syntax
    # consistently. The official command list documents --exit and
    # --obfuscate-bytecode-file=<file> as the WIN32 form.
    args = [
        str(exe),
        '--exit',
        '--obfuscate-bytecode-file=%s' % str(staged_source),
    ]
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

    output = (completed.stdout or '').strip()
    if output:
        build.logger.info('PjOrion output:\n%s', output)

    if completed.returncode != 0:
        raise RuntimeError(
            'PjOrion failed for %s (exit %s):\n%s' %
            (staged_source.name, completed.returncode, output)
        )

    if not staged_pyc.is_file():
        found = sorted(exe.parent.glob('*.pyc'))
        diagnostic = ', '.join('%s (%d bytes)' % (p.name, p.stat().st_size) for p in found)
        raise RuntimeError(
            'PjOrion returned exit 0 but did not create %s. PYC files in runtime: %s' %
            (staged_pyc.name, diagnostic or '<none>')
        )

    _check_python27_pyc(staged_pyc)
    return staged_pyc


def build_python_pjorion(config: build.AppConfig) -> None:
    """Compile every repository Python source through PjOrion bytecode obfuscation."""
    exe = _pjorion_exe()
    sources = sorted(pathlib.Path('python').rglob('*.py'))
    if not sources:
        build.logger.warning('No Python sources found for PjOrion')
        return

    build.logger.info('Using PjOrion: %s', exe)
    runtime_work = pathlib.Path(tempfile.mkdtemp(prefix='masters-', dir=str(exe.parent)))
    try:
        for index, source in enumerate(sources):
            target = source.with_suffix('.pyc')
            _remove_file(target)

            # Use a short ASCII-only filename. This avoids old Qt/Python 2.7
            # path handling issues with the GitHub runner checkout path.
            staged_source = runtime_work / ('source_%03d.py' % index)
            shutil.copyfile(str(source.resolve()), str(staged_source))

            build.logger.info('PjOrion obfuscating: %s', source)
            try:
                staged_pyc = _run_pjorion(exe, staged_source)
            except subprocess.TimeoutExpired as exc:
                raise RuntimeError('PjOrion timed out for %s' % source) from exc

            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(str(staged_pyc), str(target))
            _check_python27_pyc(target)
            build.logger.info(
                'PjOrion bytecode created: %s (%d bytes)',
                target,
                target.stat().st_size,
            )

            _remove_file(staged_source)
            _remove_file(staged_pyc)
    finally:
        shutil.rmtree(str(runtime_work), ignore_errors=True)


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
