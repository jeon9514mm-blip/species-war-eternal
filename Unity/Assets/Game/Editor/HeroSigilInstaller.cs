using System;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class HeroSigilInstaller
    {
        public static string Apply()
        {
            if(Application.isPlaying)throw new InvalidOperationException("Stop Play before importing hero sigils.");AssetDatabase.Refresh();
            for(int i=0;i<2;i++)
            {
                string path="Assets/Game/Resources/Eternal/Vfx/HeroSigils/"+(i==0?"aurelia":"noxfera")+"-v1.png";
                var importer=AssetImporter.GetAtPath(path) as TextureImporter??throw new InvalidOperationException("Missing sigil atlas "+path);
                importer.textureType=TextureImporterType.Default;importer.sRGBTexture=true;importer.alphaSource=TextureImporterAlphaSource.FromInput;importer.alphaIsTransparency=true;importer.isReadable=false;importer.mipmapEnabled=false;importer.wrapMode=TextureWrapMode.Clamp;importer.filterMode=FilterMode.Bilinear;importer.maxTextureSize=1024;importer.textureCompression=TextureImporterCompression.CompressedHQ;
                foreach(string platform in new[]{"Standalone","Android"}){var setting=importer.GetPlatformTextureSettings(platform);setting.name=platform;setting.overridden=true;setting.maxTextureSize=1024;setting.compressionQuality=100;setting.format=platform=="Android"?TextureImporterFormat.ASTC_6x6:TextureImporterFormat.BC7;importer.SetPlatformTextureSettings(setting);}importer.SaveAndReimport();
                string materialPath="Assets/Game/Resources/"+PaintedHeroSigils.Materials[i]+".mat";var material=AssetDatabase.LoadAssetAtPath<Material>(materialPath);if(material==null){material=new Material(Shader.Find("Eternal/PaintedImpact")??throw new InvalidOperationException("Painted shader missing."));AssetDatabase.CreateAsset(material,materialPath);}material.mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>(path);EditorUtility.SetDirty(material);
            }
            AssetDatabase.SaveAssets();return "Two unchanged RGBA sources imported; thirty mapped hero sigils. BC7/ASTC importer settings authored; runtime format and device acceptance must be measured separately.";
        }
    }
}
