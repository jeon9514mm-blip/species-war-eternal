#!/usr/bin/env python3
"""Read-only alpha measurement of original-painted 16-pose atlases."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from matplotlib import pyplot as plt
from fit_aurelia_anatomy import simplify

def measure(path,identity):
    image=Image.open(path)
    if image.mode!='RGBA':raise ValueError('RGBA transparency required')
    alpha=np.asarray(image)[:,:,3]
    labels,_=ndimage.label(alpha>40)
    columns,rows=(2,8) if image.height/image.width>1.5 else (4,4)
    poses={}
    for number,box in enumerate(ndimage.find_objects(labels),1):
        if box is None:continue
        mask=labels[box]==number;area=int(mask.sum())
        if area<2000:continue
        y,x=box
        cy=(y.start+y.stop)*.5;cx=(x.start+x.stop)*.5
        row=min(rows-1,int(cy/image.height*rows));column=min(columns-1,int(cx/image.width*columns))
        index=row*columns+column
        if index in poses and poses[index]['opaque_pixels']>=area:continue
        contour=plt.contour(np.pad(mask.astype(float),1),levels=[.5])
        outline=max(contour.allsegs[0],key=lambda points:abs(np.sum(points[:,0]*np.roll(points[:,1],-1)-points[:,1]*np.roll(points[:,0],-1))))-1
        plt.close()
        if np.linalg.norm(outline[0]-outline[-1])<1e-6:outline=outline[:-1]
        split=int(np.argmax(np.sum((outline-outline[0])**2,axis=1)))
        polygon=np.concatenate([simplify(outline[:split+1],.7)[:-1],simplify(np.concatenate([outline[split:],outline[:1]]),.7)[:-1]])
        height,width=mask.shape
        # Foot midpoint: the lower 8% of the connected standing painting.
        _,feet_x=np.where(mask[max(0,height-max(8,int(height*.08))):])
        anchor=[float((feet_x.min()+feet_x.max())*.5),float(height-1)]
        poses[index]={'region':[x.start,y.start,width,height],'anchor':anchor,'silhouette_uv':np.clip(polygon/[width,height],0,1).round(7).tolist(),'opaque_pixels':area}
    if len(poses)!=16:raise ValueError(f'{identity}: expected all 16 connected poses, got {sorted(poses)}')
    frames=[poses[index] for index in range(16)]
    native_height=frames[8]['region'][3]
    common={'atlas':'res://'+path.as_posix(),'atlas_size':list(image.size),'native_height':native_height,'measurement':'Read-only alpha contours; source pixels unchanged.','image_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    return {'schema':2,'id':identity,'renderer':'whole_original_painted_frames_without_joints','stride_distance':1.4,'layout':[columns,rows],'attack':dict(common,frames=frames[:8]),'motion':dict(common,frames=frames[8:]),'authored_full_body':True}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('image',type=Path);parser.add_argument('--id',required=True);args=parser.parse_args()
    output=args.image.with_name('frames.json');data=measure(args.image,args.id)
    output.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('ORIGINAL_POSES_MEASURED',args.id,output)
if __name__=='__main__':main()
