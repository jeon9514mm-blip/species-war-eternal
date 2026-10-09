param([string]$ApkPath='Unity/Builds/Android/EternalUnity-0.1.20-arm64.apk',[string]$EditorPath='C:/Program Files/Unity/Hub/Editor/6000.6.4f1/Editor',[string]$PythonPath='C:/Users/x/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
$ErrorActionPreference='Stop'
$apkRepo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$apkFile=(Resolve-Path -LiteralPath (Join-Path $apkRepo $ApkPath)).Path
if([IO.Path]::GetExtension($apkFile) -ne '.apk'){throw 'Expected an APK file.'}
$apkAndroid=Join-Path $EditorPath 'Data/PlaybackEngines/AndroidPlayer'
$apkTools=Join-Path $apkAndroid 'SDK/build-tools/36.0.0'
$env:JAVA_HOME=Join-Path $apkAndroid 'OpenJDK'
$apkBadging=(& (Join-Path $apkTools 'aapt2.exe') dump badging $apkFile 2>&1|Out-String)
if($LASTEXITCODE -ne 0){throw 'Android manifest could not be read.'}
if($apkBadging -notmatch "package: name='com.specieswar.eternal'" -or $apkBadging -notmatch "versionCode='20'" -or $apkBadging -notmatch "versionName='0.1.20'" -or $apkBadging -notmatch "sdkVersion:'26'" -or $apkBadging -notmatch "targetSdkVersion:'36'" -or $apkBadging -notmatch "native-code: 'arm64-v8a'"){throw 'APK manifest does not match the requested build.'}
$apkSignature=(& (Join-Path $apkTools 'apksigner.bat') verify --verbose --print-certs $apkFile 2>&1|Out-String)
if($LASTEXITCODE -ne 0){throw 'APK signature verification failed.'}
$apkAlignment=(& (Join-Path $apkTools 'zipalign.exe') -c -P 16 -v 4 $apkFile 2>&1|Out-String)
if($LASTEXITCODE -ne 0){throw 'APK ZIP/native-library alignment verification failed.'}
$apkZip=(& $PythonPath -X utf8 (Join-Path $PSScriptRoot 'verify-apk-zip.py') $apkFile|Out-String)
if($LASTEXITCODE -ne 0){throw 'APK ZIP/ELF validation failed.'}
$apkStructure=$apkZip|ConvertFrom-Json
$apkResult=[ordered]@{passed=$true;file=[IO.Path]::GetFileName($apkFile);bytes=(Get-Item -LiteralPath $apkFile).Length;sha256=(Get-FileHash -LiteralPath $apkFile -Algorithm SHA256).Hash.ToLowerInvariant();package='com.specieswar.eternal';version='0.1.20';version_code=20;min_sdk=26;target_sdk=36;arm64_only=$true;signature_verified=$true;alignment_16kb_verified=$true;structure=$apkStructure;badging=$apkBadging.Trim();signature=$apkSignature.Trim();device_run_verified=$false;note='Signed sideload test APK. ZIP, manifest, native ELF headers, signature and alignment checks do not establish Android gameplay or FPS.'}
$apkResult|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $apkRepo 'checks/unity-migration-2026-10-08/android-apk-validation-cp20.json') -Encoding utf8
[pscustomobject]$apkResult|Select-Object passed,file,bytes,sha256,device_run_verified|ConvertTo-Json
