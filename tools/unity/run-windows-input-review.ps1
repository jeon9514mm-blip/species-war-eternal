param([int]$TimeoutSeconds=145,[int]$Width=1920,[int]$Height=1080)
$ErrorActionPreference='Stop'
$reviewRepo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$reviewBuild=(Resolve-Path -LiteralPath (Join-Path $reviewRepo 'Unity/Builds/WindowsReview')).Path
$reviewExe=Join-Path $reviewBuild 'EternalUnity-Review.exe'
$reviewReport=Join-Path $reviewBuild 'native-ui-input.json'
$reviewLog=Join-Path $reviewBuild 'player-input-review.log'
$reviewStart=[DateTime]::UtcNow
# This is the interactive game under visual/input acceptance. A hidden player
# may keep ticking while producing empty screenshots on this Windows host.
$reviewProcess=Start-Process -FilePath $reviewExe -WorkingDirectory $reviewBuild -WindowStyle Normal -ArgumentList @('--eternal-input-qa',"`"$reviewReport`"",'-screen-width',$Width,'-screen-height',$Height,'-screen-fullscreen','0','-logFile',"`"$reviewLog`"") -PassThru
while(-not $reviewProcess.HasExited){
    if(([DateTime]::UtcNow-$reviewStart).TotalSeconds -gt $TimeoutSeconds){throw 'Native input review exceeded its budget; inspect its launched process before retrying.'}
    Start-Sleep -Milliseconds 500
}
$reviewFile=Get-Item -LiteralPath $reviewReport
if($reviewFile.LastWriteTimeUtc -lt $reviewStart){throw 'The native player did not write a fresh report.'}
$reviewData=Get-Content -LiteralPath $reviewReport -Raw | ConvertFrom-Json
$reviewData | Select-Object passed,error,steps_completed,steps_total,comparisons,elapsed_seconds,ultimate_presentations,last_ultimate_hero,last_ultimate_skill | ConvertTo-Json
if($reviewProcess.ExitCode -ne 0 -or -not $reviewData.passed){throw 'Native input acceptance failed. The result above identifies the failed step.'}
