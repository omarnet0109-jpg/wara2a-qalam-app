$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
@'
import base64,hashlib,itertools,pathlib,subprocess
repo=pathlib.Path.cwd(); expected='20aeeb9431d3a9687eb120a0f16460ee8fb9a01d43ec9d8686a7dde43e07df0e'
paths=[f'windows-builder/source.b64.{i:02d}' for i in range(12)]
def git(*a): return subprocess.check_output(['git',*a],cwd=repo,text=True,encoding='utf-8')
versions=[]
for path in paths:
    vals=[]
    for c in git('rev-list','--all','--',path).splitlines():
        try:v=git('show',f'{c}:{path}').strip()
        except subprocess.CalledProcessError:continue
        if v not in vals:vals.append(v)
    if not vals: raise RuntimeError('missing source history '+path)
    versions.append(vals)
found=None
for combo in itertools.product(*versions):
    p=list(combo)
    if len(p[8])==15999:p[8]=p[8][:12322]+'i'+p[8][12322:]
    if len(p[10])==16000 and p[10][6752]=='W':p[10]=p[10][:6752]+'V'+p[10][6753:]
    try:raw=base64.b64decode(''.join(p),validate=True)
    except:continue
    if hashlib.sha256(raw).hexdigest()==expected:found=raw;break
if found is None:raise RuntimeError('source recovery failed')
(repo/'windows-builder/source.zip').write_bytes(found)
print('SOURCE_OK',len(found),hashlib.sha256(found).hexdigest())
'@ | Set-Content "$env:RUNNER_TEMP\recover.py" -Encoding UTF8
python "$env:RUNNER_TEMP\recover.py"
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
Expand-Archive 'windows-builder/source.zip' 'windows-builder/src' -Force
$root=(Resolve-Path 'windows-builder/src').Path

@'
import base64,hashlib,pathlib,zipfile,re
repo=pathlib.Path.cwd(); parts=sorted(repo.glob('windows-builder/final_patch.b64.*'))
if not parts: raise RuntimeError('final patch parts missing')
text=''.join(p.read_text(encoding='utf-8') for p in parts)
text=re.sub(r'\s+','',text)
print('PATCH_B64_CHARS',len(text))
raw=base64.b64decode(text,validate=True)
d=hashlib.sha256(raw).hexdigest(); print('PATCH',d,len(raw))
if d!='c793507ff503cbd0a906a4f7cb7dc0fb182b055d786965b03a19a83c7e23c362':raise RuntimeError('patch hash mismatch')
z=repo/'windows-builder/final_patch.zip'; z.write_bytes(raw)
with zipfile.ZipFile(z) as f:
    bad=f.testzip()
    if bad:raise RuntimeError('patch corrupt '+bad)
    f.extractall(repo/'windows-builder/src')
print('PATCH_OK')
'@ | Set-Content "$env:RUNNER_TEMP\patch.py" -Encoding UTF8
python "$env:RUNNER_TEMP\patch.py"
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}

Set-Location $root
python -m pip install --upgrade pip
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
python -m pip install -r requirements.txt
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
python -m pip install pillow nuitka ordered-set zstandard
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}

python -m compileall -q app
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
python -c "import sys;sys.path.insert(0,'app');import brand;print('VERSION',brand.VERSION);assert brand.verify_brand();assert brand.verify_brand_assets('.');print('BRAND_OK')"
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}

$env:QTWEBENGINE_CHROMIUM_FLAGS='--disable-gpu --no-sandbox';$env:QTWEBENGINE_DISABLE_SANDBOX='1'
$marker=Join-Path $env:RUNNER_TEMP 'src.ok';Remove-Item $marker -Force -ErrorAction SilentlyContinue;$env:OMAR_SMOKE_MARKER=$marker
$p=Start-Process python -ArgumentList 'app\main.py','--runtime-smoke-test' -PassThru
if(-not $p.WaitForExit(30000)){Stop-Process $p.Id -Force;throw 'source runtime timeout'}
if($p.ExitCode-ne 0 -or -not(Test-Path $marker)){throw 'source runtime failed'}
Write-Host 'SOURCE_RUNTIME_OK'

