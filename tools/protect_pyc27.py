# -*- coding: utf-8 -*-
"""Python 2.7 helper: remove source metadata/docstrings from compiled .pyc files."""
from __future__ import print_function

import marshal
import os
import sys
import types


def _is_text(value):
    try:
        return isinstance(value, (str, unicode))
    except NameError:
        return isinstance(value, str)


def _protected_code(code):
    consts = []
    for index, value in enumerate(code.co_consts):
        if isinstance(value, types.CodeType):
            value = _protected_code(value)
        elif index == 0 and _is_text(value):
            # Module/class/function docstring. Runtime logic should not need it.
            value = None
        consts.append(value)

    return types.CodeType(
        code.co_argcount,
        code.co_nlocals,
        code.co_stacksize,
        code.co_flags,
        code.co_code,
        tuple(consts),
        code.co_names,
        code.co_varnames,
        '<protected>',
        code.co_name,
        code.co_firstlineno,
        code.co_lnotab,
        code.co_freevars,
        code.co_cellvars,
    )


def protect(path):
    with open(path, 'rb') as fh:
        header = fh.read(8)
        code = marshal.load(fh)
    if not isinstance(code, types.CodeType):
        raise TypeError('Not a Python 2.7 code object: %s' % path)
    code = _protected_code(code)
    temp = path + '.protected.tmp'
    with open(temp, 'wb') as fh:
        fh.write(header)
        marshal.dump(code, fh)
    try:
        os.remove(path)
    except OSError:
        pass
    os.rename(temp, path)


def main(argv):
    failed = False
    for path in argv[1:]:
        try:
            protect(path)
            print('protected pyc: %s' % path)
        except Exception as exc:
            failed = True
            print('failed pyc: %s: %s' % (path, exc))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
