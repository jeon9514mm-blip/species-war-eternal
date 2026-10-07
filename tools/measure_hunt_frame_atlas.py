#!/usr/bin/env python3
"""Measure whole painted poses without editing any source image pixels.

The outer alpha contour isolates adjacent full poses whose bounding rectangles
overlap. These are texture clipping meshes, never bones or articulated parts.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from matplotlib import pyplot as plt
from fit_aurelia_anatomy import simplify

def measure(path):
    image=Image.open(path)
    if image.mode!='RGBA':raise ValueError('Real RGBA transparency required')
    labels,_=ndimage.label(np.asarray(image)[:,:,3]>40)
    objects=[]
    for label,box in enumerate(ndimage.find_objects(labels),1):
        if box is None:continue
        mask=labels[box]==label
        area=int(mask.sum())
        if area<5000:continue
        y,x=box
        contour=plt.contour(np.pad(mask.astype(float),1),levels=[.5])
        outline=max(contour.allsegs[0],key=lambda a:abs(np.sum(a[:,0]*np.roll(a[:,1],-1)-a[:,1]*np.roll(a[:,0],-1))))-1
        plt.close()
        if np.linalg.norm(outline[0]-outline[-1])<1e-6:outline=outline[:-1]
        split=int(np.argmax(np.sum((outline-outline[0])**2,axis=1)))
        polygon=np.concatenate([simplify(outline[:split+1],.55)[:-1],simplify(np.concatenate([outline[split:],outline[:1]]),.55)[:-1]])
        height,width=mask.shape
        bottom_band=mask[max(0,height-32):]
        _,feet_x=np.where(bottom_band)
        anchor=[float((feet_x.min()+feet_x.max())*.5),float(height-1)]
        objects.append({'region':[x.start,y.start,width,height],'anchor':anchor,'silhouette_uv':np.clip(polygon/[width,height],0,1).round(7).tolist(),'opaque_pixels':area})
    if len(objects)!=8:raise ValueError(f'{path}: expected 8 complete painted bodies, found {len(objects)}')
    objects.sort(key=lambda p:p['region'][1]+p['region'][3]/2)
    ordered=[]
    for row in range(2):ordered+=sorted(objects[row*4:(row+1)*4],key=lambda p:p['region'][0]+p['region'][2]/2)
    return {'atlas_size':list(image.size),'frames':ordered,'native_height':ordered[0]['region'][3]-1,'image_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'measurement':'Read-only alpha analysis of complete paintings; pixel data unchanged.'}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image',type=Path);parser.add_argument('output',type=Path)
    args=parser.parse_args();args.output.write_text(json.dumps(measure(args.image),ensure_ascii=False,indent=2)+'\n')
    print('WHOLE_FRAME_MEASURED '+str(args.output))
if __name__=='__main__':main()
