from pathlib import Path
import re

ci = Path('windows-builder/final_ci.ps1')
text = ci.read_text(encoding='utf-8')

exe_pattern = re.compile(
    r"\$marker=Join-Path \$env:RUNNER_TEMP 'exe\.ok'.*?Write-Host 'EXE_RUNTIME_OK'",
    re.S,
)
exe_replacement = r'''$p=Start-Process $exe -PassThru
Start-Sleep -Seconds 12
if($p.HasExited){
  throw "exe closed unexpectedly with code $($p.ExitCode)"
}
& taskkill /PID $p.Id /T /F | Out-Null
Write-Host 'EXE_RUNTIME_OK' '''.strip()
text, n1 = exe_pattern.subn(exe_replacement, text, count=1)
if n1 != 1:
    raise SystemExit(f'EXE runtime block patch failed: {n1}')

installed_pattern = re.compile(
    r"\$marker=Join-Path \$env:RUNNER_TEMP 'installed\.ok'.*?(?=\$desktop=Join-Path)",
    re.S,
)
installed_replacement = r'''$p=Start-Process $installed -PassThru
Start-Sleep -Seconds 12
if($p.HasExited){
  throw "installed exe closed unexpectedly with code $($p.ExitCode)"
}
& taskkill /PID $p.Id /T /F | Out-Null
Write-Host 'INSTALLED_EXE_RUNTIME_OK'
'''
text, n2 = installed_pattern.subn(installed_replacement, text, count=1)
if n2 != 1:
    raise SystemExit(f'Installed runtime block patch failed: {n2}')

ci.write_text(text, encoding='utf-8')
print('CI_GUI_SURVIVAL_TEST_PATCHED', n1, n2)
