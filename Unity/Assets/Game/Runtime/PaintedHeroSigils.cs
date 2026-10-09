using System;
using System.Collections.Generic;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Thirty original hero identities, two immutable painted atlases. One quad
    // per active skill timeline; no independent combat or particle clock.
    public sealed class PaintedHeroSigils : IDisposable
    {
        public static readonly string[] Materials={"Eternal/Materials/HeroSigilsAurelia","Eternal/Materials/HeroSigilsNoxfera"};
        public static readonly string[][] Heroes={
            new[]{"leonhardt","mira","elisia","kairen","orwin","seria","astel","darius","lunea","caelum","adrien","tessa","naia","sael","odelia"},
            new[]{"valeria","morgas","ragna","bron","nyx","fenris","isolde","garm","veyra","ulric","lucien","corvin","rokan","bora","selene"}};
        static readonly Dictionary<string,(int bank,int cell)> mapping=BuildMapping();
        static Dictionary<string,(int,int)> BuildMapping(){var result=new Dictionary<string,(int,int)>(StringComparer.Ordinal);for(int bank=0;bank<2;bank++)for(int cell=0;cell<15;cell++)result.Add(Heroes[bank][cell],(bank,cell));return result;}
        public static Rect CellUV(int cell)
        {if(cell<0||cell>=15)throw new ArgumentOutOfRangeException(nameof(cell));const float gutter=.03f;return new Rect((cell%5+gutter)/5,(2-cell/5+gutter)/3,(1-2*gutter)/5,(1-2*gutter)/3);}
        public static bool TryIcon(string hero,out Texture2D texture,out Rect uv)
        {texture=null;uv=default;if(!mapping.TryGetValue(hero,out var cell))return false;var material=Resources.Load<Material>(Materials[cell.bank]);texture=material?.mainTexture as Texture2D;uv=CellUV(cell.cell);return texture!=null;}
        sealed class Bank
        {
            public GameObject root;public Mesh mesh;public Material material;public float aspect;
            public readonly List<Vector3> vertices=new(200);public readonly List<Color> colors=new(200);public readonly List<Vector2> uvs=new(200);public readonly List<int> triangles=new(300);
        }
        readonly Bank[] banks=new Bank[2];readonly Camera camera;
        public int Quads {get;private set;}public int ChargeQuads {get;private set;}public int FlightQuads {get;private set;}public int ImpactQuads {get;private set;}public int TailQuads {get;private set;}
        public PaintedHeroSigils(Transform owner,Camera camera)
        {
            this.camera=camera;
            for(int i=0;i<2;i++)
            {
                var template=Resources.Load<Material>(Materials[i]);if(template==null||template.mainTexture==null)continue;
                var bank=new Bank{root=new GameObject("Painted hero sigils "+i),mesh=new Mesh{name="Bounded thirty hero sigil atlas "+i},material=new Material(template),aspect=template.mainTexture.width*3f/(template.mainTexture.height*5f)};bank.mesh.MarkDynamic();bank.root.transform.SetParent(owner,false);bank.root.AddComponent<MeshFilter>().sharedMesh=bank.mesh;
                var renderer=bank.root.AddComponent<MeshRenderer>();renderer.sharedMaterial=bank.material;renderer.sortingOrder=1102;renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;banks[i]=bank;
            }
        }
        public bool Has(string hero)=>mapping.TryGetValue(hero,out var cell)&&banks[cell.bank]!=null;
        public void BeginFrame()
        {Quads=ChargeQuads=FlightQuads=ImpactQuads=TailQuads=0;foreach(var bank in banks)if(bank!=null){bank.vertices.Clear();bank.colors.Clear();bank.uvs.Clear();bank.triangles.Clear();}}
        public void Draw(SkillVfxProfile profile,Vector3 from,Vector3 to,float age,float lifetime,bool charge,bool recipient,bool warning)
        {
            if(Quads>=SkillVfxBatch.Capacity||!mapping.TryGetValue(profile.Hero,out var cell)||banks[cell.bank]==null)return;var bank=banks[cell.bank];
            float flight=SkillVfxBatch.FlightDuration(profile,Vector3.Distance(from,to),recipient),impact=age-flight,duration=SkillVfxBatch.ImpactDuration(profile);bool ultimate=profile.Slot=="ultimate";
            Vector3 center;float height,alpha;
            if(charge){float t=Mathf.Clamp01(age/lifetime);height=(ultimate?1.4f:1.0f)*(.8f+t*.2f);alpha=.18f+t*.20f;center=from+Vector3.up*.95f;ChargeQuads++;}
            else if(impact<0){center=Vector3.Lerp(from,to,Mathf.Clamp01(age/flight))+Vector3.up*.9f;height=1.0f;alpha=.58f;FlightQuads++;}
            else if(impact<duration){float t=impact/duration;height=(recipient?1.3f:ultimate?3.4f:2.4f)*(.92f+Mathf.Sin(t*Mathf.PI)*.12f);alpha=Mathf.Pow(1-t,1.15f)*(recipient?.38f:.90f);center=to+Vector3.up*(recipient?1.0f:1.05f);ImpactQuads++;}
            else {float t=Mathf.InverseLerp(flight+duration,lifetime,age);height=recipient?1.0f:ultimate?2.0f:1.6f;alpha=(1-t)*.12f;center=to+Vector3.up*(1.05f+t*.18f);TailQuads++;}
            var color=Color.Lerp(Color.white,profile.Color,.08f);color.a=alpha*(warning?.18f:1);float angle=profile.Twist*.12f*Mathf.Sin(age*Mathf.PI)+(profile.Slot=="a2"?.10f:0);
            var axisRight=camera!=null?camera.transform.right:Vector3.right;var axisUp=camera!=null?camera.transform.up:Vector3.up;
            var right=(axisRight*Mathf.Cos(angle)+axisUp*Mathf.Sin(angle))*height*bank.aspect*.5f;var up=(-axisRight*Mathf.Sin(angle)+axisUp*Mathf.Cos(angle))*height*.5f;int v=bank.vertices.Count;
            bank.vertices.Add(center-right-up);bank.vertices.Add(center-right+up);bank.vertices.Add(center+right+up);bank.vertices.Add(center+right-up);for(int i=0;i<4;i++)bank.colors.Add(color);
            var uv=CellUV(cell.cell);bank.uvs.Add(new Vector2(uv.xMin,uv.yMin));bank.uvs.Add(new Vector2(uv.xMin,uv.yMax));bank.uvs.Add(new Vector2(uv.xMax,uv.yMax));bank.uvs.Add(new Vector2(uv.xMax,uv.yMin));bank.triangles.Add(v);bank.triangles.Add(v+1);bank.triangles.Add(v+2);bank.triangles.Add(v);bank.triangles.Add(v+2);bank.triangles.Add(v+3);Quads++;
        }
        public void Flush(){foreach(var bank in banks)if(bank!=null){bank.mesh.Clear(true);bank.mesh.SetVertices(bank.vertices);bank.mesh.SetColors(bank.colors);bank.mesh.SetUVs(0,bank.uvs);bank.mesh.SetTriangles(bank.triangles,0,false);bank.mesh.RecalculateBounds();}}
        public void Clear(){BeginFrame();Flush();}
        public void Dispose(){foreach(var bank in banks)if(bank!=null){Release(bank.root);Release(bank.mesh);Release(bank.material);}}
        static void Release(UnityEngine.Object value){if(value==null)return;if(Application.isPlaying)UnityEngine.Object.Destroy(value);else UnityEngine.Object.DestroyImmediate(value);}
    }
}
