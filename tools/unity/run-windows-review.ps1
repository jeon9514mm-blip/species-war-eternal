param([int]$TimeoutSeconds=150,[int]$Width=1600,[int]$Height=900,[switch]$ShowWindow)
$ErrorActionPreference='Stop'
$reviewRepo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$reviewBuild=(Resolve-Path -LiteralPath (Join-Path $reviewRepo 'Unity/Builds/WindowsReview')).Path
$reviewExe=Join-Path $reviewBuild 'EternalUnity-Review.exe'
$reviewReport=Join-Path $reviewBuild 'standalone-benchmark.json'
$reviewLog=Join-Path $reviewBuild 'player-benchmark.log'
$reviewStart=[DateTime]::UtcNow
$reviewWindow=if($ShowWindow){'Normal'}else{'Hidden'}
$reviewProcess=Start-Process -FilePath $reviewExe -WorkingDirectory $reviewBuild -WindowStyle $reviewWindow -ArgumentList @('--eternal-benchmark',"`"$reviewReport`"",'--eternal-review-width',$Width,'--eternal-review-height',$Height,'-screen-fullscreen','0','-logFile',"`"$reviewLog`"") -PassThru
$reviewPeak=0L
while(-not $reviewProcess.HasExited){
    $reviewProcess.Refresh()
    if(-not $reviewProcess.HasExited){$reviewPeak=[Math]::Max($reviewPeak,$reviewProcess.WorkingSet64)}
    if(([DateTime]::UtcNow-$reviewStart).TotalSeconds -gt $TimeoutSeconds){throw 'The launched review benchmark exceeded its time budget; inspect its process and log before retrying.'}
    Start-Sleep -Milliseconds 500
}
if($reviewProcess.ExitCode -ne 0){throw "Review benchmark exited with code $($reviewProcess.ExitCode). Inspect the local player log."}
$reviewFile=Get-Item -LiteralPath $reviewReport
if($reviewFile.LastWriteTimeUtc -lt $reviewStart){throw 'The benchmark did not write a fresh report.'}
$reviewData=Get-Content -LiteralPath $reviewReport -Raw | ConvertFrom-Json
$reviewData | Add-Member -NotePropertyName host_peak_process_working_set_bytes -NotePropertyValue $reviewPeak -Force
$reviewData | Add-Member -NotePropertyName host_memory_sample_interval_ms -NotePropertyValue 500 -Force
$reviewData | Add-Member -NotePropertyName visible_review_window -NotePropertyValue ([bool]$ShowWindow) -Force
$reviewData | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $reviewReport -Encoding utf8
$reviewData.segments | Select-Object mode,samples,mean_frame_ms,p95_frame_ms,p99_frame_ms,maximum_frame_ms,frames_over_25_ms,unity_allocated_bytes,reused_hero_views
Write-Output "Fresh benchmark completed; host sampled peak working set: $reviewPeak bytes."
