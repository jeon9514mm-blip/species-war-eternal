param([string]$EditorPath='C:/Program Files/Unity/Hub/Editor/6000.6.4f1/Editor')
$ErrorActionPreference='Stop'
# Resume only the generated Gradle project after Unity has completed IL2CPP,
# shader/asset conversion, and Android project generation for this checkpoint.
$apkRepo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$apkGradle=Join-Path $apkRepo 'Unity/Library/Bee/Android/Prj/IL2CPP/Gradle'
if(!(Test-Path -LiteralPath (Join-Path $apkGradle 'launcher/build.gradle'))){throw 'Generate the Android project with AndroidApkBuilder.Build first.'}
$apkAndroid=Join-Path $EditorPath 'Data/PlaybackEngines/AndroidPlayer'
$env:JAVA_HOME=Join-Path $apkAndroid 'OpenJDK'
$apkTimer=[Diagnostics.Stopwatch]::StartNew()
Push-Location -LiteralPath $apkGradle
try{
    & (Join-Path $env:JAVA_HOME 'bin/java.exe') -classpath (Join-Path $apkAndroid 'Tools/gradle/lib/gradle-launcher-9.3.1.jar') org.gradle.launcher.GradleMain '-Dorg.gradle.jvmargs=-Xmx1024m' '-Dorg.gradle.parallel=false' --no-daemon --max-workers=2 assembleRelease
    if($LASTEXITCODE -ne 0){throw 'Gradle assembleRelease failed.'}
}finally{Pop-Location}
$apkGenerated=Join-Path $apkGradle 'launcher/build/outputs/apk/release/launcher-release.apk'
$apkOutput=Join-Path $apkRepo 'Unity/Builds/Android/EternalUnity-0.1.20-arm64.apk'
Copy-Item -LiteralPath $apkGenerated -Destination $apkOutput
& (Join-Path $PSScriptRoot 'verify-android-apk.ps1') -EditorPath $EditorPath
$apkValidation=Get-Content -LiteralPath (Join-Path $apkRepo 'checks/unity-migration-2026-10-08/android-apk-validation-cp20.json') -Raw | ConvertFrom-Json
if(!$apkValidation.passed){throw 'APK validation did not pass.'}
$apkTimer.Stop()
$apkResult=[ordered]@{result='Succeeded';stage='Gradle packaging of Unity-generated Android/IL2CPP project';gradle_exit_code=0;gradle_version='9.3.1';java_heap_mb=1024;max_workers=2;parallel=$false;daemon=$false;duration_seconds=$apkTimer.Elapsed.TotalSeconds;output='Unity/Builds/Android/EternalUnity-0.1.20-arm64.apk';bytes=$apkValidation.bytes;sha256=$apkValidation.sha256;package=$apkValidation.package;version=$apkValidation.version;version_code=20;apk_validation_passed=$true;device_run_verified=$false;note='The earlier integrated Editor build ran out of disk space during Gradle packaging. This finishes its generated project after closing the Editor. APK gameplay has not been tested on an Android device.'}
$apkResult|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $apkRepo 'checks/unity-migration-2026-10-08/android-gradle-recovery-cp20.json') -Encoding utf8
[pscustomobject]$apkResult|Select-Object result,bytes,sha256|ConvertTo-Json
