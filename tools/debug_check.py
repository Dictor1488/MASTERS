#!/usr/bin/env python3
from pathlib import Path
import json, re, sys, tokenize, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
errors=[]
for p in root.rglob('*.json'):
    try: json.loads(p.read_text(encoding='utf-8-sig'))
    except Exception as e: errors.append(f'JSON {p.relative_to(root)}: {e}')
for p in list(root.rglob('*.xml'))+list(root.rglob('*.as3proj')):
    try: ET.parse(str(p))
    except Exception as e: errors.append(f'XML {p.relative_to(root)}: {e}')
for p in root.rglob('*.py'):
    try:
        with p.open('rb') as f: list(tokenize.tokenize(f.readline))
    except Exception as e: errors.append(f'Python tokens {p.relative_to(root)}: {e}')
classes={p.stem for p in root.rglob('*.as')}
refs=set()
for p in root.rglob('*.as'):
    text=p.read_text(encoding='utf-8',errors='ignore')
    refs.update(re.findall(r'\b(?:new|extends|implements)\s+([A-Z]\w+)',text))
for name in sorted(refs):
    if name.startswith(('Mastery','Marks')) and name not in classes:
        errors.append(f'AS3 missing class: {name}')
if errors:
    print('\n'.join('[ERROR] '+e for e in errors)); sys.exit(1)
print('Debug check passed:', root.name)
