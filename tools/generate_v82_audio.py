#!/usr/bin/env python3
"""Rebuild original, procedurally composed v82 audio. No third-party samples.
Requires numpy/scipy/soundfile + ffmpeg with libvorbis. Run from any directory.
Generated tracks are synthesized production placeholders, not recorded instruments.
"""
from pathlib import Path
import hashlib,json,subprocess,tempfile
import numpy as np
import soundfile as sf
from scipy.signal import butter,sosfilt
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'audio'/'v82'; OUT.mkdir(parents=True,exist_ok=True)
SR=22050
rng=np.random.default_rng(8201)
manifest={}
def frequency(m): return 440*2**((m-69)/12)
def note(m,seconds,kind='pluck'):
 t=np.arange(int(SR*seconds))/SR; f=frequency(m)
 if kind=='pad':
  env=np.minimum(t/.2,1)*np.minimum((seconds-t)/.4,1)
  return .17*env*(np.sin(2*np.pi*f*t)+.27*np.sin(2*np.pi*f*2.002*t)+.16*np.sin(2*np.pi*f*.997*t))
 if kind=='bass': return .22*np.exp(-2*t)*np.minimum(t/.012,1)*(np.sin(2*np.pi*f*t)+.15*np.sin(2*np.pi*2*f*t))
 return .24*np.exp(-4.5*t/max(.25,seconds))*np.minimum(t/.006,1)*(np.sin(2*np.pi*f*t)+.32*np.sin(2*np.pi*2*f*t)*np.exp(-4*t)+.15*np.sin(2*np.pi*3*f*t)*np.exp(-7*t))
def noise(seconds,low=100,high=7000):
 x=rng.normal(0,1,int(SR*seconds)); return sosfilt(butter(2,[low,high],fs=SR,btype='bandpass',output='sos'),x)
