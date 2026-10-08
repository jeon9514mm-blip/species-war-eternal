using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Visual timelines consume combat events; they never delay a hit, spend a
    // resource, advance a cooldown, or write to the simulation clock.
    public sealed class SkillVfxProfile
    {
        public readonly string Signature,Hero,Slot,Motif,Kind;
        public readonly int Glyph,Symmetry,Seed;
        public readonly float Charge,Flight,Impact,Tail,Power,Twist;
        public readonly Color Color,Core;
        public SkillVfxProfile(JObject source)
        {
            Signature=(string)source["signature"];Hero=(string)source["hero_id"];
            Slot=Signature.Substring(Signature.LastIndexOf(':')+1);
            Motif=(string)source["motif"];Kind=(string)source["kind"];
            Glyph=(int?)source["glyph"]??0;Symmetry=Math.Clamp((int?)source["symmetry"]??6,4,12);Seed=(int?)source["seed"]??0;
            Charge=Number(source,"charge",.18f);Flight=Number(source,"flight",.12f);
            Impact=Number(source,"impact",.18f);Tail=Number(source,"tail",.4f);
            Power=Number(source,"power",1);Twist=Number(source,"twist",.1f);
            Color=ReadColor(source,"color",UnityEngine.Color.white);Core=ReadColor(source,"core",Color);
        }
        static float Number(JObject source,string key,float fallback)=>Mathf.Max(.01f,(float?)source[key]??fallback);
        static Color ReadColor(JObject source,string key,Color fallback)=>ColorUtility.TryParseHtmlString((string)source[key]??"",out var value)?value:fallback;
        public float Lifetime=>Mathf.Clamp(Flight+Impact+Tail,.45f,1.4f);
        // Thirty motif families retain their original colors, glyph, symmetry,
        // twist and per-slot seed rather than sharing one radial particle burst.
        public int Family=>Motif switch
        {
            "bastion" or "phalanx" or "mountain" or "royalseal"=>0,
            "worldtree" or "thousandleaves" or "dawnchoir" or "twilightchoir"=>1,
            "reticle" or "seveneyes" or "runecannon" or "sixfeathers"=>2,
            "bloodrose" or "redthreads" or "duelcrest" or "huntingfang" or "ironfang" or "judgement" or "oathspear" or "nightdance"=>3,
            "frostclaws" or "snowfist" or "mistmaze"=>4,
            "alchemy"=>5,
            _=>6
        };
    }

    public sealed class SkillVfxBatch : IDisposable
    {
        public const int Capacity=50,QuadsPerEffect=96;
        struct Effect {public SkillVfxProfile profile;public Vector3 from,to;public float age,lifetime;public bool charge;}
        readonly Effect[] effects=new Effect[Capacity];
        readonly List<Vector3> vertices=new(Capacity*QuadsPerEffect*4);
        readonly List<Color> colors=new(Capacity*QuadsPerEffect*4);
        readonly List<Vector2> uvs=new(Capacity*QuadsPerEffect*4);
        readonly List<int> triangles=new(Capacity*QuadsPerEffect*6);
        readonly Dictionary<string,SkillVfxProfile> profiles=new(StringComparer.Ordinal);
        readonly Mesh mesh;
        readonly Material material;
        readonly GameObject root;
        readonly Mesh paintedMesh;
        readonly Material paintedMaterial;
        readonly GameObject paintedRoot;
        readonly Camera camera;
        readonly List<Vector3> paintedVertices=new(Capacity*4);
        readonly List<Color> paintedColors=new(Capacity*4);
        readonly List<Vector2> paintedUvs=new(Capacity*4);
        readonly List<int> paintedTriangles=new(Capacity*6);
        public int PaintedQuads=>paintedVertices.Count/4;
        int cursor,effectQuads;
        public int ActiveEffects {get;private set;}
        public int PresentedSkills {get;private set;}
        public int Quads=>vertices.Count/4;
        public IReadOnlyDictionary<string,SkillVfxProfile> Profiles=>profiles;
        public SkillVfxBatch(Transform owner,Material template,JArray catalog,Camera camera=null)
        {
            foreach(JObject item in catalog){var profile=new SkillVfxProfile(item);profiles.Add(profile.Signature,profile);}
            mesh=new Mesh{name="50-slot original skill timeline batch"};mesh.MarkDynamic();
            material=new Material(template);material.SetFloat("_SoftDot",0);
            root=new GameObject("Original skill charge launch impact and echo batch");root.transform.SetParent(owner,false);
            root.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=root.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;renderer.sortingOrder=1100;
            renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;
            this.camera=camera;var paintedTemplate=Resources.Load<Material>("Eternal/Materials/PaintedImpact");
            if(paintedTemplate!=null)
            {
                paintedMaterial=new Material(paintedTemplate);paintedMesh=new Mesh{name="50-slot painted elemental impact batch"};paintedMesh.MarkDynamic();
                paintedRoot=new GameObject("Painted fire frost light shadow impact batch");paintedRoot.transform.SetParent(owner,false);
                paintedRoot.AddComponent<MeshFilter>().sharedMesh=paintedMesh;var r=paintedRoot.AddComponent<MeshRenderer>();r.sharedMaterial=paintedMaterial;r.sortingOrder=1101;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;
            }
        }
        public bool Observe(BattleEvent e,CombatEncounter battle)
        {
            if(e.Kind!="windup"&&e.Kind!="cast"&&e.Kind!="passive")return false;
            if(e.Source==null||e.Slot==null||!profiles.TryGetValue(e.Source+":"+e.Slot,out var profile))return false;
            var source=Find(battle,e.SourceSerial);var target=Find(battle,e.TargetSerial);
            var from=source?.Position??e.Position;var to=target?.Position??e.Position;
            if(e.Kind!="windup")
            {
                // A confirmed cast supersedes its charge. Interrupted charges
                // expire independently and never create an impact event.
                for(int i=0;i<effects.Length;i++)if(effects[i].charge&&effects[i].profile==profile)effects[i]=default;
                PresentedSkills++;
            }
            float life=e.Kind=="windup"?.18f:profile.Lifetime;
            effects[cursor++%Capacity]=new Effect{profile=profile,from=new Vector3(from.x,.065f,from.y),to=new Vector3(to.x,.07f,to.y),lifetime=life,charge=e.Kind=="windup"};
            return true;
        }
        static Combatant Find(CombatEncounter battle,int serial)
        {foreach(var h in battle.Heroes)if(h.Serial==serial)return h;foreach(var e in battle.Enemies)if(e.Serial==serial)return e;return null;}
        public void Clear(){Array.Clear(effects,0,effects.Length);mesh.Clear();paintedMesh?.Clear();paintedVertices.Clear();ActiveEffects=0;}
        public void Advance(float dt,bool warning)
        {
            vertices.Clear();colors.Clear();uvs.Clear();triangles.Clear();ActiveEffects=0;
            paintedVertices.Clear();paintedColors.Clear();paintedUvs.Clear();paintedTriangles.Clear();
            for(int i=0;i<effects.Length;i++)
            {
                var e=effects[i];if(e.profile==null)continue;e.age+=Mathf.Max(0,dt);
                if(e.age>=e.lifetime){effects[i]=default;continue;}effects[i]=e;ActiveEffects++;effectQuads=0;
                Draw(e,warning);
                DrawPainted(e,warning);
            }
            // The next timeline can have fewer vertices than the previous one.
            // Drop stale indices before resizing, including the zero-effect frame.
            mesh.Clear(true);mesh.SetVertices(vertices);mesh.SetColors(colors);mesh.SetUVs(0,uvs);mesh.SetTriangles(triangles,0,false);
            mesh.bounds=new Bounds(Vector3.zero,new Vector3(70,20,50));
            if(paintedMesh!=null)
            {paintedMesh.Clear(true);paintedMesh.SetVertices(paintedVertices);paintedMesh.SetColors(paintedColors);paintedMesh.SetUVs(0,paintedUvs);paintedMesh.SetTriangles(paintedTriangles,0,false);paintedMesh.RecalculateBounds();}
        }
        void DrawPainted(Effect e,bool warning)
        {
            if(paintedMesh==null||e.charge||e.age>.38f)return;var p=e.profile;float t=e.age/.38f;
            // Preserve 30 authored signatures. This shared four-cell art adds
            // painted energy to their procedural glyphs rather than replacing
            // every hero's skill with one bitmap.
            int cell=p.Family==4?1:p.Kind=="heal"||p.Kind=="buff"||p.Family==0||p.Family==1?2:p.Color.b>p.Color.r*1.15f?3:0;
            float size=(p.Slot=="ultimate"?3.6f:2.6f)*(.8f+Mathf.Sin(t*Mathf.PI*.8f)*.4f);
            float a=Mathf.Pow(1-t,1.15f)*(p.Slot=="ultimate"?.95f:.85f)*(warning?.26f:1);
            var color=Color.Lerp(Color.white,p.Color,.18f);color.a=a;
            Vector3 right=camera!=null?camera.transform.right:Vector3.right,up=camera!=null?camera.transform.up:Vector3.up;
            // Keep the impact above the depth-writing floor, including its lower
            // billboard corner. The painted center follows the real target.
            var center=e.to+Vector3.up*1.25f;right*=size*.5f;up*=size*.5f;int v=paintedVertices.Count;
            paintedVertices.Add(center-right-up);paintedVertices.Add(center-right+up);paintedVertices.Add(center+right+up);paintedVertices.Add(center+right-up);
            for(int k=0;k<4;k++)paintedColors.Add(color);
            float x=(cell%2)*.5f,y=cell<2?.5f:0;const float gutter=.002f;
            paintedUvs.Add(new Vector2(x+gutter,y+gutter));paintedUvs.Add(new Vector2(x+gutter,y+.5f-gutter));paintedUvs.Add(new Vector2(x+.5f-gutter,y+.5f-gutter));paintedUvs.Add(new Vector2(x+.5f-gutter,y+gutter));
            paintedTriangles.Add(v);paintedTriangles.Add(v+1);paintedTriangles.Add(v+2);paintedTriangles.Add(v);paintedTriangles.Add(v+2);paintedTriangles.Add(v+3);
        }
        void Draw(Effect e,bool warning)
        {
            var p=e.profile;float t=e.age/e.lifetime;
            float fade=e.charge?Mathf.Lerp(.2f,.7f,t):Mathf.Clamp01((1-t)*2.8f);
            if(!e.charge&&paintedMesh!=null&&e.age<.38f)fade*=.48f;
            if(warning)fade*=.38f;
            var color=p.Color;color.a=fade*.75f;var core=p.Core;core.a=fade;
            float rotation=p.Twist*e.age+p.Glyph*.13f+p.Seed*.017f;
            float radius=(e.charge?.35f:.65f+Mathf.Min(p.Power,2)*.25f)*(e.charge?.8f+t*.4f:1+Mathf.Sin(t*Mathf.PI)*.3f);
            var center=e.charge?e.from:e.to;
            if(e.charge){Ring(center,radius,rotation,20,.025f,color);Glyph(center,radius*.6f,p.Glyph,rotation,core);return;}
            // Flight and its five fading echoes originate from the actual
            // caster position, while impact starts at the confirmed hit.
            if(p.Family==2||p.Slot=="ultimate")
            {
                float flight=Mathf.Clamp01(e.age/Mathf.Min(.24f,p.Flight));
                for(int echo=0;echo<5;echo++)
                {float progress=Mathf.Clamp01(flight-echo*.09f);var c=color;c.a*=1-echo*.15f;var point=Vector3.Lerp(e.from,e.to,progress)+Vector3.up*Mathf.Sin(progress*Mathf.PI)*.45f;Line(point-Vector3.up*.06f,point+Vector3.up*.12f,.028f,c);}
            }
            Ring(center,radius,rotation,24,.028f,color);
            if(p.Slot=="ultimate")Ring(center,radius*1.16f,-rotation,24,.016f,core);
            switch(p.Family)
            {
                case 0:
                    Polygon(center,radius*.83f,rotation,p.Symmetry,.035f,core);
                    for(int k=0;k<p.Symmetry;k++){var point=Polar(center,radius,rotation+k*Mathf.PI*2/p.Symmetry);Line(point,point+Vector3.up*(.28f+.12f*Mathf.Sin(t*Mathf.PI)),.035f,color);}break;
                case 1:
                    for(int k=0;k<p.Symmetry;k++)
                    {float a=rotation+k*Mathf.PI*2/p.Symmetry;var stem=Polar(center,radius*.8f,a);Line(center,stem,.02f,color);Line(Vector3.Lerp(center,stem,.62f),Polar(center,radius*.82f,a+.22f),.03f,core);Line(Vector3.Lerp(center,stem,.62f),Polar(center,radius*.82f,a-.22f),.03f,core);}break;
                case 2:
                    for(int k=0;k<4;k++){float a=rotation+k*Mathf.PI*.5f;Line(Polar(center,radius*.6f,a),Polar(center,radius*1.25f,a),.035f,core);}Ring(center,radius*.45f,-rotation,16,.02f,core);break;
                case 3:
                    for(int k=0;k<3;k++)Arc(center,radius*(.65f+k*.2f),rotation+k*.9f+t*2.4f,Mathf.PI*1.2f,10,.035f+k*.007f,k==1?core:color);break;
                case 4:
                    for(int k=0;k<6;k++){float a=rotation+k*Mathf.PI/3;var tip=Polar(center,radius,a);var mid=Polar(center,radius*.6f,a);Line(center,tip,.025f,core);Line(mid,Polar(center,radius*.8f,a+.15f),.02f,color);Line(mid,Polar(center,radius*.8f,a-.15f),.02f,color);}break;
                case 5:
                    Polygon(center,radius*.78f,rotation,3,.032f,core);Polygon(center,radius*.78f,rotation+Mathf.PI,3,.032f,color);Ring(center,radius*.32f,-rotation,12,.024f,core);break;
                default:
                    for(int k=0;k<p.Symmetry;k++){float a=rotation+k*Mathf.PI*2/p.Symmetry;var orbit=Polar(center,radius*.7f,a);Arc(orbit,radius*.18f,-a+t*3,Mathf.PI*1.4f,4,.025f,k%2==0?core:color);}break;
            }
            Glyph(center,radius*.5f,p.Glyph,rotation,core);
            if(e.age<.12f)
            {var hit=core;hit.a*=1-e.age/.12f;Line(center-Vector3.right*radius*.35f+Vector3.up*.3f,center+Vector3.right*radius*.35f+Vector3.up*.3f,.065f,hit);Line(center,center+Vector3.up*.65f,.04f,hit);}
        }
        static Vector3 Polar(Vector3 center,float radius,float angle)=>center+new Vector3(Mathf.Cos(angle)*radius,0,Mathf.Sin(angle)*radius);
        void Polygon(Vector3 c,float r,float a,int sides,float w,Color color)
        {for(int i=0;i<sides;i++)Line(Polar(c,r,a+i*Mathf.PI*2/sides),Polar(c,r,a+(i+1)*Mathf.PI*2/sides),w,color);}
        void Ring(Vector3 c,float r,float a,int sides,float w,Color color)=>Polygon(c,r,a,sides,w,color);
        void Arc(Vector3 c,float r,float a,float length,int sides,float w,Color color)
        {for(int i=0;i<sides;i++)Line(Polar(c,r,a+i*length/sides),Polar(c,r,a+(i+1)*length/sides),w,color);}
        void Glyph(Vector3 c,float r,int glyph,float angle,Color color)
        {
            // Five independent bits plus rotation/symmetry distinguish all 30
            // original hero signatures in both charge and settled aftermath.
            for(int bit=0;bit<5;bit++)if((glyph&(1<<bit))!=0)
            {float a=angle+bit*Mathf.PI*2/5;Line(Polar(c,r*.2f,a),Polar(c,r,a+.24f),.024f,color);}
            Line(c-Vector3.right*r*.17f,c+Vector3.right*r*.17f,.026f,color);
        }
        void Line(Vector3 from,Vector3 to,float width,Color color)
        {
            if(effectQuads++>=QuadsPerEffect)return;
            var direction=to-from;var normal=Vector3.Cross(direction,Vector3.up).normalized;
            if(normal.sqrMagnitude<.01f)normal=Vector3.right;
            normal*=width*.5f;int v=vertices.Count;
            vertices.Add(from-normal);vertices.Add(from+normal);vertices.Add(to+normal);vertices.Add(to-normal);
            for(int i=0;i<4;i++)colors.Add(color);
            uvs.Add(Vector2.zero);uvs.Add(Vector2.up);uvs.Add(Vector2.one);uvs.Add(Vector2.right);
            triangles.Add(v);triangles.Add(v+1);triangles.Add(v+2);triangles.Add(v);triangles.Add(v+2);triangles.Add(v+3);
        }
        public void Dispose(){Release(root);Release(mesh);Release(material);Release(paintedRoot);Release(paintedMesh);Release(paintedMaterial);}
        static void Release(UnityEngine.Object value){if(value==null)return;if(Application.isPlaying)UnityEngine.Object.Destroy(value);else UnityEngine.Object.DestroyImmediate(value);}
    }
}
