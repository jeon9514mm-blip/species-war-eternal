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
        readonly List<Texture2D> ownedTextures=new();
        readonly Dictionary<Material,Surface> surfaces=new();
        Material stone,stoneCool,stoneWarm,edge,dark,bronze,moss,bark,leaves,leafLight,leafDeep,crystal,cloth;
        bool built;
        public void Build()
        {
            if(built)return;built=true;
            stone=Material("Grove limestone",new Color(.62f,.62f,.53f),0,.82f);
            stoneCool=Material("Cool limestone",new Color(.55f,.59f,.54f),0,.84f);
            stoneWarm=Material("Warm limestone",new Color(.64f,.60f,.50f),0,.81f);
            edge=Material("Worn limestone edges",new Color(.73f,.71f,.62f),0,.72f);
            dark=Material("Recessed stone",new Color(.27f,.31f,.29f),0,.92f);
            bronze=Material("Aurelia bronze inlay",new Color(.56f,.39f,.18f),.75f,.35f);
            moss=Material("Moss seams",new Color(.21f,.32f,.16f),0,.95f);
            bark=Material("Old oak bark",new Color(.22f,.17f,.12f),0,.9f);
            leaves=Material("Royal grove foliage",new Color(.20f,.34f,.17f),0,.83f);
            leafLight=Material("Sunlit oak leaves",new Color(.37f,.48f,.22f),0,.81f);
            leafDeep=Material("Deep oak leaves",new Color(.13f,.25f,.19f),0,.9f);
            crystal=Material("Teal crystal",new Color(.16f,.69f,.66f),.3f,.21f);
            crystal.EnableKeyword("_EMISSION");crystal.SetColor("_EmissionColor",new Color(.10f,.37f,.34f));
            cloth=Material("Royal blue banners",new Color(.045f,.12f,.30f),0,.79f);
            LimestoneGrain();
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
        void LimestoneGrain()
        {
            // A quiet, tileable material detail, not a map painting. The slab
            // joins and worn bevels are real geometry, independent of this grain.
            const int size=128;var height=new float[size*size];var color=new Color[size*size];var normals=new Color[size*size];
            float Noise(float x,float y,float frequency)
            {
                float u=x/size,v=y/size;
                return Mathf.Lerp(Mathf.Lerp(Mathf.PerlinNoise(u*frequency,v*frequency),Mathf.PerlinNoise((u-1)*frequency,v*frequency),u),
                    Mathf.Lerp(Mathf.PerlinNoise(u*frequency,(v-1)*frequency),Mathf.PerlinNoise((u-1)*frequency,(v-1)*frequency),u),v);
            }
            for(int y=0;y<size;y++)for(int x=0;x<size;x++)
            {
                float grain=Noise(x,y,11)*.55f+Noise(x,y,38)*.3f+Noise(x,y,79)*.15f;
                height[y*size+x]=grain;float tone=.87f+(grain-.5f)*.17f;color[y*size+x]=new Color(tone,tone,tone,1);
            }
            for(int y=0;y<size;y++)for(int x=0;x<size;x++)
            {
                float dx=height[y*size+(x+1)%size]-height[y*size+(x+size-1)%size];
                float dy=height[((y+1)%size)*size+x]-height[((y+size-1)%size)*size+x];
                var n=new Vector3(-dx*1.5f,-dy*1.5f,1).normalized;normals[y*size+x]=new Color(n.x*.5f+.5f,n.y*.5f+.5f,n.z*.5f+.5f,1);
            }
            Texture2D Texture(string name,Color[] pixels,bool linear)
            {var texture=new Texture2D(size,size,TextureFormat.RGBA32,true,linear){name=name,wrapMode=TextureWrapMode.Repeat,filterMode=FilterMode.Trilinear,anisoLevel=2};texture.SetPixels(pixels);texture.Apply(true,true);ownedTextures.Add(texture);return texture;}
            var albedo=Texture("Quiet limestone mineral grain",color,false);var normal=Texture("Limestone mineral normal",normals,true);
            foreach(var material in new[]{stone,stoneCool,stoneWarm,edge})
            {material.SetTexture("_BaseMap",albedo);material.SetTexture("_BumpMap",normal);material.EnableKeyword("_NORMALMAP");material.SetFloat("_BumpScale",.24f);}
        }
        void Plaza()
        {
            Block(new Vector3(0,-.38f,0),new Vector3(66,.60f,42),dark);
            // The playable rectangle remains -23..23 by -13..13 at y=0.
            // Edge architecture starts beyond it, leaving all incoming lanes open.
            for(int z=-10;z<=9;z++)for(int x=-16;x<=15;x++)
            {
                float width=2.025f,depth=2.025f;var center=new Vector3((x+.5f)*2.05f,-.055f,(z+.5f)*2.05f);
                int variant=Math.Abs(x*73+z*19);var material=variant%8==0?stoneWarm:variant%5==0?stoneCool:stone;
                BeveledSlab(center,width,.11f,depth,.024f+variant%5*.005f,material);
                // Sparse joint-only islands keep the combat floor visually calm.
                if(variant%5==0)MossJoint(center+new Vector3(0,.061f,-1.015f),variant);
                if(variant%11==0)MossJoint(center+new Vector3(-1.015f,.061f,0),variant+1,true);
                if(variant%17==0)
                {
                    var a=new Vector3(center.x-.88f,.007f,center.z-.89f);var b=a+new Vector3(.22f,0,.12f);
                    Ribbon(a,b,.006f,0,dark);Ribbon(b,b+new Vector3(.13f,0,.23f),.004f,0,dark);
                }
            }
            Ring(Vector3.zero,5.7f,5.78f,.016f,bronze,128);
            Ring(Vector3.zero,6.3f,6.42f,.017f,bronze,128);
            Ring(Vector3.zero,7.1f,7.25f,.012f,edge,128);
            Ring(Vector3.zero,1.15f,1.23f,.017f,bronze,64);
            for(int i=0;i<12;i++)
            {
                float a=i*Mathf.PI/6;var direction=new Vector3(Mathf.Sin(a),0,Mathf.Cos(a));
                var side=new Vector3(direction.z,0,-direction.x);var center=direction*6.03f+Vector3.up*.022f;
                GroundQuad(center-direction*.20f,center+side*.11f,center+direction*.20f,center-side*.11f,bronze);
                var path=direction*17;Ribbon(direction*7.35f,path,.035f,.012f,bronze);
            }
            for(int i=0;i<8;i++)
            {
                float a=i*Mathf.PI/4;var dir=new Vector3(Mathf.Sin(a),0,Mathf.Cos(a));
                Ribbon(dir*.4f,dir*4.9f,.035f,.02f,bronze);
                var side=new Vector3(dir.z,0,-dir.x);var p=dir*4.3f+Vector3.up*.022f;
                GroundQuad(p-dir*.35f,p+side*.24f,p+dir*.55f,p-side*.24f,bronze);
            }
        }
        void MossJoint(Vector3 center,int seed,bool vertical=false)
        {
            for(int i=0;i<5;i++)
            {
                float along=-.75f+i*.28f,width=.016f+Mathf.Abs(Mathf.Sin(seed+i*7))*.052f;
                var dir=vertical?Vector3.forward:Vector3.right;var side=vertical?Vector3.right:Vector3.forward;
                var p=center+dir*along;float length=.07f+Mathf.Abs(Mathf.Sin(seed+i*13))*.08f;
                GroundQuad(p-dir*length-side*width*.6f,p+dir*length-side*width,p+dir*length*.8f+side*width,p-dir*length*.7f+side*width*.4f,moss);
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
            Column(p+Vector3.up*1.04f,.572f,.07f,12,bronze);
            Column(p+Vector3.up*5.82f,.572f,.09f,12,bronze);
            Crest(p+new Vector3(0,4.4f,-.565f),.42f);
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
                if(i==0)Quad(f3,f3+Vector3.forward*depth,f0+Vector3.forward*depth,f0,stone);
                if(i==count-1)Quad(f1,f1+Vector3.forward*depth,f2+Vector3.forward*depth,f2,stone);
            }
        }
        void Banner(Vector3 top)
        {
            Tube(new[]{top-new Vector3(.6f,0,0),top+new Vector3(.6f,0,0)},new[]{.045f,.045f},8,bronze);
            const int rows=12,columns=5;
            Vector3 At(int x,int y)=>top+new Vector3((x/(float)columns-.5f)*1.1f,-y/(float)rows*3.3f+(y==rows?Mathf.Abs(x/(float)columns-.5f)*.42f:0),Mathf.Sin(y*.48f+x*.30f)*.12f);
            for(int y=0;y<rows;y++)for(int x=0;x<columns;x++)
            {
                var a=At(x,y);var b=At(x+1,y);var c=At(x+1,y+1);var d=At(x,y+1);
                Quad(a,b,c,d,cloth);Quad(d,c,b,a,cloth);
            }
            for(int y=0;y<rows;y++)
            {
                BannerStitch(At(0,y),At(0,y+1),.025f);BannerStitch(At(columns,y),At(columns,y+1),.025f);
            }
            for(int x=0;x<columns;x++)BannerStitch(At(x,rows),At(x+1,rows),.023f);
            Crest(top+new Vector3(0,-1.05f,-.145f),.33f);
            Tube(new[]{top+new Vector3(-.58f,-.05f,0),top+new Vector3(-.58f,-.52f,0)},new[]{.027f,.012f},6,bronze);
            Tube(new[]{top+new Vector3(.58f,-.05f,0),top+new Vector3(.58f,-.52f,0)},new[]{.027f,.012f},6,bronze);
        }
        void BannerStitch(Vector3 a,Vector3 b,float width)
        {
            var side=Vector3.Cross(b-a,Vector3.forward).normalized*width;var face=new Vector3(0,0,-.012f);
            Quad(a-side+face,a+side+face,b+side+face,b-side+face,bronze);
            Quad(a-side-face,b-side-face,b+side-face,a+side-face,bronze);
        }
        void Crest(Vector3 p,float size)
        {
            // Raised eight-point Aurelia star and laurel, actual bronze volume.
            var center=p+Vector3.back*.03f;
            for(int i=0;i<8;i++)
            {
                float a=i*Mathf.PI/4,b=(i+.5f)*Mathf.PI/4,c=(i+1)*Mathf.PI/4;
                var u=p+new Vector3(Mathf.Sin(a)*size,Mathf.Cos(a)*size,0);
                var v=p+new Vector3(Mathf.Sin(b)*size*.32f,Mathf.Cos(b)*size*.32f,0);
                var w=p+new Vector3(Mathf.Sin(c)*size,Mathf.Cos(c)*size,0);
                Triangle(center,u,v,bronze);Triangle(center,v,w,bronze);
            }
            for(int sign=-1;sign<=1;sign+=2)for(int i=0;i<5;i++)
            {
                float angle=(-65+i*27)*Mathf.Deg2Rad;var at=p+new Vector3(sign*Mathf.Cos(angle)*size*.91f,Mathf.Sin(angle)*size*.91f,-.016f);
                var tip=at+new Vector3(sign*size*.22f,size*.13f,-.01f);var side=new Vector3(-size*.055f,sign*size*.10f,0);
                Triangle(at-side,tip,at+side,bronze);Triangle(at+side,tip,at-side,bronze);
            }
        }
        void Vegetation()
        {
            var rng=new System.Random(10010);
            for(int i=0;i<22;i++)
            {
                float sign=i%2==0?-1:1;var p=new Vector3(sign*(31.7f+(i%3)*2.5f),0,-18+(i/2)*4.3f);
                Oak(p,7.5f+(i%4)*.8f,i);
            }
            for(int i=0;i<8;i++)Oak(new Vector3((i<4?-1:1)*(11+i%4*5.8f),0,28+i%3*2.8f),9.2f+i%3,40+i);
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
        void Oak(Vector3 p,float height,int seed)
        {
            var peak=p+new Vector3(Mathf.Sin(seed)*.65f,height,Mathf.Cos(seed)*.55f);
            var middle=p+new Vector3(.2f,height*.35f,-.1f);
            Tube(new[]{p,middle,Vector3.Lerp(middle,peak,.56f),peak},new[]{.72f,.42f,.24f,.035f},10,bark);
            for(int j=0;j<7;j++)
            {
                float a=j*2.399963f+seed;var outward=new Vector3(Mathf.Cos(a),0,Mathf.Sin(a));
                var joint=p+Vector3.up*(height*(.44f+j%3*.09f));
                var tip=peak+outward*(2.4f+j%2*.55f)-Vector3.up*(1.6f-j%3*.4f);
                var bend=Vector3.Lerp(joint,tip,.62f)+Vector3.up*.32f;
                Tube(new[]{joint,bend,tip},new[]{.22f,.10f,.024f},7,bark);
                for(int fork=0;fork<3;fork++)
                {
                    var side=new Vector3(-outward.z,0,outward.x)*(fork-1)*.95f;
                    var end=tip+outward*.6f+side+Vector3.up*(.15f+fork*.2f);
                    Tube(new[]{bend,Vector3.Lerp(tip,end,.3f),end},new[]{.064f,.030f,.006f},5,bark);
                    LeafBough(end,outward+side*.35f,seed*97+j*11+fork,1.0f+fork*.08f);
                }
            }
            LeafBough(peak,Vector3.forward,seed+701,1.35f);
            for(int root=0;root<6;root++)
            {
                float a=root*Mathf.PI/3+seed;var d=new Vector3(Mathf.Cos(a),0,Mathf.Sin(a));
                Tube(new[]{p+Vector3.up*.52f,p+d*.70f+Vector3.up*.16f,p+d*1.75f+Vector3.up*.04f},new[]{.22f,.20f,.028f},6,bark);
            }
        }
        void LeafBough(Vector3 p,Vector3 direction,int seed,float scale)
        {
            var rng=new System.Random(seed);var axis=direction.normalized;var side=Vector3.Cross(axis,Vector3.up).normalized;
            for(int i=0;i<22;i++)
            {
                float angle=(float)rng.NextDouble()*Mathf.PI*2,radius=Mathf.Sqrt((float)rng.NextDouble())*1.05f*scale;
                var offset=(axis*Mathf.Cos(angle)+side*Mathf.Sin(angle))*radius+Vector3.up*((float)rng.NextDouble()-.3f)*.7f;
                var tip=axis*.6f+side*Mathf.Sin(angle)*.7f+Vector3.up*(.25f+(float)rng.NextDouble()*.5f);
                var at=p+offset;var material=i%5==0?leafLight:i%4==0?leafDeep:leaves;
                FoldedLeaf(at,tip.normalized,(.45f+(float)rng.NextDouble()*.48f)*scale,.19f*scale,material);
            }
        }
        void FoldedLeaf(Vector3 p,Vector3 direction,float length,float width,Material material)
        {
            var side=Vector3.Cross(direction,Vector3.up).normalized;
            if(side.sqrMagnitude<.1f)side=Vector3.right;
            var tip=p+direction*length;var mid=p+direction*length*.46f;
            var left=mid+side*width;var right=mid-side*width;var ridge=mid+Vector3.up*length*.075f;
            void Both(Vector3 a,Vector3 b,Vector3 c){Triangle(a,b,c,material);Triangle(c,b,a,material);}
            Both(p,left,ridge);Both(p,ridge,right);Both(left,tip,ridge);Both(ridge,tip,right);
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
                Triangle(p,u,v,crystal);
            }
        }
        void Column(Vector3 p,float radius,float height,int sides,Material material)=>Tube(new[]{p,p+Vector3.up*height},new[]{radius,radius},sides,material);
        void Tube(Vector3[] points,float[] radii,int sides,Material material)
        {
            var right=new Vector3[points.Length];var forward=new Vector3[points.Length];
            for(int i=0;i<points.Length;i++)
            {
                var up=(points[Math.Min(i+1,points.Length-1)]-points[Math.Max(0,i-1)]).normalized;
                right[i]=Vector3.Cross(up,Mathf.Abs(up.y)>.9f?Vector3.forward:Vector3.up).normalized;forward[i]=Vector3.Cross(right[i],up);
            }
            Vector3 At(int row,int index){float angle=index*Mathf.PI*2/sides;return points[row]+(right[row]*Mathf.Cos(angle)+forward[row]*Mathf.Sin(angle))*radii[row];}
            for(int row=0;row<points.Length-1;row++)
            {
                for(int i=0;i<sides;i++)
                    Quad(At(row,i),At(row+1,i),At(row+1,i+1),At(row,i+1),material);
            }
            int end=points.Length-1;
            for(int i=0;i<sides;i++){Triangle(points[0],At(0,i),At(0,i+1),material);Triangle(points[end],At(end,i+1),At(end,i),material);}
        }
        void BeveledSlab(Vector3 p,float width,float height,float depth,float bevel,Material material)
        {
            float x=width/2,z=depth/2,y=height/2;
            var lower=new[]{p+new Vector3(-x,-y,-z),p+new Vector3(x,-y,-z),p+new Vector3(x,-y,z),p+new Vector3(-x,-y,z)};
            var outer=new[]{p+new Vector3(-x,y-bevel,-z),p+new Vector3(x,y-bevel,-z),p+new Vector3(x,y-bevel,z),p+new Vector3(-x,y-bevel,z)};
            var upper=new[]{p+new Vector3(-x+bevel,y,-z+bevel),p+new Vector3(x-bevel,y,-z+bevel),p+new Vector3(x-bevel,y,z-bevel),p+new Vector3(-x+bevel,y,z-bevel)};
            Quad(upper[3],upper[2],upper[1],upper[0],material);
            for(int i=0;i<4;i++){int j=(i+1)%4;Quad(lower[i],outer[i],outer[j],lower[j],material);Quad(outer[i],upper[i],upper[j],outer[j],edge);}
            Quad(lower[0],lower[1],lower[2],lower[3],material);
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
            GroundQuad(a-side+offset,b-side+offset,b+side+offset,a+side+offset,material);
        }
        void GroundQuad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Material material)
        {if(Vector3.Cross(b-a,c-a).y<0)Quad(a,d,c,b,material);else Quad(a,b,c,d,material);}
        void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Material material)=>surfaces[material].Quad(a,b,c,d);
        void Triangle(Vector3 a,Vector3 b,Vector3 c,Material material)=>surfaces[material].Triangle(a,b,c);
        void OnDestroy(){foreach(var mesh in ownedMeshes)if(mesh!=null)Destroy(mesh);foreach(var material in ownedMaterials)if(material!=null)Destroy(material);foreach(var texture in ownedTextures)if(texture!=null)Destroy(texture);}
        sealed class Surface
        {
            readonly List<Vector3> positions=new();readonly List<int> indices=new();readonly List<Vector2> uv=new();
            public void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d)
            {
                var normal=Vector3.Cross(b-a,c-a);
                if(normal.sqrMagnitude<.00000001f){Triangle(a,c,d);return;}
                if(Vector3.Cross(c-a,d-a).sqrMagnitude<.00000001f){Triangle(a,b,c);return;}
                int n=positions.Count;positions.AddRange(new[]{a,b,c,d});
                uv.AddRange(new[]{Project(a,normal),Project(b,normal),Project(c,normal),Project(d,normal)});
                indices.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});
            }
            public void Triangle(Vector3 a,Vector3 b,Vector3 c)
            {
                var normal=Vector3.Cross(b-a,c-a);if(normal.sqrMagnitude<.00000001f)return;
                int n=positions.Count;positions.AddRange(new[]{a,b,c});uv.AddRange(new[]{Project(a,normal),Project(b,normal),Project(c,normal)});indices.AddRange(new[]{n,n+1,n+2});
            }
            static Vector2 Project(Vector3 position,Vector3 normal)
            {
                // Dominant-face mapping gives upright columns and walls usable
                // texture area; projecting everything onto xz collapsed them.
                var n=new Vector3(Mathf.Abs(normal.x),Mathf.Abs(normal.y),Mathf.Abs(normal.z));
                return (n.y>=n.x&&n.y>=n.z?new Vector2(position.x,position.z):n.x>=n.z?new Vector2(position.z,position.y):new Vector2(position.x,position.y))*.4f;
            }
            public void Upload(Transform parent,Material material,List<Mesh> owned)
            {
                var mesh=new Mesh{name=material.name+" volume geometry",indexFormat=IndexFormat.UInt32};
                mesh.SetVertices(positions);mesh.SetUVs(0,uv);mesh.SetTriangles(indices,0);mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();owned.Add(mesh);
                var go=new GameObject(material.name);go.transform.SetParent(parent,false);go.AddComponent<MeshFilter>().sharedMesh=mesh;
                var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;renderer.shadowCastingMode=ShadowCastingMode.On;renderer.receiveShadows=true;
            }
        }
    }
}
