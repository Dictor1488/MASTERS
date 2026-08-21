# -*- coding: utf-8 -*-
"""Headless Python 2.7 module packer for protected WoT releases.

Compiles the original module to a code object, serializes it with marshal,
compresses it, XORs the payload, stores it as Base64 inside a tiny loader,
and compiles only that loader to the final .pyc.
"""
from __future__ import print_function

import base64
import hashlib
import marshal
import os
import py_compile
import random
import sys
import tempfile
import zlib


def _xor(data, key):
    size = len(key)
    return ''.join(chr(ord(ch) ^ ord(key[i % size])) for i, ch in enumerate(data))


def _chunks(text, width=120):
    return [text[i:i + width] for i in xrange(0, len(text), width)]


def _literal(text):
    parts = _chunks(text)
    if not parts:
        return "''"
    return '(' + '\n'.join(repr(part) for part in parts) + ')'


def _name(seed, index):
    digest = hashlib.sha1(seed + str(index)).hexdigest()[:12]
    return '_o' + digest


def pack(source_path, target_path):
    source_path = os.path.abspath(source_path)
    target_path = os.path.abspath(target_path)

    with open(source_path, 'rb') as fh:
        source = fh.read()

    seed_hex = hashlib.sha256(source).hexdigest()
    seed = seed_hex.encode('ascii')
    fake_filename = '<%s>' % seed_hex[:16]

    code = compile(source, fake_filename, 'exec')
    payload = marshal.dumps(code)
    payload = zlib.compress(payload, 9)

    key = hashlib.sha256(seed + b':masters:protected:').digest()
    encrypted = _xor(payload, key)
    payload_b64 = base64.b64encode(encrypted)
    key_b64 = base64.b64encode(key)

    n_b64 = _name(seed, 1)
    n_z = _name(seed, 2)
    n_m = _name(seed, 3)
    n_k = _name(seed, 4)
    n_d = _name(seed, 5)
    n_i = _name(seed, 6)

    loader = (
        "# -*- coding: ascii -*-\n"
        "import base64 as {b},zlib as {z},marshal as {m}\n"
        "{k}={b}.b64decode({key})\n"
        "{d}={b}.b64decode({payload})\n"
        "{d}=''.join(chr(ord({d}[{i}])^ord({k}[{i}%len({k})])) for {i} in xrange(len({d})))\n"
        "exec {m}.loads({z}.decompress({d})) in globals(),globals()\n"
        "del {b},{z},{m},{k},{d},{i}\n"
    ).format(
        b=n_b64, z=n_z, m=n_m, k=n_k, d=n_d, i=n_i,
        key=_literal(key_b64), payload=_literal(payload_b64))

    target_dir = os.path.dirname(target_path)
    if target_dir and not os.path.isdir(target_dir):
        os.makedirs(target_dir)

    fd, loader_path = tempfile.mkstemp(prefix='masters_', suffix='.py', dir=target_dir or None)
    os.close(fd)
    try:
        with open(loader_path, 'wb') as fh:
            fh.write(loader.encode('ascii'))
        py_compile.compile(loader_path, cfile=target_path, dfile=fake_filename, doraise=True)
    finally:
        try:
            os.remove(loader_path)
        except OSError:
            pass

    if not os.path.isfile(target_path) or os.path.getsize(target_path) <= 8:
        raise RuntimeError('Protected PYC was not created: %s' % target_path)


def main(argv):
    if len(argv) != 3:
        print('Usage: python2 orion_like_packer27.py <source.py> <target.pyc>', file=sys.stderr)
        return 2
    try:
        pack(argv[1], argv[2])
    except Exception as exc:
        print('packer error: %s' % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
