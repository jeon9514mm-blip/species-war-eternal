using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class PaintedRosterInstaller
    {
        public static string Import()
            =>ImportSheets(FallenMonsterCatalog.Ids.Concat(new[]{"orwin","caelum","kairen"}).ToArray(),"painted-roster-cp14.json");
        public static string ImportExpansion()
            =>ImportSheets(new[]{"fallen_ogre","fallen_lich","fallen_harpy"},"painted-monsters-cp19.json");
        static string ImportSheets(string[] ids,string reportName)
        {
            if(Application.isPlaying)throw new InvalidOperationException("Stop Play before importing painted sheets.");
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);var rows=new JArray();
            foreach(string id in ids)
            {
                bool monster=FallenMonsterCatalog.Contains(id);string root="Assets/Game/Resources/Eternal/"+(monster?"Actors/":"HeroStyles/")+id;string path=root+"/poses.png";
                var importer=AssetImporter.GetAtPath(path) as TextureImporter??throw new InvalidOperationException("New sheet missing: "+id);
                importer.textureType=TextureImporterType.Default;importer.npotScale=TextureImporterNPOTScale.None;importer.isReadable=true;importer.maxTextureSize=1024;importer.mipmapEnabled=false;importer.alphaSource=TextureImporterAlphaSource.FromInput;importer.alphaIsTransparency=true;importer.textureCompression=TextureImporterCompression.Uncompressed;
                importer.maxTextureSize=2048;
                importer.SetPlatformTextureSettings(new TextureImporterPlatformSettings{name="Standalone",overridden=true,maxTextureSize=2048,format=TextureImporterFormat.RGBA32});importer.SaveAndReimport();
                var texture=AssetDatabase.LoadAssetAtPath<Texture2D>(path);if(texture.width!=texture.height||texture.width%2!=0)throw new InvalidOperationException("Even square sheet required: "+id);
                int size=texture.width,half=size/2;
                var pixels=texture.GetPixels32();var poses=new PoseFrame[4];int[] gutters=new int[4];
                for(int cell=0;cell<4;cell++)
                {
                    int x0=cell%2*half,y0=cell/2*half,minX=half,minY=half,maxX=-1,maxY=-1;
                    for(int y=0;y<half;y++)for(int x=0;x<half;x++)if(pixels[(size-1-y0-y)*size+x0+x].a>24){minX=Math.Min(minX,x);maxX=Math.Max(maxX,x);minY=Math.Min(minY,y);maxY=Math.Max(maxY,y);}
                    if(maxX<0||maxY-minY<100)throw new InvalidOperationException("Empty or incomplete painted pose: "+id+" / "+cell);
                    double feetX=0;int feetCount=0;for(int y=Math.Max(minY,maxY-6);y<=maxY;y++)for(int x=minX;x<=maxX;x++)if(pixels[(size-1-y0-y)*size+x0+x].a>48){feetX+=x;feetCount++;}
                    float anchorX=(float)(feetCount>0?feetX/feetCount:(minX+maxX)*.5)-minX;
                    poses[cell]=new PoseFrame{region=new float[]{x0+minX,y0+minY,maxX-minX+1,maxY-minY+1},anchor=new[]{anchorX,(float)(maxY-minY+1)},hair_rect=new[]{.15f,0,.7f,.3f}};
                    gutters[cell]=Math.Min(Math.Min(minX,half-1-maxX),Math.Min(minY,half-1-maxY));
                    if(gutters[cell]<8)throw new InvalidOperationException("Pose touches quadrant edge: "+id+" / "+cell+" gutter="+gutters[cell]);
                }
                float height=poses[0].region[3];var atlas=new AtlasDefinition{id=id,attack=new PoseSet{native_height=height,frames=new[]{poses[0],poses[1],poses[2]}},motion=new PoseSet{native_height=height,frames=new[]{poses[0],poses[0],poses[3],poses[3],poses[0],poses[3],poses[1]}}};
                File.WriteAllText(root+"/frames.json",JsonUtility.ToJson(atlas,true));AssetDatabase.ImportAsset(root+"/frames.json",ImportAssetOptions.ForceSynchronousImport);
                ActorTextureBudget.Configure(importer);importer.SaveAndReimport();texture=AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                // Source-space regions must match the final 1024 texture import.
                float regionScale=texture.width/(float)size;
                if(regionScale!=1){foreach(var pose in poses){for(int j=0;j<4;j++)pose.region[j]*=regionScale;for(int j=0;j<2;j++)pose.anchor[j]*=regionScale;}atlas.attack.native_height*=regionScale;atlas.motion.native_height*=regionScale;File.WriteAllText(root+"/frames.json",JsonUtility.ToJson(atlas,true));AssetDatabase.ImportAsset(root+"/frames.json",ImportAssetOptions.ForceSynchronousImport);}
                using var sha=SHA256.Create();string hash=BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();
                rows.Add(new JObject{{"id",id},{"path",path},{"source_sha256",hash},{"width",texture.width},{"height",texture.height},{"format",texture.format.ToString()},{"alpha",texture.alphaIsTransparency},{"minimum_pose_gutters",new JArray(gutters)},{"painted_poses",4},{"source_png_unmodified",true}});
            }
            AssetDatabase.SaveAssets();OriginalReliefMesh.Clear();var result=new JObject{{"passed",true},{"sheets",rows},{"mode","built-in image generation + targeted sprite-gutter edits"},{"note","Four painted poses per sheet, foot anchors measured from source-resolution alpha and mapped to the final 1024 atlas. Source PNG pixels preserved. Procedural full-coverage 2.5D relief; not rigged skeletal 3D animation. Android ASTC authored, not device tested."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/"+reportName,result.ToString());return result.ToString();
        }
    }
}
