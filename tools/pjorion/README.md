# PjOrion runtime for protected releases

Expected version: **PjOrion 1.3.5 (11.08.2019)**.

The release workflow downloads the original package, extracts `PjOrion.exe`, and refuses to continue unless the executable matches the copy supplied for the MASTERS build setup.

- `PjOrion.exe` size: `2905088` bytes
- SHA-256: `aecca1ade73418b37e27669d8b4caba386bbc860ea7ed73d7f1aa6e7920738aa`
- Python runtime: **x86 Python 2.7** (`C:\Python27\python27.dll`)

CLI switches confirmed from the supplied PjOrion 1.3.5 executable:

```text
--compile-file="<file.py>" /exit
--obfuscate-text-file="<file.py>" /exit
--obfuscate-bytecode-file="<file.py>" /exit
--protect-bytecode-file="<file.pyc>" /exit
```

MASTERS currently uses `--obfuscate-bytecode-file` for every Python source in the protected release build. Plain `.py` files are not packaged into the `.wotmod`.

`PjOrion.ini` disables web-update/WOT connection behavior and selects `C:\Python27\python27.dll` for deterministic CI use.
