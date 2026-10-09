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
        {
            if(Application.isPlaying)throw new InvalidOperationException("Stop Play before importing painted sheets.");
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);var rows=new JArray();
            foreach(string id in FallenMonsterCatalog.Ids.Concat(new[]{"orwin","caelum","kairen"}))
            {
                bool monster=FallenMonsterCatalog.Contains(id);string root="Assets/Game/Resources/Eternal/"+(monster?"Actors/":"HeroStyles/")+id;string path=root+"/poses.png";
                var importer=AssetImporter.GetAtPath(path) as TextureImporter??throw new InvalidOperationException("New sheet missing: "+id);
                importer.textureType=TextureImporterType.Default;importer.npotScale=TextureImporterNPOTScale.None;importer.isReadable=true;importer.maxTextureSize=1024;importer.mipmapEnabled=false;importer.alphaSource=TextureImporterAlphaSource.FromInput;importer.alphaIsTransparency=true;importer.textureCompression=TextureImporterCompression.Uncompressed;
                importer.SetPlatformTextureSettings(new TextureImporterPlatformSettings{name="Standalone",overridden=true,maxTextureSize=1024,format=TextureImporterFormat.RGBA32});importer.SaveAndReimport();
                var texture=AssetDatabase.LoadAssetAtPath<Texture2D>(path);if(texture.width!=1024||texture.height!=1024)throw new InvalidOperationException("Square 1024 import required: "+id);
                var pixels=texture.GetPixels32();var poses=new PoseFrame[4];int[] gutters=new int[4];
                for(int cell=0;cell<4;cell++)
                {
                    int x0=cell%2*512,y0=cell/2*512,minX=512,minY=512,maxX=-1,maxY=-1;
                    for(int y=0;y<512;y++)for(int x=0;x<512;x++)if(pixels[(1023-y0-y)*1024+x0+x].a>24){minX=Math.Min(minX,x);maxX=Math.Max(maxX,x);minY=Math.Min(minY,y);maxY=Math.Max(maxY,y);}
                    if(maxX<0||maxY-minY<100)throw new InvalidOperationException("Empty or incomplete painted pose: "+id+" / "+cell);
                    double feetX=0;int feetCount=0;for(int y=Math.Max(minY,maxY-6);y<=maxY;y++)for(int x=minX;x<=maxX;x++)if(pixels[(1023-y0-y)*1024+x0+x].a>48){feetX+=x;feetCount++;}
                    float anchorX=(float)(feetCount>0?feetX/feetCount:(minX+maxX)*.5)-minX;
                    poses[cell]=new PoseFrame{region=new float[]{x0+minX,y0+minY,maxX-minX+1,maxY-minY+1},anchor=new[]{anchorX,(float)(maxY-minY+1)},hair_rect=new[]{.15f,0,.7f,.3f}};
                    gutters[cell]=Math.Min(Math.Min(minX,511-maxX),Math.Min(minY,511-maxY));
                    if(gutters[cell]<8)throw new InvalidOperationException("Pose touches quadrant edge: "+id+" / "+cell+" gutter="+gutters[cell]);
                }
                float height=poses[0].region[3];var atlas=new AtlasDefinition{id=id,attack=new PoseSet{native_height=height,frames=new[]{poses[0],poses[1],poses[2]}},motion=new PoseSet{native_height=height,frames=new[]{poses[0],poses[0],poses[3],poses[3],poses[0],poses[3],poses[1]}}};
                File.WriteAllText(root+"/frames.json",JsonUtility.ToJson(atlas,true));AssetDatabase.ImportAsset(root+"/frames.json",ImportAssetOptions.ForceSynchronousImport);
                ActorTextureBudget.Configure(importer);importer.SaveAndReimport();texture=AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                using var sha=SHA256.Create();string hash=BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();
                rows.Add(new JObject{{"id",id},{"path",path},{"source_sha256",hash},{"width",texture.width},{"height",texture.height},{"format",texture.format.ToString()},{"alpha",texture.alphaIsTransparency},{"minimum_pose_gutters",new JArray(gutters)},{"painted_poses",4},{"source_png_unmodified",true}});
            }
            AssetDatabase.SaveAssets();OriginalReliefMesh.Clear();var result=new JObject{{"passed",true},{"sheets",rows},{"mode","built-in image generation + targeted sprite-gutter edits"},{"note","Four painted poses per sheet, foot anchors measured from imported alpha. Procedural full-coverage relief; not rigged 3D motion or thirty hero redraws. Android ASTC authored, not device tested."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/painted-roster-cp14.json",result.ToString());return result.ToString();
        }
    }
}
