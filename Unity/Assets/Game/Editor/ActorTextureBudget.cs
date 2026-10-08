using System;
using System.IO;
using System.Security.Cryptography;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class ActorTextureBudget
    {
        const string Actors="Assets/OriginalImported/Resources/Eternal/Actors/";
        public static void Configure(TextureImporter importer)
        {
            importer.textureType=TextureImporterType.Default;importer.sRGBTexture=true;
            importer.alphaSource=TextureImporterAlphaSource.FromInput;importer.alphaIsTransparency=true;importer.isReadable=false;
            importer.mipmapEnabled=true;importer.wrapMode=TextureWrapMode.Clamp;importer.filterMode=FilterMode.Bilinear;importer.maxTextureSize=1024;
            importer.textureCompression=TextureImporterCompression.CompressedHQ;importer.compressionQuality=100;
            var desktop=importer.GetPlatformTextureSettings("Standalone");desktop.name="Standalone";desktop.overridden=true;desktop.maxTextureSize=1024;desktop.format=TextureImporterFormat.BC7;desktop.textureCompression=TextureImporterCompression.CompressedHQ;desktop.compressionQuality=100;desktop.crunchedCompression=false;importer.SetPlatformTextureSettings(desktop);
            var mobile=importer.GetPlatformTextureSettings("Android");mobile.name="Android";mobile.overridden=true;mobile.maxTextureSize=1024;mobile.format=TextureImporterFormat.ASTC_6x6;mobile.textureCompression=TextureImporterCompression.CompressedHQ;mobile.compressionQuality=100;mobile.crunchedCompression=false;importer.SetPlatformTextureSettings(mobile);
        }
        static string Hash(string path)
        {using var sha=SHA256.Create();return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();}
        public static string Apply()
        {
            if(Application.isPlaying)throw new InvalidOperationException("Stop native Play before reimporting actor textures.");
            var entries=OriginalCatalog.Actors.entries;var records=new JArray();long beforeTotal=0,afterTotal=0;
            foreach(var actor in entries)
            {
                string path=Actors+actor.id+"/poses.png";string hash=Hash(path);var before=AssetDatabase.LoadAssetAtPath<Texture2D>(path);long beforeBytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(before);string beforeFormat=before.format.ToString();
                var importer=AssetImporter.GetAtPath(path) as TextureImporter??throw new InvalidOperationException("Original actor importer missing: "+actor.id);
                Configure(importer);importer.SaveAndReimport();var texture=AssetDatabase.LoadAssetAtPath<Texture2D>(path);long bytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(texture);
                if(Hash(path)!=hash||texture.width!=1024||texture.height!=1024||texture.format!=TextureFormat.BC7||texture.isReadable||!texture.alphaIsTransparency)throw new InvalidOperationException("Actor compression changed source pixels or lost expected imported format: "+actor.id);
                beforeTotal+=beforeBytes;afterTotal+=bytes;
                records.Add(new JObject{{"id",actor.id},{"hero",actor.hero},{"source_sha256",hash},{"width",texture.width},{"height",texture.height},{"before_format",beforeFormat},{"after_format",texture.format.ToString()},{"before_runtime_texture_bytes",beforeBytes},{"after_runtime_texture_bytes",bytes},{"mipmaps",texture.mipmapCount},{"source_file_unchanged",true},{"android_format_setting","ASTC_6x6"}});
            }
            AssetDatabase.SaveAssets();var report=new JObject{{"passed",true},{"actors",records.Count},{"before_runtime_texture_bytes",beforeTotal},{"after_runtime_texture_bytes",afterTotal},{"source_pngs_unchanged",true},{"records",records},{"note","Windows Editor imported texture allocation only. Android ASTC settings are authored; Android rendering/device allocation and total standalone 60fps/200MB remain unmeasured. Native visual acceptance is separate."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/actor-texture-budget.json",report.ToString());return report.ToString();
        }
    }
}
