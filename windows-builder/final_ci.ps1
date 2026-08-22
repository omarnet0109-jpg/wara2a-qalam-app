$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
$expected='20aeeb9431d3a9687eb120a0f16460ee8fb9a01d43ec9d8686a7dde43e07df0e'
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
print('SOURCE_OK',len(found))
'@ | Set-Content "$env:RUNNER_TEMP\recover.py" -Encoding UTF8
python "$env:RUNNER_TEMP\recover.py"
Expand-Archive 'windows-builder/source.zip' 'windows-builder/src' -Force
$root=(Resolve-Path 'windows-builder/src').Path
@'
import base64,hashlib,pathlib,zipfile
repo=pathlib.Path.cwd(); parts=sorted(repo.glob('windows-builder/final_patch.b64.*'))
raw=base64.b64decode(''.join(p.read_text().strip() for p in parts),validate=True)
d=hashlib.sha256(raw).hexdigest(); print('PATCH',d,len(raw))
if d!='c793507ff503cbd0a906a4f7cb7dc0fb182b055d786965b03a19a83c7e23c362':raise RuntimeError('patch hash mismatch')
z=repo/'windows-builder/final_patch.zip'; z.write_bytes(raw)
with zipfile.ZipFile(z) as f:
    if f.testzip():raise RuntimeError('patch corrupt')
    f.extractall(repo/'windows-builder/src')
'@ | Set-Content "$env:RUNNER_TEMP\patch.py" -Encoding UTF8
python "$env:RUNNER_TEMP\patch.py"
Set-Location $root
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m pip install pillow nuitka ordered-set zstandard
python -m compileall -q app
python -c "import sys;sys.path.insert(0,'app');import brand;assert brand.verify_brand();assert brand.verify_brand_assets('.');print('BRAND_OK',brand.VERSION)"
$env:QTWEBENGINE_CHROMIUM_FLAGS='--disable-gpu --no-sandbox';$env:QTWEBENGINE_DISABLE_SANDBOX='1'
$marker=Join-Path $env:RUNNER_TEMP 'src.ok';$env:OMAR_SMOKE_MARKER=$marker
$p=Start-Process python -ArgumentList 'app\main.py','--runtime-smoke-test' -PassThru
if(-not $p.WaitForExit(30000)){Stop-Process $p.Id -Force;throw 'source runtime timeout'}
if($p.ExitCode-ne 0 -or -not(Test-Path $marker)){throw 'source runtime failed'}
python -m nuitka --assume-yes-for-downloads --onefile --windows-console-mode=disable --enable-plugin=pyside6 --include-data-dir=assets=assets --windows-icon-from-ico="assets\branding\bashmohandes_omar.ico" --product-name="الباشمهندس عمر" --file-description="استوديو تصميم وبرمجة المواقع" --product-version=9.1.0.0 --file-version=9.1.0.0 --copyright="جميع الحقوق محفوظة - الباشمهندس عمر - 01158022519" --output-dir=build_output --output-filename="BashmohandesOmar.exe" app\main.py
$exe=Join-Path $root 'build_output\BashmohandesOmar.exe';if(-not(Test-Path $exe)){throw 'exe missing'}
$marker=Join-Path $env:RUNNER_TEMP 'exe.ok';$env:OMAR_SMOKE_MARKER=$marker
$p=Start-Process $exe -ArgumentList '--runtime-smoke-test' -PassThru
if(-not $p.WaitForExit(45000)){Stop-Process $p.Id -Force;throw 'exe runtime timeout'}
if($p.ExitCode-ne 0 -or -not(Test-Path $marker)){throw 'exe runtime failed'}
choco install innosetup --no-progress -y
& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' 'create_setup.iss'
$setup=Join-Path $root 'installer_output\Program-Setup-Final.exe';if(-not(Test-Path $setup)){throw 'setup missing'}
Copy-Item $setup (Join-Path $repo 'Program-Setup-Final.exe') -Force
$dir=Join-Path $env:RUNNER_TEMP 'Installed';$p=Start-Process $setup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$dir",'/TASKS=desktopicon' -Wait -PassThru
if($p.ExitCode-ne 0){throw 'install failed'}
$installed=Join-Path $dir 'BashmohandesOmar.exe';if(-not(Test-Path $installed)){throw 'installed exe missing'}
$marker=Join-Path $env:RUNNER_TEMP 'installed.ok';$env:OMAR_SMOKE_MARKER=$marker
$p=Start-Process $installed -ArgumentList '--runtime-smoke-test' -PassThru
if(-not $p.WaitForExit(45000)){Stop-Process $p.Id -Force;throw 'installed runtime timeout'}
if($p.ExitCode-ne 0 -or -not(Test-Path $marker)){throw 'installed runtime failed'}
$desktop=Join-Path ([Environment]::GetFolderPath('Desktop')) 'الباشمهندس عمر.lnk';if(-not(Test-Path $desktop)){throw 'desktop shortcut missing'}
$start=Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\الباشمهندس عمر.lnk';if(-not(Test-Path $start)){throw 'start shortcut missing'}
$uninst=Get-ChildItem $dir -Filter 'unins*.exe'|Select-Object -First 1;if(-not $uninst){throw 'uninstaller missing'}
$p=Start-Process $uninst.FullName -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru;if($p.ExitCode-ne 0){throw 'uninstall failed'}
$srcStage=Join-Path $env:RUNNER_TEMP 'Program-Source-Final';New-Item -ItemType Directory -Force $srcStage|Out-Null;Copy-Item "$root\*" $srcStage -Recurse -Force;Remove-Item "$srcStage\build_output","$srcStage\installer_output" -Recurse -Force -ErrorAction SilentlyContinue
Compress-Archive "$srcStage\*" (Join-Path $repo 'Program-Source-Final.zip') -Force
$port=Join-Path $env:RUNNER_TEMP 'Program-Portable-Final';New-Item -ItemType Directory -Force $port|Out-Null;Copy-Item $exe "$port\BashmohandesOmar.exe";'Windows 10/11 x64 Portable'|Set-Content "$port\README.txt";Compress-Archive "$port\*" (Join-Path $repo 'Program-Portable-Final.zip') -Force
Write-Host 'FINAL_WINDOWS_VERIFIED'
