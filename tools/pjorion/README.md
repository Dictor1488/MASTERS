# PjOrion runtime for protected releases

Expected version: **PjOrion 1.3.5 (11.08.2019)**.

The protected release workflow does **not** download PjOrion from KoreanRandom. The runtime must be stored in this repository in one of these forms:

- `tools/pjorion/PjOrion.exe`, or
- `tools/pjorion/PjOrion_1.3.5_11.08.2019.rar`

If the RAR is present, the Windows GitHub runner extracts it with 7-Zip and locates `PjOrion.exe` automatically.

Expected executable:

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

MASTERS uses `--obfuscate-bytecode-file` for every Python source in the protected release build. Plain `.py` files are not packaged into the `.wotmod`.

`PjOrion.ini` selects `C:\Python27\python27.dll` for CI use.
