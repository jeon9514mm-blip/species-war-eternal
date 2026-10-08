"""Reproduce the bundled Korean UI font from a pinned OFL source.

Install fonttools==4.66.1 in an isolated tooling environment, then pass the
downloaded Google Fonts variable source, its unchanged OFL.txt and commit SHA.
No source font or player save is modified.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from fontTools import subset, __version__
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,required=True)
parser.add_argument('--license',type=Path,required=True)
args=parser.parse_args()
repo=Path(__file__).resolve().parents[2]
output=repo/'Unity/Assets/Game/Resources/Eternal/Fonts'
output.mkdir(parents=True,exist_ok=True)
original=args.source.read_bytes()
source_hash=hashlib.sha256(original).hexdigest()
expected='194018e6b2b293a7964f037b25c0249ce1418bc9ab3c971060a03aa57861e252'
if source_hash!=expected:raise RuntimeError('Pinned source font hash changed.')
if __version__!='4.66.1':raise RuntimeError('Use the documented fonttools==4.66.1 tool version.')
font=TTFont(args.source,recalcTimestamp=False)
font=instantiateVariableFont(font,{'wght':400},inplace=True)
ranges=[(0x20,0xff),(0x1100,0x11ff),(0x2000,0x206f),(0x2190,0x21ff),(0x25a0,0x25ff),(0x3000,0x303f),(0x3130,0x318f),(0xa960,0xa97f),(0xac00,0xd7a3),(0xd7b0,0xd7ff),(0xff00,0xffef)]
codepoints={c for a,b in ranges for c in range(a,b+1)}
options=subset.Options();options.name_IDs=['*'];options.name_languages=['*'];options.recalc_timestamp=False
subsetter=subset.Subsetter(options=options);subsetter.populate(unicodes=codepoints);subsetter.subset(font)
# A derivative name keeps this subset distinct from the original upstream font.
for entry in font['name'].names:
    replacement={1:'Eternal KR',2:'Regular',3:'EternalKR-Regular-1',4:'Eternal KR Regular',6:'EternalKR-Regular',16:'Eternal KR',17:'Regular'}.get(entry.nameID)
    if replacement is not None:entry.string=replacement.encode(entry.getEncoding(),errors='replace')
destination=output/'EternalKR-Regular.ttf';font.save(destination)
cmap=font.getBestCmap();missing=[c for c in range(0xac00,0xd7a4) if c not in cmap]
if missing:raise RuntimeError('Full Korean syllable coverage was lost.')
shutil.copyfile(args.license,output/'EternalKR-OFL.txt')
record={'source_repository':'https://github.com/google/fonts/tree/b38c5c93af322c45f633e17ac440ec1e6c94d489/ofl/notosanskr','source_sha256':source_hash,'source_bytes':len(original),'tool':'fonttools=='+__version__,'weight':400,'derivative_family':'Eternal KR','license':'SIL Open Font License 1.1; unchanged upstream license included','unicode_ranges':[[hex(a),hex(b)] for a,b in ranges],'mapped_codepoints':len(cmap),'hangul_syllables':11172,'output_bytes':destination.stat().st_size,'output_sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'note':'Bundled static-weight TrueType source used by Unity dynamic text rendering. This is a character subset, not a pre-baked SDF atlas or target-device font/performance verification.'}
(output/'EternalKR-SOURCE.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:record[k] for k in ['mapped_codepoints','hangul_syllables','output_bytes','output_sha256']}))
