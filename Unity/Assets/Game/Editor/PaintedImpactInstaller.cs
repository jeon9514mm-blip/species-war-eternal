using System;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class PaintedImpactInstaller
    {
        public static string Apply()
        {
            if(Application.isPlaying)throw new InvalidOperationException("Stop Play before importing painted impacts.");AssetDatabase.Refresh();
            const string texturePath="Assets/Game/Resources/Eternal/Vfx/painted-impacts-v1.png";
            var importer=AssetImporter.GetAtPath(texturePath) as TextureImporter??throw new InvalidOperationException("Painted impact source missing.");
            importer.textureType=TextureImporterType.Default;importer.sRGBTexture=true;importer.alphaSource=TextureImporterAlphaSource.FromInput;importer.alphaIsTransparency=true;importer.isReadable=false;
            importer.mipmapEnabled=false;importer.wrapMode=TextureWrapMode.Clamp;importer.filterMode=FilterMode.Bilinear;importer.maxTextureSize=1024;importer.textureCompression=TextureImporterCompression.CompressedHQ;
            var settings=importer.GetPlatformTextureSettings("Standalone");settings.name="Standalone";settings.overridden=true;settings.format=TextureImporterFormat.BC7;settings.maxTextureSize=1024;settings.compressionQuality=100;importer.SetPlatformTextureSettings(settings);importer.SaveAndReimport();
            const string path="Assets/Game/Resources/Eternal/Materials/PaintedImpact.mat";var material=AssetDatabase.LoadAssetAtPath<Material>(path);
            var shader=Shader.Find("Eternal/PaintedImpact")??throw new InvalidOperationException("Painted impact shader missing.");
            if(material==null){material=new Material(shader);AssetDatabase.CreateAsset(material,path);}else material.shader=shader;
            material.mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath);EditorUtility.SetDirty(material);AssetDatabase.SaveAssets();
            return "Imported four painted impact cells at 1024 with BC7 alpha; existing original skill profiles still determine timing, motifs and colors.";
        }
    }
}
