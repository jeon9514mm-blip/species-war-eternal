#!/usr/bin/env python3
"""Read-only PNG analysis; writes joint/region JSON, never changes image pixels."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art-direction/aurelia-4head'
ORDER = ['head', 'hair_back', 'chest', 'cape_back', 'weapon', 'offhand',
         'left_upper_arm', 'left_forearm', 'left_hand',
         'right_upper_arm', 'right_forearm', 'right_hand',
         'left_thigh', 'left_shin', 'left_foot',
         'right_thigh', 'right_shin', 'right_foot']
BONES = ['Head', 'Hair', 'Chest', 'Cape', 'Weapon', 'Offhand',
         'LeftUpperArm', 'LeftForearm', 'LeftHand', 'RightUpperArm',
         'RightForearm', 'RightHand', 'LeftThigh', 'LeftShin', 'LeftFoot',
         'RightThigh', 'RightShin', 'RightFoot']
FAMILIES = {'mira':'bow', 'elisia':'heal', 'kairen':'staff', 'orwin':'spear',
            'seria':'dual', 'astel':'heal', 'darius':'blade', 'lunea':'staff',
            'caelum':'blade', 'adrien':'rapier', 'tessa':'cannon', 'naia':'bow',
            'sael':'dual', 'odelia':'book'}
LEFT = {'mira', 'elisia', 'kairen', 'astel', 'naia', 'odelia'}
HEADS = {'mira':(.58,.80,.27), 'elisia':(.54,.72,.285), 'kairen':(.53,.74,.29),
         'orwin':(.50,.94,.215), 'seria':(.56,.74,.28), 'astel':(.51,.74,.29),
         'darius':(.52,.94,.215), 'lunea':(.50,.76,.28), 'caelum':(.50,.94,.215),
         'adrien':(.52,.94,.215), 'tessa':(.50,.77,.275), 'naia':(.50,.76,.28),
         'sael':(.53,.82,.255), 'odelia':(.52,.80,.27)}
Z = [9, -30, 10, -40, 30, 33, 22, 23, 25, 20, 21, 24, 5, 6, 7, 1, 2, 3]


def fit(hero):
    current = ART / hero / 'parts.json'
    if current.exists() and json.loads(current.read_text()).get('anatomy_revision'):
        raise RuntimeError('Retired generic fitting cannot overwrite inspected anatomy; use fit_aurelia_anatomy.py')
    path = ART / hero / 'parts.png'
    image = Image.open(path)
    assert image.mode == 'RGBA', f'{hero}: true alpha required'
    alpha = np.asarray(image)[:, :, 3]
    labels, _ = ndimage.label(alpha > 50)
    objects = []
    for number, box in enumerate(ndimage.find_objects(labels), 1):
        if box is None:
            continue
        pixels = int(np.count_nonzero(labels[box] == number))
        if pixels < 300:
            continue
        y, x = box
        objects.append(dict(label=number, pixels=pixels,
                            region=[x.start, y.start, x.stop-x.start, y.stop-y.start]))
    assert len(objects) == 18, f'{hero}: expected18 independently painted components, got{len(objects)}'
    objects.sort(key=lambda p: p['region'][1]+p['region'][3]/2)
    ordered = []
    for row in range(3):
        ordered.extend(sorted(objects[row*6:row*6+6], key=lambda p: p['region'][0]+p['region'][2]/2))
    overlaps = []
    for i, p in enumerate(ordered):
        x, y, w, h = p['region']
        for j, other in enumerate(ordered[:i]):
            ox, oy, ow, oh = other['region']
            if x < ox+ow and ox < x+w and y < oy+oh and oy < y+h:
                overlaps.append([ORDER[j], ORDER[i]])
    assert not overlaps, f'{hero}: rectangular regions overlap: {overlaps}; request image spacing repair'
    rest = {'Root':[0,0], 'Pelvis':[0,-.52], 'Torso':[0,-.63],
            'Chest':[0,-.735], 'Head':[.005,-.777], 'Hair':[0,-.91], 'Cape':[0,-.755]}
    for side, sign in [('Left',1),('Right',-1)]:
        rest.update({side+'UpperArm':[sign*.108,-.735], side+'Forearm':[sign*.155,-.575],
                     side+'Hand':[sign*.175,-.415], side+'Thigh':[sign*.058,-.505],
                     side+'Shin':[sign*.095,-.285], side+'Foot':[sign*.12,-.075]})
    family = FAMILIES[hero]
    hand = 'left' if hero in LEFT else 'right'
    if family == 'bow':
        rest['LeftForearm'] = [.165,-.61]
        rest['LeftHand'] = [.24,-.50]
        rest['RightHand'] = [-.04,-.50]
    elif family in ['staff','heal']:
        side = 'Left' if hand == 'left' else 'Right'
        sign = 1 if hand == 'left' else -1
        rest[side+'Forearm'] = [sign*.17,-.60]
        rest[side+'Hand'] = [sign*.28,-.50]
    elif family == 'cannon':
        rest['RightForearm'] = [-.14,-.565]
        rest['RightHand'] = [.015,-.535]
        rest['LeftForearm'] = [.17,-.60]
        rest['LeftHand'] = [.22,-.52]
    elif family == 'book':
        rest['LeftHand'] = [.22,-.54]
    parts = []
    for index, (name, bone, source) in enumerate(zip(ORDER, BONES, ordered)):
        x, y, w, h = source['region']
        mask = labels[y:y+h, x:x+w] == source['label']
        anchor = [.5,.12]
        height = .17
        rotation = 0.0
        offset = [0,0]
        if name == 'head':
            hx, hy, height = HEADS[hero]
            anchor = [hx,hy]
        elif name == 'hair_back':
            anchor, height = [.5,.15], .48 if hero not in ['orwin','darius','caelum','adrien'] else .19
        elif name == 'chest':
            anchor, height = [.5,.10], .37
        elif name == 'cape_back':
            anchor, height = [.5,.05], .61 if family in ['staff','heal','book'] else .57
        elif name == 'weapon':
            offset = [.012 if hand == 'left' else -.012,.033]
            if family == 'bow': anchor, height = [.5,.50], .72
            elif family in ['staff','heal']: anchor, height = [.5,.62], .82
            elif family == 'spear': anchor, height = [.5,.60], .95
            elif family == 'cannon': anchor, height = [.15,.64], .27
            elif family == 'book': anchor, height = [.5,.82], .22
            else: anchor, height = [.5,.14], .30 if family == 'dual' else .50
            if family not in ['book','cannon']:
                row = max(0,min(h-1,round(anchor[1]*(h-1))))
                xs = np.nonzero(mask[max(0,row-2):min(h,row+3)])[1]
                if xs.size: anchor[0] = float(np.median(xs)/w)
        elif name == 'offhand':
            if family == 'bow': anchor, height, rotation, offset = [.5,.88], .43, math.pi/2, [.027,0]
            elif family == 'spear': anchor, height, offset = [.5,.55], .40, [0,.03]
            elif family == 'dual': anchor, height, offset = [.5,.14], .30, [0,.033]
            elif family == 'book': anchor, height = [.5,.12], .24
            else: anchor, height, offset = [.5,.5], .08, [.08,-.06]
        elif name.endswith('_foot'):
            anchor, height = [.50,.375], .12
        elif name.endswith('_hand'):
            anchor, height = [.5,.12], .08
            side = 'Left' if name.startswith('left') else 'Right'
            forearm_axis = np.array(rest[side+'Hand']) - np.array(rest[side+'Forearm'])
            rotation = math.atan2(forearm_axis[1], forearm_axis[0]) - math.pi/2
            # These paintings present a horizontal cuff/palm, rather than a
            # downward glove. Their artist wrist points must remain explicit.
            if hero == 'elisia':
                if side == 'Left':
                    anchor, height = [.20,.42], .08
                    rotation = math.atan2(forearm_axis[1], forearm_axis[0])
                else:
                    anchor, height = [.78,.26], .09
                    rotation = math.atan2(forearm_axis[1], forearm_axis[0]) - 2.42
            elif hero == 'odelia':
                if side == 'Left':
                    anchor, height, rotation = [.74,.50], .09, 0.0
                else:
                    anchor, height, rotation = [.56,.62], .09, 0.0
        else:
            side = 'Left' if name.startswith('left') else 'Right'
            distal = side + ('Forearm' if name.endswith('upper_arm') else 'Hand' if name.endswith('forearm') else 'Shin' if name.endswith('thigh') else 'Foot')
            proximal_y, distal_y = .12, .88
            def center_at(fraction):
                row = max(0,min(h-1,round(fraction*(h-1))))
                band = mask[max(0,row-3):min(h,row+4)]
                xs = np.nonzero(band)[1]
                return float(xs.mean()/w) if xs.size else .5
            px, dx = center_at(proximal_y), center_at(distal_y)
            anchor = [px,proximal_y]
            drawn = np.array([(dx-px)*w/h, distal_y-proximal_y])
            target = np.array(rest[distal])-np.array(rest[bone])
            height = float(np.linalg.norm(target)/np.linalg.norm(drawn))
            rotation = math.atan2(target[1],target[0])-math.atan2(drawn[1],drawn[0])
        # Secondary carry props are preserved in the source atlas but not shown
        # as a spare weapon strapped to the palm during a two-handed pose.
        if name == 'offhand' and family in ['cannon','blade','rapier']:
            continue
        parts.append({'id':name,'bone':bone,'region':source['region'],
                      'anchor':anchor,'display_size':[height*w/h,height],
                      'offset':offset,'z_order':Z[index],'rotation':rotation,
                      'alpha_visible_pixels':source['pixels']})
    by_id = {part['id']:part for part in parts}
    for equipment, glove in [('weapon',hand+'_hand'),
                             ('offhand',('right' if hand=='left' else 'left')+'_hand')]:
        if equipment not in by_id: continue
        # Small dangling charms float near the free palm; held objects must
        # mount at the painted finger grip rather than the wrist hinge.
        if equipment=='offhand' and family not in ['bow','spear','dual','book']: continue
        g = by_id[glove]
        grip = [.5,.53]
        if hero=='elisia' and glove=='left_hand': grip=[.70,.43]
        if hero=='odelia' and glove=='left_hand': grip=[.36,.48]
        dx=(grip[0]-g['anchor'][0])*g['display_size'][0]
        dy=(grip[1]-g['anchor'][1])*g['display_size'][1]
        angle=g['rotation']-by_id[equipment]['rotation']
        by_id[equipment]['offset']=[dx*math.cos(angle)-dy*math.sin(angle),
                                    dx*math.sin(angle)+dy*math.cos(angle)]
    definition = {'schema_version':1,'hero_id':hero,
                  'atlas':f'res://assets/art-direction/aurelia-4head/{hero}/parts.png',
                  'atlas_size':list(image.size),'reviewed':False,
                  'component_integrity_verified':True,
                  'art_status':'long_leg_parts_initial_fit_pending_visual_review',
                  'weapon_hand':hand,'long_leg_neutral_fitted':True,
                  'attack_foreground':True,'joint_rest':rest,'parts':parts,
                  'artist_notes':['Generated independent parts from the existing master; all active rectangles are disjoint.',
                                  'PNG pixels untouched; read-only alpha analysis supplies region and limb endpoints.',
                                  'Region/pivot fitting and16 source-time motion prototypes require actual enlarged rendering and final user review.']}
    (path.parent/'parts.json').write_text(json.dumps(definition,ensure_ascii=False,indent=2)+'\n')
    report = {'hero_id':hero,'painted_components':18,'active_parts':len(parts),
              'rectangles_disjoint':True,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
              'transparent_pixels':int(np.count_nonzero(alpha<20)), 'reviewed':False}
    (path.parent/'parts-analysis.json').write_text(json.dumps(report,indent=2)+'\n')
    print(hero, 'fitted',len(parts),'parts',flush=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('heroes',nargs='+',choices=FAMILIES)
    for hero in parser.parse_args().heroes:
        fit(hero)
