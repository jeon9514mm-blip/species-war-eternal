"""Bake small analytic contact shadow and four deterministic creature cues.

Standard-library offline authoring; no per-frame texture/audio synthesis.
Also set checked-in Godot import options for the Blender runtime assets.
"""
from pathlib import Path
import math
import random
import re
import struct
import wave
import zlib
import json
import hashlib

ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/mobile25d/floor'
def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
size=128
pixels=bytearray()
for y in range(size):
    pixels.append(0)
    for x in range(size):
        radius=math.hypot((x+.5)/size-.5,((y+.5)/size-.5)*1.25)
        t=max(0,min(1,(radius-.06)/.44));alpha=round((1-t*t*(3-2*t))**2*255)
        pixels.extend((alpha,alpha,alpha,255))
data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels,9))+chunk(b'IEND',b'')
(folder/'contact_shadow_128.png').write_bytes(data)

for index,name in enumerate(['bold','pack','cautious','flanker']):
    rate=22050;duration=.26+index*.025;rng=random.Random(20261007+index)
    values=[];low=0.;phase=0.
    for sample in range(round(duration*rate)):
        t=sample/rate;p=t/duration;freq=(125+index*25)*(1-.35*p)
        phase+=math.tau*freq/rate;low=low*.88+(rng.random()*2-1)*.12
        envelope=math.sin(math.pi*p)**1.8
        value=(math.sin(phase)*.24+math.sin(phase*1.51)*.1+low*.7)*envelope*.38
        values.append(round(max(-1,min(1,value))*32767))
    with wave.open(str(ROOT/'audio/v82'/('monster_'+name+'.wav')),'wb') as stream:
        stream.setparams((1,2,rate,0,'NONE','not compressed'));stream.writeframes(struct.pack('<'+'h'*len(values),*values))
    path=ROOT/'audio/v82'/('monster_'+name+'.wav')
    manifest_path=ROOT/'audio/v82/manifest.json';manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest['tracks']['monster_'+name]={'file':path.relative_to(ROOT).as_posix(),'loop':False,'seconds':len(values)/rate,'sample_rate':rate,'channels':1,'peak':max(abs(value) for value in values)/32767,'rms':math.sqrt(sum(value*value for value in values)/len(values))/32767,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'generator':'tools/build_mobile25d_support.py'}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

for path in (ROOT/'assets/mobile25d').rglob('*.png.import'):
    text=path.read_text(encoding='utf-8')
    for key,value in [('compress/mode','2'),('compress/high_quality','true'),('mipmaps/generate','true'),('detect_3d/compress_to','0'),('process/size_limit','1024')]:
        text=re.sub(r'^'+re.escape(key)+r'=.*$',key+'='+value,text,flags=re.M)
    if 'normal' in path.name:text=re.sub(r'^compress/normal_map=.*$','compress/normal_map=1',text,flags=re.M)
    path.write_text(text,encoding='utf-8')
for path in (ROOT/'assets/mobile25d').rglob('*.glb.import'):
    text=path.read_text(encoding='utf-8').replace('meshes/generate_lods=true','meshes/generate_lods=false').replace('meshes/create_shadow_meshes=true','meshes/create_shadow_meshes=false')
    path.write_text(text,encoding='utf-8')
print('MOBILE25D_SUPPORT_OK')
