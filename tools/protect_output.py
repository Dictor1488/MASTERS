# -*- coding: utf-8 -*-
"""Protect staged GameFace files. Python bytecode protection is handled by PjOrion."""
from __future__ import annotations

import os
import pathlib
import re
import shutil
import subprocess
import tempfile
from typing import List


def _log(message: str) -> None:
    print('[protect] ' + message)


def _read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding='utf-8', errors='strict')


def _write_text(path: pathlib.Path, text: str) -> None:
    path.write_text(text, encoding='utf-8', newline='')


def minify_html(text: str) -> str:
    text = re.sub(r'<!--(?!\[if)[\s\S]*?-->', '', text)
    text = re.sub(r'>\s+<', '><', text)
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n\s*', '', text)
    return text.strip()


def minify_css(text: str) -> str:
    out: List[str] = []
    i = 0
    quote = None
    escape = False
    length = len(text)
    while i < length:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < length else ''
        if quote:
            out.append(ch)
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == quote:
                quote = None
            i += 1
            continue
        if ch in ('"', "'"):
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == '/' and nxt == '*':
            end = text.find('*/', i + 2)
            if end < 0:
                break
            i = end + 2
            continue
        out.append(ch)
        i += 1

    compact = ''.join(out)
    compact = re.sub(r'\s+', ' ', compact)
    compact = re.sub(r'\s*([{}:;,>+~])\s*', r'\1', compact)
    compact = re.sub(r';}', '}', compact)
    return compact.strip()


def _javascript_obfuscator_command() -> List[str]:
    direct = shutil.which('javascript-obfuscator') or shutil.which('javascript-obfuscator.cmd')
    if direct:
        return [direct]
    npx = shutil.which('npx') or shutil.which('npx.cmd')
    if npx:
        return [npx, '--yes', 'javascript-obfuscator']
    raise RuntimeError(
        'javascript-obfuscator is required for protected builds. '
        'Install Node.js (npx) or run: npm install -g javascript-obfuscator'
    )


def obfuscate_js(path: pathlib.Path) -> None:
    command = _javascript_obfuscator_command()
    fd, tmp_name = tempfile.mkstemp(prefix='mastery-js-', suffix='.js')
    os.close(fd)
    tmp = pathlib.Path(tmp_name)
    try:
        args = command + [
            str(path),
            '--output', str(tmp),
            '--compact', 'true',
            '--identifier-names-generator', 'hexadecimal',
            '--rename-globals', 'false',
            '--control-flow-flattening', 'false',
            '--dead-code-injection', 'false',
            '--self-defending', 'false',
            '--string-array', 'true',
            '--string-array-encoding', 'base64',
            '--string-array-threshold', '0.80',
            '--string-array-shuffle', 'true',
            '--string-array-rotate', 'true',
            '--transform-object-keys', 'false',
            '--unicode-escape-sequence', 'false',
        ]
        completed = subprocess.run(
            args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding='utf-8', errors='replace'
        )
        if completed.returncode != 0 or not tmp.is_file() or tmp.stat().st_size == 0:
            raise RuntimeError(
                'javascript-obfuscator failed for %s\n%s' % (path, completed.stdout)
            )
        shutil.copy2(str(tmp), str(path))
    finally:
        try:
            tmp.unlink()
        except OSError:
            pass


def protect_tree(root: pathlib.Path) -> None:
    """Protect staged JS/CSS/HTML in-place. PYC files must already come from PjOrion."""
    root = pathlib.Path(root)
    if not root.is_dir():
        raise RuntimeError('Protection root does not exist: %s' % root)

    js_files = sorted(root.rglob('*.js'))
    css_files = sorted(root.rglob('*.css'))
    html_files = sorted(root.rglob('*.html'))

    for path in js_files:
        obfuscate_js(path)
        _log('JS obfuscated: %s' % path.relative_to(root))

    for path in css_files:
        _write_text(path, minify_css(_read_text(path)))
        _log('CSS minified: %s' % path.relative_to(root))

    for path in html_files:
        _write_text(path, minify_html(_read_text(path)))
        _log('HTML minified: %s' % path.relative_to(root))

    _log('Protected GameFace output complete: js=%d css=%d html=%d' %
         (len(js_files), len(css_files), len(html_files)))
