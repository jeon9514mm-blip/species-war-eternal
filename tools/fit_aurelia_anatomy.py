#!/usr/bin/env python3
"""Fit artist-authored anatomical landmarks without modifying any image pixels.

Unlike the retired percentage fitter, every limb requires inspected source UVs.
Hero proportions and equipment lengths come from that hero's concept landmarks.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from matplotlib import pyplot as plt
from fit_aurelia_parts import ART, BONES, ORDER, FAMILIES, LEFT

ROOT = Path(__file__).resolve().parents[1]
SPEC_ROOT = ROOT / 'tools/hero-anatomy'
DISTAL = {'upper_arm':'Forearm','forearm':'Hand','thigh':'Shin','shin':'Foot'}


def simplify(points, tolerance=.7):
    if len(points)<3:return points
    line=points[-1]-points[0]
    distance=np.abs((points[:,0]-points[0,0])*line[1]-(points[:,1]-points[0,1])*line[0])/max(np.linalg.norm(line),1e-10)
    index=int(np.argmax(distance))
    if distance[index]<=tolerance:return points[[0,-1]]
    return np.concatenate([simplify(points[:index+1],tolerance)[:-1],simplify(points[index:],tolerance)])


def components(path):
    image = Image.open(path)
    if image.mode != 'RGBA': raise ValueError('True transparent RGBA required')
    alpha = np.asarray(image)[:,:,3]
    labels, _ = ndimage.label(alpha > 50)
    objects=[]
    for label, box in enumerate(ndimage.find_objects(labels),1):
        if box is None: continue
        area=int(np.count_nonzero(labels[box]==label))
        if area<300: continue
        y,x=box
        mask = labels[box] == label
        contour = plt.contour(np.pad(mask.astype(float),1),levels=[.5])
        paths=contour.allsegs[0]
        outline=max(paths,key=lambda a: abs(np.sum(a[:,0]*np.roll(a[:,1],-1)-a[:,1]*np.roll(a[:,0],-1))))-1
        plt.close()
        # Matplotlib is used solely to analyze the source alpha boundary;
        # no figure or edited image is ever saved.
        if np.linalg.norm(outline[0]-outline[-1])<1e-6: outline=outline[:-1]
        split=int(np.argmax(np.sum((outline-outline[0])**2,axis=1)))
        poly=np.concatenate([simplify(outline[:split+1])[:-1],simplify(np.concatenate([outline[split:],outline[:1]]))[:-1]])
        height,width=mask.shape
        poly=np.clip(poly/[width,height],0,1).tolist()
        objects.append({'region':[x.start,y.start,x.stop-x.start,y.stop-y.start], 'pixels':area,'silhouette_uv':poly})
    if len(objects)!=18: raise ValueError(f'{path}: expected 18 painted components; got {len(objects)}')
    # Cell identity is determined by row/column, not by painting length.
    objects.sort(key=lambda p:p['region'][1]+p['region'][3]/2)
    ordered=[]
    for row in range(3): ordered += sorted(objects[row*6:(row+1)*6],key=lambda p:p['region'][0]+p['region'][2]/2)
    return image,dict(zip(ORDER,ordered))


def rotation(angle, point):
    x,y=point
    return [x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle)]


def fit(hero):
    folder=ART/hero
    spec=json.loads((SPEC_ROOT/(hero+'.json')).read_text())
    image,objects=components(folder/'parts.png')
    if hashlib.sha256((folder/'parts.png').read_bytes()).hexdigest()!=spec['atlas_sha256']:
        raise ValueError(f'{hero}: source changed; re-inspect artist landmarks before fitting')
    if hero=='leonhardt':
        # This source deliberately interchanges the two foot cells to retain
        # their artist-authored toe direction. Do not infer anatomical side.
        objects['left_foot'],objects['right_foot']=objects['right_foot'],objects['left_foot']
    rest=spec['joint_rest']; family=FAMILIES.get(hero,'blade')
    hand='left' if hero in LEFT else 'right'
    landmarks=spec['part_landmarks']
    required=[n for n in ORDER if any(n.endswith('_'+k) for k in DISTAL)]
    missing=[n for n in required if n not in landmarks]
    if missing: raise ValueError(f'{hero}: artist landmarks missing: {missing}')
    parts=[]; diagnostics=[]
    for name,bone in zip(ORDER,BONES):
        obj=objects[name]; x,y,w,h=obj['region']
        authored=landmarks.get(name,{})
        anchor=authored.get('anchor',[.5,.1]); angle=authored.get('rotation',0.0); offset=[0,0]
        height=authored.get('height',.08)
        side='Left' if name.startswith('left_') else 'Right'
        segment=next((k for k in DISTAL if name.endswith('_'+k)),None)
        if name=='head': offset=[0,spec['neck_attachment']['underlap_body_units']]
        if segment:
            anchor=authored['proximal']; distal=authored['distal']
            drawn=np.array([(distal[0]-anchor[0])*w/h,distal[1]-anchor[1]])
            target=np.array(rest[side+DISTAL[segment]])-np.array(rest[bone])
            height=float(np.linalg.norm(target)/np.linalg.norm(drawn))
            angle=float(math.atan2(target[1],target[0])-math.atan2(drawn[1],drawn[0]))
        elif name=='head': height=spec['head_height']
        elif name=='chest':
            height=spec['core_height']
            neck=authored['neck']
            # Match the actual neck paint to the neck hinge, independently of
            # the chest hinge's lower position used for clavicle rotation.
            anchor=[neck[0],neck[1]+(rest['Chest'][1]-rest['Head'][1])/height]
            offset=[rest['Head'][0]-rest['Chest'][0],0]
        elif name=='hair_back': height=authored['height']
        elif name=='cape_back': height=authored.get('height',.62)
        elif name in ['weapon','offhand']:
            if name=='offhand' and family in ['cannon','blade','rapier'] and hero!='leonhardt':continue
            length=spec['weapon_long_axis'] if name=='weapon' else spec['offhand_long_axis']
            height=length/(max(w,h)/h)
        elif name.endswith('_hand'):
            height=authored.get('height',.075)
            # Artist cuff-to-finger direction, not an assumed vertical palm.
            axis=authored['finger_axis']
            target=np.array(rest[side+'Hand'])-np.array(rest[side+'Forearm'])
            angle=math.atan2(target[1],target[0])-math.atan2(axis[1]*h,axis[0]*w)
        elif name.endswith('_foot'): height=authored.get('height',.125)
        size=[height*w/h,height]
        z={'head':14,'hair_back':-30,'chest':16,'cape_back':-40,'weapon':28,'offhand':30}.get(name,0)
        if segment or name.endswith(('_hand','_foot')):
            # Single knee guard lives on the thigh, covering the plain shin
            # underlap. Likewise upper arm covers elbow, forearm covers wrist.
            z=(8 if side=='Left' else 3)+{'upper_arm':15,'forearm':14,'thigh':2,'shin':1}.get(segment,17 if name.endswith('_hand') else 0)
        if name.endswith('_hand'): z=35 if side=='Left' else 34
        part={'silhouette_uv':obj['silhouette_uv'],'id':name,'bone':bone,'region':obj['region'],'anchor':anchor,'display_size':size,'rotation':angle,'offset':offset,'z_order':z,'alpha_visible_pixels':obj['pixels']}
        if name=='head':
            part['neck_seam']=spec['neck_attachment']['head_seam_uv']
        if name=='chest' and 'core_mask_uv' in spec['neck_attachment']:
            part['core_neck_mask']=spec['neck_attachment']['core_mask_uv']
            part['core_neck_skin_only']=bool(spec['neck_attachment'].get('core_skin_only',False))
        if segment:
            part['distal_anchor']=authored['distal'];part['distal_joint']=side+DISTAL[segment]
            local=np.array(rotation(angle,[(authored['distal'][0]-anchor[0])*size[0],(authored['distal'][1]-anchor[1])*size[1]]))
            error=float(np.linalg.norm(local-(np.array(rest[part['distal_joint']])-np.array(rest[bone]))))
            diagnostics.append({'part_id':name,'source_proximal_uv':anchor,'source_distal_uv':authored['distal'],'rest_endpoint_error':error})
            if error>1e-8: raise ValueError(f'{hero}: fitting endpoint error')
        parts.append(part)
    by_id={p['id']:p for p in parts}
    for prop,glove in [('weapon',hand+'_hand'),('offhand',('right' if hand=='left' else 'left')+'_hand')]:
        if prop not in by_id:continue
        g=by_id[glove];grip=landmarks[glove]['grip']
        mount=rotation(g['rotation'],[(grip[0]-g['anchor'][0])*g['display_size'][0],(grip[1]-g['anchor'][1])*g['display_size'][1]])
        by_id[prop]['offset']=rotation(-by_id[prop]['rotation'],mount)
        by_id[prop]['grip_hand_part']=glove;by_id[prop]['hand_grip_anchor']=grip
        by_id[prop]['concept_long_axis_ratio']=spec['weapon_long_axis'] if prop=='weapon' else spec['offhand_long_axis']
    definition={'schema_version':1,'hero_id':hero,'atlas':f'res://assets/art-direction/aurelia-4head/{hero}/parts.png','atlas_size':list(image.size),'reviewed':False,'component_integrity_verified':True,'art_status':'anatomical_refit_v3_pending_actual_visual_review','weapon_hand':hand,'long_leg_neutral_fitted':True,'attack_foreground':True,'joint_rest':rest,'parts':parts,'neck_attachment':spec['neck_attachment'],'anatomy_spec':f'res://tools/hero-anatomy/{hero}.json','anatomy_revision':'individual_concept_and_painted_joint_landmarks_v3','artist_notes':['All limb pivots explicitly authored against this painting; no shared 12/88 percent landmarks.','Equipment aspect is preserved and long axis fitted to individual master-body reference.','PNG pixels unchanged by fitter. Anatomy artwork regeneration provenance is stored separately.','Endpoint tests verify attachment geometry; visual quality must still be reviewed from actual rendering.']}
    (folder/'parts.json').write_text(json.dumps(definition,ensure_ascii=False,indent=2)+'\n')
    report={'hero_id':hero,'reviewed':False,'atlas_sha256':hashlib.sha256((folder/'parts.png').read_bytes()).hexdigest(),'spec_sha256':hashlib.sha256((SPEC_ROOT/(hero+'.json')).read_bytes()).hexdigest(),'painted_components':18,'active_parts':len(parts),'painted_silhouettes_disjoint':True,'joint_landmarks':diagnostics,'maximum_rest_endpoint_error':max(d['rest_endpoint_error'] for d in diagnostics),'scope':'Binding geometry only, not an artistic approval.'}
    (folder/'parts-analysis.json').write_text(json.dumps(report,indent=2)+'\n')
    print(hero,len(parts),'parts, max endpoint error',report['maximum_rest_endpoint_error'],flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('heroes',nargs='+',choices=['leonhardt']+list(FAMILIES))
    for hero in parser.parse_args().heroes:fit(hero)
