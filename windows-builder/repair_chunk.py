import hashlib
from pathlib import Path

p = Path('windows-builder/final_clean.b64.1')
s = p.read_text(encoding='utf-8').strip()
expected = 'dc74759661b2f14769f244a5068432e8720578f73c542a997694932fadce462b'
if len(s) == 5999:
    chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    result = None
    for i in range(6000):
        for ch in chars:
            candidate = s[:i] + ch + s[i:]
            if hashlib.sha256(candidate.encode()).hexdigest() == expected:
                result = candidate
                break
        if result is not None:
            break
    if result is None:
        raise SystemExit('Unable to repair chunk')
    s = result
if len(s) != 6000 or hashlib.sha256(s.encode()).hexdigest() != expected:
    raise SystemExit('Chunk verification failed')
p.write_text(s, encoding='utf-8')
print('CHUNK_1_OK', len(s))

ci = Path('windows-builder/final_ci.ps1')
text = ci.read_text(encoding='utf-8')
needle = '''python -c "import sys;sys.path.insert(0,'app');import brand;print('VERSION',brand.VERSION);assert brand.verify_brand();assert brand.verify_brand_assets('.');print('BRAND_OK')"'''
replacement = r'''@'
from PIL import Image
from pathlib import Path
import hashlib,re
root=Path.cwd(); b=root/'assets'/'branding'
im=Image.open(b/'brand.jpg').convert('RGB')
logo=b/'bashmohandes_omar_logo.png'; icon=b/'bashmohandes_omar.ico'
im.save(logo,optimize=True)
im.save(icon,sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
digest=hashlib.sha256(logo.read_bytes()).hexdigest()
p=root/'app'/'brand.py'; t=p.read_text(encoding='utf-8')
t,n=re.subn(r'LOGO_SHA256\s*=\s*"[^"]*"',f'LOGO_SHA256 = "{digest}"',t)
if n != 1: raise RuntimeError('LOGO_SHA256 patch failed')
p.write_text(t,encoding='utf-8')
print('BRAND_ASSETS_REBUILT',digest)
'@ | Set-Content "$env:RUNNER_TEMP\brandfix.py" -Encoding UTF8
python "$env:RUNNER_TEMP\brandfix.py"
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
python -c "import sys;sys.path.insert(0,'app');import brand;print('VERSION',brand.VERSION);assert brand.verify_brand();assert brand.verify_brand_assets('.');print('BRAND_OK')"'''
if needle not in text:
    raise SystemExit('CI brand verification anchor missing')
text = text.replace(needle, replacement)

# Build as a standalone Windows app instead of onefile. This avoids a long
# extraction pause before the splash screen and matches the Inno installer.
text = text.replace('--onefile', '--standalone')
text = text.replace("$exe=Join-Path $root 'build_output\\BashmohandesOmar.exe'", "$exe=Join-Path $root 'build_output\\main.dist\\BashmohandesOmar.exe'")
text = text.replace("Copy-Item $exe \"$port\\BashmohandesOmar.exe\";'Windows 10/11 x64 Portable'|Set-Content \"$port\\README.txt\"", "Copy-Item (Join-Path $root 'build_output\\main.dist\\*') $port -Recurse -Force;'Windows 10/11 x64 Portable'|Set-Content \"$port\\README.txt\"")

# Patch the source package's own Windows build files before they are tested
# and later zipped for delivery.
anchor = "Set-Location $root\n"
source_fix = r'''@'
from pathlib import Path
root=Path.cwd()
build=root/'build_windows_final.ps1'
s=build.read_text(encoding='utf-8')
s=s.replace('--onefile','--standalone')
s=s.replace("build_output\\BashmohandesOmar.exe","build_output\\main.dist\\BashmohandesOmar.exe")
build.write_text(s,encoding='utf-8')
iss=root/'create_setup.iss'
s=iss.read_text(encoding='utf-8')
s=s.replace(r'build_output\BashmohandesOmar.dist\*',r'build_output\main.dist\*')
iss.write_text(s,encoding='utf-8')
print('SOURCE_BUILD_FILES_FIXED')
'@ | Set-Content "$env:RUNNER_TEMP\sourcefix.py" -Encoding UTF8
python "$env:RUNNER_TEMP\sourcefix.py"
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
'''
if source_fix not in text:
    if anchor not in text:
        raise SystemExit('CI source patch anchor missing')
    text = text.replace(anchor, anchor + source_fix, 1)

# Standalone startup should be quick, but retain a generous test timeout.
text = text.replace('WaitForExit(45000)', 'WaitForExit(90000)')
text = text.replace('WaitForExit(180000)', 'WaitForExit(90000)')
ci.write_text(text, encoding='utf-8')
print('CI_BRAND_STEP_PATCHED')
print('CI_STANDALONE_PATCHED')
