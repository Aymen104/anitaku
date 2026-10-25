param(
    [string]$Serial = 'emulator-5554',
    [switch]$SkipInstall
)
$ErrorActionPreference = 'Continue'
$adb = 'C:\Users\pc\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\adb.exe'
$apk = 'C:\Users\pc\AppData\Local\Temp\anitaku\signed\patched-aligned-debugSigned.apk'
$tokenFile = 'C:\Users\pc\AppData\Local\Temp\anitaku\access_token.txt'
$token = (Get-Content -Raw $tokenFile).Trim()
$pkg = 'com.anitaku'
$S = @('-s', $Serial)

function A { param([Parameter(ValueFromRemainingArguments=$true)]$Args) & $adb @S $Args }

Write-Output '=== devices ==='
& $adb devices -l

Write-Output '=== wait-for-device ==='
& $adb @S wait-for-device

Write-Output '=== root ==='
& $adb @S root
Start-Sleep -Seconds 3
& $adb @S wait-for-device

if (-not $SkipInstall) {
    Write-Output '=== install ==='
    & $adb @S install -r -d $apk
}

Write-Output '=== grant notification permission ==='
A shell pm grant $pkg android.permission.POST_NOTIFICATIONS 2>&1 | Out-Null

Write-Output '=== resolve app uid ==='
$uid = (A shell dumpsys package $pkg | Select-String 'userId=(\d+)' | Select-Object -First 1)
Write-Output $uid
$uidNum = if ($uid -match 'userId=(\d+)') { $matches[1] } else { '' }
Write-Output "uidNum=$uidNum"

Write-Output '=== stop app ==='
A shell am force-stop $pkg | Out-Null

Write-Output '=== write prefs ==='
$xml = @"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="ACCESS_TOKEN">$token</string>
</map>
"@
$xml | Set-Content -NoNewline -Encoding UTF8 'C:\Users\pc\AppData\Local\Temp\anitaku\Preferences.xml'
A shell "mkdir -p /data/data/$pkg/shared_prefs"
& $adb @S push 'C:\Users\pc\AppData\Local\Temp\anitaku\Preferences.xml' "/data/data/$pkg/shared_prefs/Preferences.xml"
A shell "chown $uidNum`:$uidNum /data/data/$pkg/shared_prefs/Preferences.xml"
A shell "chmod 660 /data/data/$pkg/shared_prefs/Preferences.xml"
A shell "ls -l /data/data/$pkg/shared_prefs/"

Write-Output '=== clear logcat ==='
A logcat -c

Write-Output '=== launch app ==='
A shell am start -n "$pkg/.ui.splash.SplashActivity"
Start-Sleep -Seconds 25

Write-Output '=== EPPOLL log ==='
A logcat -d -s EPPOLL:V | Select-Object -Last 40

Write-Output '=== app process ==='
A shell pidof $pkg
