using System;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class PaintedSkillShapesInstaller
    {
        public static string Apply()
        {
            if(Application.isPlaying)throw new InvalidOperationException("Stop Play before importing skill shapes.");
            AssetDatabase.Refresh();
            const string texturePath="Assets/Game/Resources/Eternal/Vfx/painted-skill-shapes-v1.png";
            var importer=AssetImporter.GetAtPath(texturePath) as TextureImporter??throw new InvalidOperationException("Skill shape source missing.");
            importer.textureType=TextureImporterType.Default;importer.sRGBTexture=true;importer.alphaSource=TextureImporterAlphaSource.FromInput;importer.alphaIsTransparency=true;importer.isReadable=false;
            importer.mipmapEnabled=false;importer.wrapMode=TextureWrapMode.Clamp;importer.filterMode=FilterMode.Bilinear;importer.maxTextureSize=1024;importer.textureCompression=TextureImporterCompression.CompressedHQ;
            foreach(string platform in new[]{"Standalone","Android"})
            {
                var setting=importer.GetPlatformTextureSettings(platform);setting.name=platform;setting.overridden=true;setting.maxTextureSize=1024;setting.compressionQuality=100;
                setting.format=platform=="Android"?TextureImporterFormat.ASTC_6x6:TextureImporterFormat.BC7;importer.SetPlatformTextureSettings(setting);
            }
            importer.SaveAndReimport();
            InstallMaterial("PaintedSkillShapes","Eternal/PaintedImpact",AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath));
            InstallMaterial("RaidTelegraph","Eternal/RaidTelegraph",null);
            AssetDatabase.SaveAssets();
            return "Eight transparent skill shapes imported at 1024 BC7; raid telegraph material installed. Android ASTC is authored, not device tested.";
        }
        static void InstallMaterial(string name,string shaderName,Texture2D texture)
        {
            string path="Assets/Game/Resources/Eternal/Materials/"+name+".mat";
            var shader=Shader.Find(shaderName)??throw new InvalidOperationException("Missing shader: "+shaderName);
            var material=AssetDatabase.LoadAssetAtPath<Material>(path);
            if(material==null){material=new Material(shader);AssetDatabase.CreateAsset(material,path);}else material.shader=shader;
            if(texture!=null)material.mainTexture=texture;
            EditorUtility.SetDirty(material);
        }
    }
}
