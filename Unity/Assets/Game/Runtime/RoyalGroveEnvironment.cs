using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Eternal.UnityMigration
{
    // Authored volume geometry for the graphics rebuild. No painted backdrop,
    // camera-facing map plane, physics terrain or combat state is created here.
    public sealed class RoyalGroveEnvironment : MonoBehaviour
    {
        readonly List<Mesh> ownedMeshes=new();
        readonly List<Material> ownedMaterials=new();
        readonly Dictionary<Material,Surface> surfaces=new();
        Material stone,edge,dark,bronze,moss,bark,leaves,crystal,cloth;
        bool built;
        public void Build()
        {
            if(built)return;built=true;
            stone=Material("Grove limestone",new Color(.49f,.51f,.45f),0,.82f);
            edge=Material("Worn limestone edges",new Color(.64f,.65f,.55f),0,.72f);
            dark=Material("Recessed stone",new Color(.24f,.29f,.27f),0,.92f);
            bronze=Material("Aurelia bronze inlay",new Color(.56f,.39f,.18f),.75f,.35f);
            moss=Material("Moss seams",new Color(.21f,.32f,.16f),0,.95f);
            bark=Material("Old oak bark",new Color(.22f,.17f,.12f),0,.9f);
            leaves=Material("Royal grove foliage",new Color(.20f,.34f,.17f),0,.83f);
            crystal=Material("Teal crystal",new Color(.16f,.69f,.66f),.3f,.21f);
            crystal.EnableKeyword("_EMISSION");crystal.SetColor("_EmissionColor",new Color(.10f,.37f,.34f));
            cloth=Material("Royal blue banners",new Color(.045f,.12f,.30f),0,.79f);
            var normal=Resources.Load<Texture2D>("Eternal/Floor/stone_1024_normal");
            if(normal!=null){stone.SetTexture("_BumpMap",normal);stone.EnableKeyword("_NORMALMAP");stone.SetFloat("_BumpScale",.28f);}
            Plaza();Architecture();Vegetation();
            foreach(var entry in surfaces)entry.Value.Upload(transform,entry.Key,ownedMeshes);
        }
        Material Material(string name,Color color,float metallic,float roughness)
        {
            var shader=Shader.Find("Universal Render Pipeline/Lit");
            if(shader==null)throw new InvalidOperationException("URP Lit is required for the royal grove.");
            var material=new Material(shader){name=name};material.SetColor("_BaseColor",color);
            material.SetFloat("_Metallic",metallic);material.SetFloat("_Smoothness",1-roughness);
            ownedMaterials.Add(material);surfaces[material]=new Surface();return material;
        }
        void Plaza()
        {
            Block(new Vector3(0,-.38f,0),new Vector3(66,.60f,42),dark);
            // The playable rectangle remains -23..23 by -13..13 at y=0.
            // Edge architecture starts beyond it, leaving all incoming lanes open.
            for(int z=-10;z<=9;z++)for(int x=-16;x<=15;x++)
            {
                float width=2.025f,depth=2.025f;var center=new Vector3((x+.5f)*2.05f,-.055f,(z+.5f)*2.05f);
                BeveledSlab(center,width,.11f,depth,.045f,(x+z*3)%7==0?edge:stone);
                if((x*17+z*7)%13==0)Quad(new Vector3(center.x-.35f,.008f,center.z-depth*.48f),new Vector3(center.x+.7f,.008f,center.z-depth*.48f),new Vector3(center.x+.55f,.008f,center.z-depth*.44f),new Vector3(center.x-.5f,.008f,center.z-depth*.44f),moss);
            }
            Ring(Vector3.zero,5.7f,5.78f,.016f,bronze,128);
            Ring(Vector3.zero,6.3f,6.42f,.017f,bronze,128);
            Ring(Vector3.zero,7.1f,7.25f,.012f,edge,128);
            Ring(Vector3.zero,1.15f,1.23f,.017f,bronze,64);
            for(int i=0;i<12;i++)
            {
                float a=i*Mathf.PI/6;var direction=new Vector3(Mathf.Sin(a),0,Mathf.Cos(a));
                var side=new Vector3(direction.z,0,-direction.x);var center=direction*6.03f+Vector3.up*.022f;
                Quad(center-direction*.20f,center+side*.11f,center+direction*.20f,center-side*.11f,bronze);
                var path=direction*17;Ribbon(direction*7.35f,path,.035f,.012f,bronze);
            }
            for(int i=0;i<8;i++)
            {
                float a=i*Mathf.PI/4;var dir=new Vector3(Mathf.Sin(a),0,Mathf.Cos(a));
                Ribbon(dir*.4f,dir*4.9f,.035f,.02f,bronze);
                var side=new Vector3(dir.z,0,-dir.x);var p=dir*4.3f+Vector3.up*.022f;
                Quad(p-dir*.35f,p+side*.24f,p+dir*.55f,p-side*.24f,bronze);
            }
        }
        void Architecture()
        {
            // Four wide entry openings are geometry gaps, not painted paths.
            foreach(int sign in new[]{-1,1})
            {
                for(int x=-28;x<=28;x+=4)
                {
                    if(Mathf.Abs(x)<7)continue;var p=new Vector3(x,0,sign*16.7f);
                    Block(p+Vector3.up*.28f,new Vector3(3.8f,.56f,1.1f),dark);
                    BeveledSlab(p+Vector3.up*.60f,3.9f,.16f,1.2f,.065f,edge);
                    for(int k=-1;k<=1;k++)Column(p+new Vector3(k*1.08f,.70f,0),.16f,1.05f,8,stone);
                    BeveledSlab(p+Vector3.up*1.83f,4,.22f,1.35f,.065f,edge);
                }
                for(int z=-12;z<=12;z+=4)
                {
                    if(Mathf.Abs(z)<5)continue;var p=new Vector3(sign*27.8f,0,z);
                    Block(p+Vector3.up*.32f,new Vector3(1.25f,.64f,3.8f),dark);
                    BeveledSlab(p+Vector3.up*.72f,1.45f,.16f,3.9f,.065f,edge);
                    for(int k=-1;k<=1;k++)Column(p+new Vector3(0,.8f,k*1.08f),.16f,.98f,8,stone);
                    BeveledSlab(p+Vector3.up*1.86f,1.50f,.22f,4,.065f,edge);
                }
                for(int i=0;i<9;i++)BeveledSlab(new Vector3(sign*25.2f+sign*i*.46f,-.065f+(i+1)*.18f,0),.52f,.36f,7.7f,.035f,stone);
                Block(new Vector3(sign*32,1,0),new Vector3(4.6f,2,10),dark);
                BeveledSlab(new Vector3(sign*32,2.08f,0),4.7f,.18f,10.2f,.06f,edge);
            }
            for(int i=0;i<10;i++)BeveledSlab(new Vector3(0,-.065f+(i+1)*.16f,15.1f+i*.49f),8.3f,.32f,.55f,.035f,stone);
            Block(new Vector3(0,.78f,23),new Vector3(16,1.56f,8),dark);
            BeveledSlab(new Vector3(0,1.66f,23),16.1f,.20f,8.1f,.06f,edge);
            foreach(var p in new[]{new Vector3(-8,0,16),new Vector3(8,0,16),new Vector3(-27,0,-7),new Vector3(27,0,-7),new Vector3(-27,0,7),new Vector3(27,0,7)})
            {
                Pillar(p);Banner(p+new Vector3(.7f,5.9f,0));CrystalCluster(p+new Vector3(1.15f,.4f,-1.05f),.7f);
            }
            foreach(int sign in new[]{-1,1})
            {
                Pillar(new Vector3(sign*5.7f,1.75f,24));
                Arch(new Vector3(0,7.7f,24),6.05f,.6f,.8f,Mathf.PI*.06f,Mathf.PI*.94f,24);
                for(int i=0;i<4;i++)CrystalCluster(new Vector3(sign*(12+i*4),.55f,20+i%2*2),1.2f+i*.22f);
            }
        }
        void Pillar(Vector3 p)
        {
            BeveledSlab(p+Vector3.up*.28f,1.9f,.56f,1.9f,.1f,edge);
            BeveledSlab(p+Vector3.up*.67f,1.5f,.24f,1.5f,.08f,stone);
            Column(p+Vector3.up*.82f,.55f,5.3f,12,stone);
            for(int i=0;i<12;i++)
            {
                float a=i*Mathf.PI/6;var n=new Vector3(Mathf.Sin(a),0,Mathf.Cos(a));
                Tube(new[]{p+n*.54f+Vector3.up*1.12f,p+n*.54f+Vector3.up*5.72f},new[]{.028f,.028f},8,edge);
            }
            BeveledSlab(p+Vector3.up*6.16f,1.65f,.30f,1.65f,.1f,edge);
            BeveledSlab(p+Vector3.up*6.43f,1.9f,.24f,1.9f,.08f,stone);
            Column(p+Vector3.up*6.56f,.6f,.30f,12,bronze);
            Crystal(p+Vector3.up*6.88f,.34f,1.1f);
        }
        void Arch(Vector3 center,float radius,float width,float depth,float begin,float end,int count)
        {
            for(int i=0;i<count;i++)
            {
                float a=Mathf.Lerp(begin,end,i/(float)count),b=Mathf.Lerp(begin,end,(i+1)/(float)count);
                Vector3 At(float t,float r,float z)=>center+new Vector3(Mathf.Cos(t)*r,Mathf.Sin(t)*r,z);
                var f0=At(a,radius,-depth/2);var f1=At(b,radius,-depth/2);var f2=At(b,radius+width,-depth/2);var f3=At(a,radius+width,-depth/2);
                Quad(f0,f1,f2,f3,i%3==0?edge:stone);Quad(f3+Vector3.forward*depth,f2+Vector3.forward*depth,f1+Vector3.forward*depth,f0+Vector3.forward*depth,stone);
                Quad(f0,f0+Vector3.forward*depth,f1+Vector3.forward*depth,f1,dark);
                Quad(f2,f2+Vector3.forward*depth,f3+Vector3.forward*depth,f3,edge);
            }
        }
        void Banner(Vector3 top)
        {
            Tube(new[]{top-new Vector3(.6f,0,0),top+new Vector3(.6f,0,0)},new[]{.045f,.045f},8,bronze);
            const int rows=12,columns=5;
            Vector3 At(int x,int y)=>top+new Vector3((x/(float)columns-.5f)*1.1f,-y/(float)rows*3.3f,Mathf.Sin(y*.48f+x*.30f)*.12f);
            for(int y=0;y<rows;y++)for(int x=0;x<columns;x++)
            {
                var a=At(x,y);var b=At(x+1,y);var c=At(x+1,y+1);var d=At(x,y+1);
                Quad(a,b,c,d,cloth);Quad(d,c,b,a,cloth);
            }
            for(int y=0;y<rows;y++){Ribbon(At(0,y),At(0,y+1),.025f,0,bronze);Ribbon(At(columns,y),At(columns,y+1),.025f,0,bronze);}
        }
        void Vegetation()
        {
            var rng=new System.Random(10010);
            for(int i=0;i<22;i++)
            {
                float sign=i%2==0?-1:1;var p=new Vector3(sign*(31.7f+(i%3)*2.5f),0,-18+(i/2)*4.3f);
                var peak=p+new Vector3(sign*.5f,7.5f+(i%4)*.8f,.4f);
                Tube(new[]{p,p+new Vector3(.2f,2.7f,-.1f),peak},new[]{.75f,.42f,.15f},10,bark);
                for(int j=0;j<5;j++)
                {
                    float a=j*1.256f+i;var tip=peak+new Vector3(Mathf.Cos(a)*3,-1.5f+(j%3)*.5f,Mathf.Sin(a)*2.4f);
                    Tube(new[]{p+Vector3.up*4,tip},new[]{.22f,.055f},8,bark);
                    Canopy(tip+Vector3.up*.65f,2.4f,j+i,leaves);
                }
            }
            for(int i=0;i<210;i++)
            {
                float x=(float)rng.NextDouble()*64-32,z=(float)rng.NextDouble()*40-20;
                if(Mathf.Abs(x)<24&&Mathf.Abs(z)<14)continue;
                var p=new Vector3(x,.05f,z);float height=.15f+(float)rng.NextDouble()*.28f;
                for(int j=0;j<3;j++)
                {
                    float a=j*Mathf.PI/3;var side=new Vector3(Mathf.Cos(a)*.11f,0,Mathf.Sin(a)*.11f);
                    Triangle(p-side,p+side,p+Vector3.up*height,moss);Triangle(p+side,p-side,p+Vector3.up*height,moss);
                }
            }
        }
        void Canopy(Vector3 p,float radius,int seed,Material material)
        {
            // Faceted curved canopy surfaces, not camera-facing foliage cards.
            const int segments=12,rings=6;
            for(int r=0;r<rings;r++)for(int i=0;i<segments;i++)
            {
                Vector3 At(int ring,int segment)
                {
                    float v=ring/(float)rings*Mathf.PI,a=segment/(float)segments*Mathf.PI*2;
                    float noise=1+.12f*Mathf.Sin(segment*2.3f+ring+seed);
                    return p+new Vector3(Mathf.Cos(a)*Mathf.Sin(v)*radius*noise,Mathf.Cos(v)*radius*.5f,Mathf.Sin(a)*Mathf.Sin(v)*radius*noise);
                }
                Quad(At(r,i),At(r,i+1),At(r+1,i+1),At(r+1,i),material);
            }
        }
        void CrystalCluster(Vector3 p,float scale)
        {
            BeveledSlab(p-Vector3.up*.08f,1.4f*scale,.2f,1.4f*scale,.08f,dark);
            for(int i=0;i<5;i++){float a=i*2.399963f;Crystal(p+new Vector3(Mathf.Cos(a)*.43f,0,Mathf.Sin(a)*.43f)*scale,(.20f+i%2*.06f)*scale,(1.2f+i%3*.45f)*scale);}
        }
        void Crystal(Vector3 p,float radius,float height)
        {
            const int n=6;var tip=p+Vector3.up*height;
            for(int i=0;i<n;i++)
            {
                float a=i*Mathf.PI*2/n,b=(i+1)*Mathf.PI*2/n;
                var u=p+new Vector3(Mathf.Cos(a)*radius,0,Mathf.Sin(a)*radius);var v=p+new Vector3(Mathf.Cos(b)*radius,0,Mathf.Sin(b)*radius);
                var upper=Vector3.up*height*.63f;Quad(u,u+upper,v+upper,v,crystal);Triangle(u+upper,tip,v+upper,crystal);
            }
        }
        void Column(Vector3 p,float radius,float height,int sides,Material material)=>Tube(new[]{p,p+Vector3.up*height},new[]{radius,radius},sides,material);
        void Tube(Vector3[] points,float[] radii,int sides,Material material)
        {
            for(int row=0;row<points.Length-1;row++)
            {
                var up=(points[row+1]-points[row]).normalized;var right=Vector3.Cross(up,Mathf.Abs(up.y)>.9f?Vector3.forward:Vector3.up).normalized;var forward=Vector3.Cross(right,up);
                for(int i=0;i<sides;i++)
                {
                    Vector3 Offset(int index,float radius){float a=index*Mathf.PI*2/sides;return (right*Mathf.Cos(a)+forward*Mathf.Sin(a))*radius;}
                    Quad(points[row]+Offset(i,radii[row]),points[row]+Offset(i+1,radii[row]),points[row+1]+Offset(i+1,radii[row+1]),points[row+1]+Offset(i,radii[row+1]),material);
                }
            }
        }
        void BeveledSlab(Vector3 p,float width,float height,float depth,float bevel,Material material)
        {
            float x=width/2,z=depth/2,y=height/2;
            var lower=new[]{p+new Vector3(-x,-y,-z),p+new Vector3(x,-y,-z),p+new Vector3(x,-y,z),p+new Vector3(-x,-y,z)};
            var outer=new[]{p+new Vector3(-x,y-bevel,-z),p+new Vector3(x,y-bevel,-z),p+new Vector3(x,y-bevel,z),p+new Vector3(-x,y-bevel,z)};
            var upper=new[]{p+new Vector3(-x+bevel,y,-z+bevel),p+new Vector3(x-bevel,y,-z+bevel),p+new Vector3(x-bevel,y,z-bevel),p+new Vector3(-x+bevel,y,z-bevel)};
            Quad(upper[3],upper[2],upper[1],upper[0],material);
            for(int i=0;i<4;i++){int j=(i+1)%4;Quad(lower[i],outer[i],outer[j],lower[j],material);Quad(outer[i],upper[i],upper[j],outer[j],edge);}
        }
        void Block(Vector3 p,Vector3 size,Material material)
        {
            var v=new Vector3[8];for(int i=0;i<8;i++)v[i]=p+Vector3.Scale(size*.5f,new Vector3((i&1)==0?-1:1,(i&2)==0?-1:1,(i&4)==0?-1:1));
            Quad(v[0],v[2],v[3],v[1],material);Quad(v[5],v[7],v[6],v[4],material);
            Quad(v[4],v[6],v[2],v[0],material);Quad(v[1],v[3],v[7],v[5],material);
            Quad(v[2],v[6],v[7],v[3],material);Quad(v[0],v[1],v[5],v[4],material);
        }
        void Ring(Vector3 p,float inner,float outer,float y,Material material,int count)
        {
            for(int i=0;i<count;i++)
            {
                float a=i*Mathf.PI*2/count,b=(i+1)*Mathf.PI*2/count;
                Vector3 At(float t,float r)=>p+new Vector3(Mathf.Sin(t)*r,y,Mathf.Cos(t)*r);
                Quad(At(a,inner),At(a,outer),At(b,outer),At(b,inner),material);
            }
        }
        void Ribbon(Vector3 a,Vector3 b,float width,float y,Material material)
        {
            var side=Vector3.Cross(b-a,Vector3.up).normalized*width;var offset=Vector3.up*y;
            Quad(a-side+offset,b-side+offset,b+side+offset,a+side+offset,material);
        }
        void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Material material)=>surfaces[material].Quad(a,b,c,d);
        void Triangle(Vector3 a,Vector3 b,Vector3 c,Material material)=>surfaces[material].Triangle(a,b,c);
        void OnDestroy(){foreach(var mesh in ownedMeshes)if(mesh!=null)Destroy(mesh);foreach(var material in ownedMaterials)if(material!=null)Destroy(material);}
        sealed class Surface
        {
            readonly List<Vector3> positions=new();readonly List<int> indices=new();readonly List<Vector2> uv=new();
            public void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d)
            {
                int n=positions.Count;positions.AddRange(new[]{a,b,c,d});
                uv.AddRange(new[]{new Vector2(a.x,a.z),new Vector2(b.x,b.z),new Vector2(c.x,c.z),new Vector2(d.x,d.z)});
                indices.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});
            }
            public void Triangle(Vector3 a,Vector3 b,Vector3 c)
            {
                int n=positions.Count;positions.AddRange(new[]{a,b,c});uv.AddRange(new[]{Vector2.zero,Vector2.right,Vector2.up});indices.AddRange(new[]{n,n+1,n+2});
            }
            public void Upload(Transform parent,Material material,List<Mesh> owned)
            {
                var mesh=new Mesh{name=material.name+" volume geometry",indexFormat=IndexFormat.UInt32};
                mesh.SetVertices(positions);mesh.SetUVs(0,uv);mesh.SetTriangles(indices,0);mesh.RecalculateNormals();mesh.RecalculateBounds();owned.Add(mesh);
                var go=new GameObject(material.name);go.transform.SetParent(parent,false);go.AddComponent<MeshFilter>().sharedMesh=mesh;
                var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;renderer.shadowCastingMode=ShadowCastingMode.On;renderer.receiveShadows=true;
            }
        }
    }
}
