using System;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class HuntArtInstaller
    {
        public static string Import()
        {
            AssetDatabase.Refresh();var rows=new JArray();
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                string path="Assets/Game/Resources/"+HuntEnvironmentPresentation.Resource(zone)+".png";
                if(AssetImporter.GetAtPath(path) is not TextureImporter importer)throw new InvalidOperationException("Hunting painting missing: "+zone);
                importer.textureType=TextureImporterType.Default;importer.sRGBTexture=true;importer.alphaSource=TextureImporterAlphaSource.None;importer.mipmapEnabled=false;importer.isReadable=false;importer.wrapMode=TextureWrapMode.Clamp;importer.filterMode=FilterMode.Bilinear;importer.npotScale=TextureImporterNPOTScale.None;importer.maxTextureSize=1024;
                importer.SetPlatformTextureSettings(new TextureImporterPlatformSettings{name="Standalone",overridden=true,maxTextureSize=1024,format=TextureImporterFormat.BC7,compressionQuality=90});
                importer.SetPlatformTextureSettings(new TextureImporterPlatformSettings{name="Android",overridden=true,maxTextureSize=1024,format=TextureImporterFormat.ASTC_6x6,compressionQuality=90});importer.SaveAndReimport();
                var texture=AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                rows.Add(new JObject{{"zone",zone},{"path",path},{"width",texture.width},{"height",texture.height},{"editor_format",texture.format.ToString()},{"authored_standalone_format",importer.GetPlatformTextureSettings("Standalone").format.ToString()},{"authored_android_format",importer.GetPlatformTextureSettings("Android").format.ToString()},{"shader_supported",Shader.Find("Eternal/PaintedArena").isSupported},{"shader_errors",ShaderUtil.ShaderHasError(Shader.Find("Eternal/PaintedArena"))}});
            }
            AssetDatabase.SaveAssets();var report=new JObject{{"paintings",rows},{"native_import",true},{"android_device_verified",false},{"note","Built-in source PNGs retained unchanged; max-size 1024 paintings. BC7/ASTC6x6 are authored settings; observed texture format is recorded separately. World projection does not add remodeled collision or baked PBR."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/hunt-art-import.json",report.ToString());return report.ToString();
        }
    }
}
