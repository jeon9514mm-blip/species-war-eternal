using System;
using UnityEditor;

namespace Eternal.UnityMigration.Editor
{
    public sealed class AureliaVolumeImporter : AssetPostprocessor
    {
        const string Prefix="Assets/Game/Resources/Eternal/GraphicsRebuild/Heroes/";
        void OnPreprocessModel()
        {
            if(!assetPath.StartsWith(Prefix,StringComparison.Ordinal)||!assetPath.EndsWith(".fbx",StringComparison.OrdinalIgnoreCase))return;
            var importer=(ModelImporter)assetImporter;importer.globalScale=1;
            importer.importAnimation=true;importer.animationType=ModelImporterAnimationType.Generic;
            importer.avatarSetup=ModelImporterAvatarSetup.CreateFromThisModel;
            importer.addCollider=false;importer.importBlendShapes=false;
            importer.importNormals=ModelImporterNormals.Import;
            importer.animationCompression=ModelImporterAnimationCompression.Off;
            var clips=importer.defaultClipAnimations;
            foreach(var clip in clips)
            {
                bool loop=clip.name.Contains("Idle",StringComparison.OrdinalIgnoreCase)||clip.name.Contains("Walk",StringComparison.OrdinalIgnoreCase);
                clip.loopTime=loop;clip.loopPose=loop;
            }
            if(clips.Length>0)importer.clipAnimations=clips;
        }
    }
}