def save(name,x,loop=False):
 x=np.nan_to_num(x); peak=float(np.max(np.abs(x)))
 if peak>.78:x*=.78/peak
 # Non-looping effects fade to silence; tracks cross a quiet loop boundary.
 fade=min(len(x)//4,int(.025*SR)); x[:fade]*=np.linspace(0,1,fade)[:,None] if x.ndim==2 else np.linspace(0,1,fade)
 x[-fade:]*=np.linspace(1,0,fade)[:,None] if x.ndim==2 else np.linspace(1,0,fade)
 path=OUT/(name+('.ogg' if loop else '.wav'))
 if loop:
  with tempfile.NamedTemporaryFile(suffix='.wav') as f:
   sf.write(f.name,x,SR,subtype='PCM_16')
   subprocess.run(['ffmpeg','-loglevel','error','-y','-i',f.name,'-c:a','libvorbis','-q:a','3','-map_metadata','-1',str(path)],check=True)
 else:sf.write(path,x,SR,subtype='PCM_16')
 decoded,sr=sf.read(path)
 manifest[name]={'file':path.relative_to(ROOT).as_posix(),'loop':loop,'seconds':round(len(decoded)/sr,3),'sample_rate':sr,'channels':1 if decoded.ndim==1 else decoded.shape[1],'peak':round(float(np.abs(decoded).max()),5),'rms':round(float(np.sqrt(np.mean(decoded**2))),5),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
def compose(name,tempo,chords,melody):
 beat=60/tempo; seconds=beat*64; n=int(seconds*SR); track=np.zeros((n,2))
 def add(x,pos,pan=0):
  start=int(pos*SR); ids=(np.arange(len(x))+start)%n
  track[ids,0]+=x*np.sqrt((1-pan)/2); track[ids,1]+=x*np.sqrt((1+pan)/2)
 for bar in range(16):
  root,third=chords[(bar//2)%len(chords)]
  for m in [root+12,root+third+12,root+19]:add(note(m,beat*4.15,'pad')*.42,bar*4*beat)
  for step in range(8):
   m=[root+24,root+third+24,root+31,root+36][(step+bar)%4]
   add(note(m,beat*.8)*.26,(bar*4+step*.5)*beat,(-.3 if step%2 else .3))
  for step in [0,2]:add(note(root,beat*1.6,'bass')*.45,(bar*4+step)*beat)
  for step in range(4):
   m=melody[(bar*4+step)%len(melody)];add(note(m,beat*1.4)*.55,(bar*4+step)*beat,0.12)
  for step in range(4):
   tt=np.arange(int(SR*.16))/SR
   drum=np.sin(2*np.pi*(55*tt+80*.025*(1-np.exp(-tt/.025))))*np.exp(-tt*30)*.12
   add(drum,(bar*4+step)*beat)
   hh=noise(.09,3500,8500)*np.exp(-np.arange(int(.09*SR))/SR*70)*.035
   add(hh,(bar*4+step+.5)*beat,-.4)
 # Mix at conservative level, no runtime synthesis/FFT.
 save(name,track,True)
compose('meadow',104,[(50,4),(47,3),(43,4),(45,4)],[74,78,81,78,76,74,71,69,71,74,78,76,73,76,81,78])
compose('mine',92,[(38,3),(34,4),(41,4),(36,4)],[62,65,69,65,60,62,65,69,65,69,72,69,67,65,62,60])
compose('forest',80,[(45,3),(41,4),(48,4),(43,4)],[81,84,88,84,79,81,76,79,81,83,84,88,86,83,81,76])
compose('boss',132,[(38,3),(39,4),(34,4),(45,4)],[74,74,77,81,79,77,74,72,75,77,81,84,82,79,77,73])
for zone,lo,hi in [('meadow',150,1200),('mine',70,550),('forest',500,2400)]:
 seconds=12;t=np.arange(SR*seconds)/SR;x=noise(seconds,lo,hi)*.023*(.75+.25*np.sin(2*np.pi*t/seconds))
 for start in ([1,5,9] if zone=='meadow' else [2,6,10]):
  pitch=90 if zone=='mine' else (88 if zone=='forest' else 95)
  sig=note(pitch,.6)*(.09 if zone=='mine' else .055);i=int(start*SR);x[i:i+len(sig)]+=sig
 fade=int(.3*SR);x[:fade]*=np.linspace(0,1,fade);x[-fade:]*=np.linspace(1,0,fade)
 save('ambient_'+zone,np.column_stack([x,np.roll(x,193)*.87]),True)
def chime(notes,d=.6):
 x=np.zeros(int(SR*d))
 for i,m in enumerate(notes):
  start=int(i*.055*SR);a=note(m,d-i*.055)*.65;x[start:start+len(a)]+=a[:len(x)-start]
 return x
save('ui_click',note(88,.075)*.42)
save('equip',chime([67,74,79],.32))
save('upgrade',chime([62,66,69,74,81],.65))
save('reward',chime([74,78,81,86],.7))
save('summon',chime([57,64,69,73,76,81],1.1))
save('victory',chime([62,66,69,74,78,81],1.4))
save('defeat',chime([65,62,57],.75))
t=np.arange(int(SR*.22))/SR
save('sword',noise(.22,600,6500)*np.exp(-t*22)*.22+note(57,.22)*.18)
save('bow',noise(.18,1200,8000)*np.exp(-np.arange(int(.18*SR))/SR*24)*.12+note(81,.18)*.2)
save('magic',chime([81,88],.34))
save('guard',chime([38,50,57],.4))
save('heal',chime([74,81,86],.6))
save('control',chime([57,69,70],.4))
save('ultimate',chime([38,50,57,62,69,74],.85))
save('critical',noise(.18,500,7500)*np.exp(-np.arange(int(.18*SR))/SR*30)*.25+chime([86,93],.18))
save('boss_warning',chime([50,51,62],.55))
save('shield_break',noise(.45,900,7500)*np.exp(-np.arange(int(.45*SR))/SR*15)*.27+chime([62,74,86],.45))
(OUT/'manifest.json').write_text(json.dumps({'origin':'Original procedural compositions and synthesized SFX; no third-party samples. Draft audio, not a recorded sound pack.','generator':'tools/generate_v82_audio.py','tracks':manifest},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'files':len(manifest),'bytes':sum(v['bytes'] for v in manifest.values()),'seconds':sum(v['seconds'] for v in manifest.values())}))
