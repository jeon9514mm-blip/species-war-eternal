using System;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class PaintedGroundSealInstaller
    {
        public static string Apply()
        {
            if(Application.isPlaying)throw new InvalidOperationException("Stop Play before importing the painted seal.");AssetDatabase.Refresh();
            const string texturePath="Assets/Game/Resources/Eternal/Vfx/painted-moss-seal-v1.png";
            var importer=AssetImporter.GetAtPath(texturePath) as TextureImporter??throw new InvalidOperationException("Painted seal source missing.");
            importer.textureType=TextureImporterType.Default;importer.sRGBTexture=true;importer.alphaSource=TextureImporterAlphaSource.FromInput;importer.alphaIsTransparency=true;importer.isReadable=false;
            importer.mipmapEnabled=false;importer.wrapMode=TextureWrapMode.Clamp;importer.filterMode=FilterMode.Bilinear;importer.maxTextureSize=1024;importer.textureCompression=TextureImporterCompression.CompressedHQ;
            var settings=importer.GetPlatformTextureSettings("Standalone");settings.name="Standalone";settings.overridden=true;settings.format=TextureImporterFormat.BC7;settings.maxTextureSize=1024;settings.compressionQuality=100;importer.SetPlatformTextureSettings(settings);importer.SaveAndReimport();
            var mobile=importer.GetPlatformTextureSettings("Android");mobile.name="Android";mobile.overridden=true;mobile.format=TextureImporterFormat.ASTC_6x6;mobile.maxTextureSize=1024;importer.SetPlatformTextureSettings(mobile);importer.SaveAndReimport();
            const string path="Assets/Game/Resources/Eternal/Materials/PaintedGroundSeal.mat";var material=AssetDatabase.LoadAssetAtPath<Material>(path);
            var shader=Shader.Find("Eternal/PaintedGroundSeal")??throw new InvalidOperationException("Painted seal shader missing.");
            if(material==null){material=new Material(shader);AssetDatabase.CreateAsset(material,path);}else material.shader=shader;
            material.mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath);material.SetFloat("_Opacity",.58f);material.SetFloat("_RotationRate",.12f);EditorUtility.SetDirty(material);AssetDatabase.SaveAssets();
            return "Imported transparent moss/bronze seal as one ground quad, 1024 BC7 / authored Android ASTC6x6, ground depth and bounded shader pulse/rotation.";
        }
    }
}
