"""Save a stable Unity development scene and source GUIDs without launching QA.

FBX import details are handled by AureliaVolumeImporter when Unity opens it.
Never edits the APK build entry or existing production scene.
"""
from pathlib import Path
import uuid

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'Unity/Assets'
namespace=uuid.UUID('f8d16d50-83c2-4d2a-a907-1315ca48f84c')
def guid(path):return uuid.uuid5(namespace,path.as_posix()).hex
def metadata(path):
    meta=Path(str(path)+'.meta')
    if meta.exists():return
    text='fileFormatVersion: 2\nguid: '+guid(path.relative_to(ASSETS))+'\n'
    if path.is_dir():text+='folderAsset: yes\nDefaultImporter:\n  externalObjects: {}\n  userData: \n  assetBundleName: \n  assetBundleVariant: \n'
    meta.write_text(text,encoding='utf-8')

for file in [ASSETS/'Game/Runtime/RoyalGroveEnvironment.cs',ASSETS/'Game/Runtime/AureliaVolumeActor.cs',ASSETS/'Game/Runtime/RoyalGroveDevelopmentStage.cs',ASSETS/'Game/Editor/GraphicsRebuildInstaller.cs',ASSETS/'Game/Editor/AureliaVolumeImporter.cs']:
    metadata(file)
folder=ASSETS/'Game/Resources/Eternal/GraphicsRebuild'
for file in [folder,*folder.rglob('*')]:
    if file.suffix!='.meta':metadata(file)
scene=ASSETS/'Scenes/RoyalGroveDevelopment.unity'
source=(ASSETS/'Scenes/HuntingReview.unity').read_text(encoding='utf-8')
source=source.replace('Native hunting integration review','Royal grove graphics development')
stage=ASSETS/'Game/Runtime/RoyalGroveDevelopmentStage.cs'
stage_guid=Path(str(stage)+'.meta').read_text(encoding='utf-8').split('guid: ')[1].splitlines()[0]
source=source.replace('8cdf09939594abd4aaf3e2019ff549ce',stage_guid).replace('Assembly-CSharp::Eternal.UnityMigration.HuntingMigrationReview','Assembly-CSharp::Eternal.UnityMigration.RoyalGroveDevelopmentStage')
scene.write_text(source,encoding='utf-8');metadata(scene)
print('SAVED_DEVELOPMENT_SCENE',scene.relative_to(ROOT).as_posix())
