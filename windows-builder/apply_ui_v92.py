from pathlib import Path
import hashlib

ci = Path('windows-builder/final_ci.ps1')
text = ci.read_text(encoding='utf-8')
payload_path = Path('windows-builder/ui_main_v92.zlib.b64')
payload = payload_path.read_text(encoding='ascii').strip()
expected = '977040541433aaaea73efe73ae419352f6eadffae87bd996798605ecb19a0f4a'

anchor = "python -m compileall -q app"
if anchor not in text:
    raise SystemExit('compile anchor missing')

block = f'''@'\nimport base64,zlib,hashlib,pathlib\npayload={payload!r}\nraw=zlib.decompress(base64.b64decode(payload))\nd=hashlib.sha256(raw).hexdigest()\nif d != {expected!r}:\n    raise RuntimeError(f'ui payload hash mismatch: {{d}}')\np=pathlib.Path('app/main.py')\np.write_bytes(raw)\nprint('SIMPLIFIED_UI_PATCHED', len(raw), d)\n'@ | Set-Content "$env:RUNNER_TEMP\\ui_v92.py" -Encoding UTF8\npython "$env:RUNNER_TEMP\\ui_v92.py"\nif($LASTEXITCODE-ne 0){{exit $LASTEXITCODE}}\n'''

text = text.replace(anchor, block + '\n' + anchor, 1)
ci.write_text(text, encoding='utf-8')
print('CI_SIMPLIFIED_UI_V92_PATCHED')
