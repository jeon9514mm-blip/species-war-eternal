"""Real Mobile rendering, production timing, native process memory; isolated save."""
from pathlib import Path
import json,os,subprocess,tempfile,threading,time,ctypes
from ctypes import wintypes
repo=Path(__file__).resolve().parents[3]
output=repo/'checks/ultra-vfx-2026-10-08/review'
output.mkdir(parents=True,exist_ok=True)
binary=repo.parent/'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
class Counters(ctypes.Structure):
    _fields_=[('cb',wintypes.DWORD),('PageFaultCount',wintypes.DWORD)]+[(key,ctypes.c_size_t) for key in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage']]
class ProcessEntry(ctypes.Structure):
    _fields_=[('dwSize',wintypes.DWORD),('cntUsage',wintypes.DWORD),('th32ProcessID',wintypes.DWORD),('th32DefaultHeapID',ctypes.c_size_t),('th32ModuleID',wintypes.DWORD),('cntThreads',wintypes.DWORD),('th32ParentProcessID',wintypes.DWORD),('pcPriClassBase',wintypes.LONG),('dwFlags',wintypes.DWORD),('szExeFile',wintypes.WCHAR*260)]
def process_ids(parent):
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    kernel.CreateToolhelp32Snapshot.restype=wintypes.HANDLE
    kernel.Process32FirstW.argtypes=[wintypes.HANDLE,ctypes.POINTER(ProcessEntry)]
    kernel.Process32NextW.argtypes=[wintypes.HANDLE,ctypes.POINTER(ProcessEntry)]
    kernel.CloseHandle.argtypes=[wintypes.HANDLE]
    snapshot=kernel.CreateToolhelp32Snapshot(2,0);rows=[]
    if snapshot==ctypes.c_void_p(-1).value:return [parent]
    try:
        row=ProcessEntry();row.dwSize=ctypes.sizeof(row)
        valid=kernel.Process32FirstW(snapshot,ctypes.byref(row))
        while valid:
            rows.append((row.th32ProcessID,row.th32ParentProcessID,str(row.szExeFile)))
            valid=kernel.Process32NextW(snapshot,ctypes.byref(row))
    finally:kernel.CloseHandle(snapshot)
    owned={parent}
    for _ in range(3):
        for pid,owner,name in rows:
            if owner in owned and name.startswith('Godot_v4.7.2-stable_win64'):owned.add(pid)
    return sorted(owned)
def memory(pid):
    kernel=ctypes.WinDLL('kernel32',use_last_error=True);psapi=ctypes.WinDLL('psapi',use_last_error=True)
    kernel.OpenProcess.restype=wintypes.HANDLE;kernel.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD]
    kernel.CloseHandle.argtypes=[wintypes.HANDLE]
    psapi.GetProcessMemoryInfo.argtypes=[wintypes.HANDLE,ctypes.POINTER(Counters),wintypes.DWORD]
    handle=kernel.OpenProcess(0x1000|0x10,False,pid)
    if not handle:return None
    try:
        value=Counters();value.cb=ctypes.sizeof(value)
        if not psapi.GetProcessMemoryInfo(handle,ctypes.byref(value),value.cb):return None
        return {'working_set_bytes':value.WorkingSetSize,'private_bytes':value.PrivateUsage,'peak_working_set_bytes':value.PeakWorkingSetSize}
    finally:kernel.CloseHandle(handle)
samples=[]
with tempfile.TemporaryDirectory(dir=repo.parent/'validation',prefix='ultra-review-',ignore_cleanup_errors=True) as temp:
    env=dict(os.environ,GAME_AUDIT_OUTPUT=str(output),APPDATA=temp,XDG_DATA_HOME=temp,XDG_CONFIG_HOME=temp,XDG_CACHE_HOME=temp)
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    with (output/'capture.log').open('w',encoding='utf-8') as log:
        p=subprocess.Popen([str(binary),'--path',str(repo),'--rendering-method','mobile','--audio-driver','Dummy','--disable-vsync','--script','res://tools/diagnostics/ultra-vfx-2026-10-08/UltraPerformanceReview.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,startupinfo=startup)
        started=time.monotonic()
        while p.poll() is None:
            details=[dict(pid=pid,**value) for pid in process_ids(p.pid) if (value:=memory(pid))]
            if details:samples.append(dict(seconds=time.monotonic()-started,processes=details,**{key:sum(x[key] for x in details) for key in ['working_set_bytes','private_bytes','peak_working_set_bytes']}))
            if time.monotonic()-started>240:p.terminate();raise TimeoutError('Review exceeded240s')
            time.sleep(.5)
        returncode=p.returncode
text=(output/'capture.log').read_text(encoding='utf-8')
(output/'process-memory.json').write_text(json.dumps({'scope':'Windows Godot engine and its console wrapper combined; shared GPU not independently counted','samples':samples,'max_working_set_bytes':max((x['working_set_bytes'] for x in samples),default=0),'max_private_bytes':max((x['private_bytes'] for x in samples),default=0)},indent=2)+'\n')
if returncode or 'FINAL_POLISH_REVIEW_OK' not in text or any(x in text for x in ['ERROR:','SCRIPT ERROR','leaked at exit']):
    print('GODOT_REVIEW_EXIT',returncode);print(text[-16000:]);raise SystemExit(1)
print((output/'performance.json').read_text(encoding='utf-8'))
print('NATIVE_PROCESS_MEMORY_OK',max((x['working_set_bytes'] for x in samples),default=0))