python -m nuitka --assume-yes-for-downloads --onefile --windows-console-mode=disable --enable-plugin=pyside6 --include-data-dir=assets=assets --windows-icon-from-ico="assets\branding\bashmohandes_omar.ico" --product-name="الباشمهندس عمر" --file-description="استوديو تصميم وبرمجة المواقع" --product-version=9.1.0.0 --file-version=9.1.0.0 --copyright="جميع الحقوق محفوظة - الباشمهندس عمر - 01158022519" --output-dir=build_output --output-filename="BashmohandesOmar.exe" app\main.py
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
$exe=Join-Path $root 'build_output\BashmohandesOmar.exe';if(-not(Test-Path $exe)){throw 'exe missing'}
$b=[IO.File]::ReadAllBytes($exe);if($b[0]-ne 0x4D -or $b[1]-ne 0x5A){throw 'invalid exe'}
$marker=Join-Path $env:RUNNER_TEMP 'exe.ok';Remove-Item $marker -Force -ErrorAction SilentlyContinue;$env:OMAR_SMOKE_MARKER=$marker
$p=Start-Process $exe -ArgumentList '--runtime-smoke-test' -PassThru
if(-not $p.WaitForExit(45000)){Stop-Process $p.Id -Force;throw 'exe runtime timeout'}
if($p.ExitCode-ne 0 -or -not(Test-Path $marker)){throw 'exe runtime failed'}
Write-Host 'EXE_RUNTIME_OK'

choco install innosetup --no-progress -y
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' 'create_setup.iss'
if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
$setup=Join-Path $root 'installer_output\Program-Setup-Final.exe';if(-not(Test-Path $setup)){throw 'setup missing'}
$b=[IO.File]::ReadAllBytes($setup);if($b[0]-ne 0x4D -or $b[1]-ne 0x5A){throw 'invalid setup'}
Copy-Item $setup (Join-Path $repo 'Program-Setup-Final.exe') -Force

$dir=Join-Path $env:RUNNER_TEMP 'Installed';$p=Start-Process $setup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$dir",'/TASKS=desktopicon' -Wait -PassThru
if($p.ExitCode-ne 0){throw 'install failed'}
$installed=Join-Path $dir 'BashmohandesOmar.exe';if(-not(Test-Path $installed)){throw 'installed exe missing'}
$marker=Join-Path $env:RUNNER_TEMP 'installed.ok';Remove-Item $marker -Force -ErrorAction SilentlyContinue;$env:OMAR_SMOKE_MARKER=$marker
$p=Start-Process $installed -ArgumentList '--runtime-smoke-test' -PassThru
if(-not $p.WaitForExit(45000)){Stop-Process $p.Id -Force;throw 'installed runtime timeout'}
if($p.ExitCode-ne 0 -or -not(Test-Path $marker)){throw 'installed runtime failed'}
$desktop=Join-Path ([Environment]::GetFolderPath('Desktop')) 'الباشمهندس عمر.lnk';if(-not(Test-Path $desktop)){throw 'desktop shortcut missing'}
$start=Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\الباشمهندس عمر.lnk';if(-not(Test-Path $start)){throw 'start shortcut missing'}
$reg=Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue | ForEach-Object {Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue} | Where-Object {$_.DisplayName -eq 'الباشمهندس عمر'} | Select-Object -First 1
if(-not $reg){throw 'Apps and Features uninstall registration missing'}
$uninst=Get-ChildItem $dir -Filter 'unins*.exe'|Select-Object -First 1;if(-not $uninst){throw 'uninstaller missing'}
$p=Start-Process $uninst.FullName -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru;if($p.ExitCode-ne 0){throw 'uninstall failed'}
Write-Host 'INSTALLER_FULL_TEST_OK'

$srcStage=Join-Path $env:RUNNER_TEMP 'Program-Source-Final';New-Item -ItemType Directory -Force $srcStage|Out-Null;Copy-Item "$root\*" $srcStage -Recurse -Force;Remove-Item "$srcStage\build_output","$srcStage\installer_output" -Recurse -Force -ErrorAction SilentlyContinue
Compress-Archive "$srcStage\*" (Join-Path $repo 'Program-Source-Final.zip') -Force
$port=Join-Path $env:RUNNER_TEMP 'Program-Portable-Final';New-Item -ItemType Directory -Force $port|Out-Null;Copy-Item $exe "$port\BashmohandesOmar.exe";'Windows 10/11 x64 Portable'|Set-Content "$port\README.txt";Compress-Archive "$port\*" (Join-Path $repo 'Program-Portable-Final.zip') -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach($z in 'Program-Source-Final.zip','Program-Portable-Final.zip'){$a=[IO.Compression.ZipFile]::OpenRead((Join-Path $repo $z));$a.Dispose()}
Get-FileHash (Join-Path $repo 'Program-Source-Final.zip') -Algorithm SHA256
Get-FileHash (Join-Path $repo 'Program-Setup-Final.exe') -Algorithm SHA256
Get-FileHash (Join-Path $repo 'Program-Portable-Final.zip') -Algorithm SHA256
Write-Host 'FINAL_WINDOWS_VERIFIED'
