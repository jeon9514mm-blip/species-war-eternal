#!/usr/bin/env python3
"""Read actual Godot Control geometry, excluding expected scroll overflow."""
import json,sys,pathlib
path=pathlib.Path(sys.argv[1]);data=json.loads(path.read_text())
report={'source':str(path),'rendered':any(s['path'] for s in data),'screens':[]}
def intersects(a,b):
 return min(a[0]+a[2],b[0]+b[2])>max(a[0],b[0]) and min(a[1]+a[3],b[1]+b[3])>max(a[1],b[1])
for screen in data:
 result={'view':screen['view'],'controls':len(screen['controls']),'outside_viewport':[],'touch_targets_under_40':[],'text_overflow':[],'buttons':[]}
 for n in screen['controls']:
  r=n['rect'];clip=n.get('clip_rect',[0,0,1280,720]);clipped=n.get('clipped_by',[])
  if not intersects(r,clip):continue
  short={'text':n['text'],'rect':r,'path':n.get('path','')}
  if not clipped and (r[0]<-1 or r[1]<-1 or r[0]+r[2]>1281 or r[1]+r[3]>721):result['outside_viewport'].append(short)
  if n['type']=='Button':
   result['buttons'].append(short)
   if r[2]<40 or r[3]<40:result['touch_targets_under_40'].append(short)
  if n.get('autowrap',0)==0 and n.get('text_width',0)>r[2]+1:result['text_overflow'].append(short|{'text_width':n.get('text_width')})
 report['screens'].append(result)
out=path.with_name('layout_analysis.json');out.write_text(json.dumps(report,ensure_ascii=False,indent=2))
for s in report['screens']:
 print(f"{s['view']}: outside={len(s['outside_viewport'])}, text={len(s['text_overflow'])}, small_touch={len(s['touch_targets_under_40'])}")
print(out)
