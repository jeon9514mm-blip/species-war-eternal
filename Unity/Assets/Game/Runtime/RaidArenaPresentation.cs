using System.Collections.Generic;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Dedicated map roots and bounded warning meshes. Never owns damage state.
    public sealed class RaidArenaPresentation : MonoBehaviour
    {
        readonly List<Material> ownedMaterials=new();
        readonly List<LineRenderer> warningLines=new();
        RaidSimulation raid;
        Material warningMaterial,outlineMaterial;
        Mesh warningMesh;
        MeshRenderer warningRenderer;
        int shownVersion=-1;
        public string PaintedMap {get;private set;}
        public void Initialize(RaidSimulation simulation,Material stone)
        {
            raid=simulation;bool meadow=raid.Zone=="gray_meadow",mine=raid.Zone=="forgotten_mine";
            string painting=meadow?"sky-court":mine?"amber-quarry":"lunar-sanctum";
            var art=Resources.Load<Texture2D>("Eternal/Environment/"+painting);
            if(art!=null)
            {
                var material=new Material(Resources.Load<Material>("Eternal/Materials/PaintedArena"));
                material.SetTexture("_MainTex",art);ownedMaterials.Add(material);PaintedMap=painting;
                Primitive(PrimitiveType.Plane,"Original painted raid floor · "+painting,new Vector3(0,-.08f,0),new Vector3(6,1,4),material);
            }
            else
            {
            var ground=new Material(stone);ownedMaterials.Add(ground);
            var stoneTint=meadow?new Color(.49f,.53f,.43f):mine?new Color(.35f,.37f,.42f):new Color(.37f,.40f,.49f);
            if(ground.HasProperty("_Tint"))ground.SetColor("_Tint",meadow?new Color(1.08f,1.10f,.91f):mine?new Color(.86f,.94f,1.06f):new Color(.88f,.88f,1.12f));
            Primitive(PrimitiveType.Cube,"Raised regional arena",new Vector3(0,-.28f,0),new Vector3(25,.45f,9.1f),ground);
            var lit=Shader.Find("Universal Render Pipeline/Lit");
            Material Surface(Color color,float metallic=.3f)
            {var m=new Material(lit);m.SetColor("_BaseColor",color);m.SetFloat("_Metallic",metallic);m.SetFloat("_Smoothness",.42f);ownedMaterials.Add(m);return m;}
            var stoneTrim=Surface(stoneTint*.65f);var bronze=Surface(new Color(.38f,.29f,.18f),.65f);
            var accent=Surface(meadow?new Color(.43f,.58f,.37f):mine?new Color(.42f,.66f,.75f):new Color(.6f,.47f,.76f));
            for(int side=-1;side<=1;side+=2)
            {
                Primitive(PrimitiveType.Cube,"Carved perimeter",new Vector3(0,-.01f,side*4.52f),new Vector3(25.4f,.22f,.28f),bronze);
                Primitive(PrimitiveType.Cube,"Outer stone lip",new Vector3(side*12.5f,-.01f,0),new Vector3(.24f,.22f,9.3f),bronze);
            }
            for(int i=0;i<7;i++)
            {
                float x=-12+i*4;
                foreach(float z in new[]{-5.6f,5.6f})
                {
                    Primitive(PrimitiveType.Cube,"Temple column footing",new Vector3(x,.16f,z),new Vector3(.9f,.4f,.9f),stoneTrim);
                    Primitive(PrimitiveType.Cylinder,"Regional columns",new Vector3(x,1.0f,z),new Vector3(.48f,meadow?.75f:mine?.6f:.9f,.48f),stoneTrim);
                    Primitive(PrimitiveType.Cube,"Column bronze capital",new Vector3(x,meadow?1.76f:mine?1.46f:2.06f,z),new Vector3(.72f,.22f,.72f),bronze);
                    if(mine)
                    {
                        for(int j=0;j<3;j++){var crystal=Primitive(PrimitiveType.Cube,"Mine crystal",new Vector3(x+(j-1)*.22f,.3f+j*.15f,z-.4f),new Vector3(.17f,.7f+j*.18f,.17f),accent);crystal.transform.rotation=Quaternion.Euler(10+j*12,45,j*15);}
                    }
                    else if(meadow)
                    {
                        var moss=Primitive(PrimitiveType.Sphere,"Moss on ruined stone",new Vector3(x-.2f,.26f,z+.34f),new Vector3(.65f,.18f,.42f),accent);moss.transform.rotation=Quaternion.Euler(0,i*34,0);
                    }
                    else
                    {
                        var moon=Primitive(PrimitiveType.Sphere,"Moon shrine ornament",new Vector3(x,2.5f,z),new Vector3(.5f,.5f,.13f),accent);moon.transform.rotation=Quaternion.Euler(45,0,0);
                    }
                }
            }
            for(int i=0;i<3;i++)Primitive(PrimitiveType.Cube,"Entry stairs",new Vector3(-13.1f-i*.45f,-.15f-i*.12f,0),new Vector3(.65f,.3f,4.4f+i*.7f),stoneTrim);
            if(mine)for(int i=0;i<2;i++)Primitive(PrimitiveType.Cylinder,"Mining bronze conduit",new Vector3(0,.1f,(i==0?-1:1)*5.2f),new Vector3(.15f,12.2f,.15f),bronze).transform.rotation=Quaternion.Euler(0,0,90);
            if(!meadow&&!mine)
            {
                Primitive(PrimitiveType.Cylinder,"Moon altar",new Vector3(8,-.035f,.5f),new Vector3(5,.16f,5),stoneTrim);
                var ring=new GameObject("Moon altar inlay").AddComponent<LineRenderer>();ring.transform.SetParent(transform,false);ring.sharedMaterial=accent;ring.useWorldSpace=false;ring.loop=true;ring.widthMultiplier=.035f;ring.positionCount=96;
                for(int i=0;i<96;i++){float a=i*Mathf.PI*2/96;ring.SetPosition(i,new Vector3(8+Mathf.Cos(a)*2.4f,.14f,.5f+Mathf.Sin(a)*2.4f));}
            }
            }
            warningMaterial=new Material(Resources.Load<Material>("Eternal/Materials/Particles"));warningMaterial.SetFloat("_SoftDot",0);ownedMaterials.Add(warningMaterial);
            warningMaterial.SetFloat("_ClipArena",1);warningMaterial.SetVector("_ArenaBounds",new Vector4(RaidFootprint.Floor.xMin,RaidFootprint.Floor.yMin,RaidFootprint.Floor.xMax,RaidFootprint.Floor.yMax));warningMaterial.renderQueue=2990;
            outlineMaterial=new Material(warningMaterial);outlineMaterial.renderQueue=2991;ownedMaterials.Add(outlineMaterial);
            var warning=new GameObject("Shared geometry warning fill");warning.transform.SetParent(transform,false);
            warningMesh=new Mesh{name="Frozen raid warning"};warning.AddComponent<MeshFilter>().sharedMesh=warningMesh;warningRenderer=warning.AddComponent<MeshRenderer>();warningRenderer.sharedMaterial=warningMaterial;
            for(int i=0;i<4;i++){var line=new GameObject("Warning footprint "+i).AddComponent<LineRenderer>();line.transform.SetParent(transform,false);line.sharedMaterial=outlineMaterial;line.loop=true;line.useWorldSpace=false;line.widthMultiplier=.065f;warningLines.Add(line);}
        }
        GameObject Primitive(PrimitiveType type,string name,Vector3 position,Vector3 scale,Material material)
        {var go=GameObject.CreatePrimitive(type);go.name=name;go.transform.SetParent(transform,false);go.transform.localPosition=position;go.transform.localScale=scale;go.GetComponent<Renderer>().sharedMaterial=material;Destroy(go.GetComponent<Collider>());return go;}
        void LateUpdate()
        {
            if(raid==null)return;
            var shape=raid.SecondWarning??raid.Warning;
            if(shownVersion!=raid.WarningVersion){shownVersion=raid.WarningVersion;RebuildWarning(shape);}
            var color=raid.CounterReady?new Color(.28f,.69f,1,.7f):new Color(1,.24f,.28f,.6f);
            outlineMaterial.SetColor("_Tint",color);color.a=shape==null?0:.13f+Mathf.Sin(Time.unscaledTime*7)*.035f;warningMaterial.SetColor("_Tint",color);
        }
        void RebuildWarning(RaidFootprint shape)
        {
            foreach(var line in warningLines)line.gameObject.SetActive(false);warningMesh.Clear();warningRenderer.enabled=shape!=null;if(shape==null)return;
            int index=0;foreach(var outline in shape.Outlines())
            {
                if(index>=warningLines.Count)break;var line=warningLines[index++];line.gameObject.SetActive(true);line.positionCount=outline.Length;
                for(int i=0;i<outline.Length;i++)line.SetPosition(i,new Vector3(outline[i].x,.18f,outline[i].y));
            }
            // One bounded grid is rebuilt only when a cast changes. Sampling the
            // authoritative shape also keeps a donut's inner safe region open.
            var vertices=new List<Vector3>();var colors=new List<Color>();var triangles=new List<int>();var uv=new List<Vector2>();const float cell=.30f;
            for(float x=RaidFootprint.Floor.xMin;x<RaidFootprint.Floor.xMax;x+=cell)for(float z=RaidFootprint.Floor.yMin;z<RaidFootprint.Floor.yMax;z+=cell)
            {
                if(!shape.Contains(new Vector2(x+cell*.5f,z+cell*.5f)))continue;int v=vertices.Count;
                float right=Mathf.Min(x+cell,RaidFootprint.Floor.xMax),top=Mathf.Min(z+cell,RaidFootprint.Floor.yMax);
                vertices.Add(new Vector3(x,.17f,z));vertices.Add(new Vector3(x,.17f,top));vertices.Add(new Vector3(right,.17f,top));vertices.Add(new Vector3(right,.17f,z));
                colors.AddRange(new[]{Color.white,Color.white,Color.white,Color.white});uv.AddRange(new[]{Vector2.zero,Vector2.up,Vector2.one,Vector2.right});triangles.AddRange(new[]{v,v+1,v+2,v,v+2,v+3});
            }
            warningMesh.SetVertices(vertices);warningMesh.SetColors(colors);warningMesh.SetUVs(0,uv);warningMesh.SetTriangles(triangles,0);warningMesh.RecalculateBounds();
        }
        void OnDestroy(){if(warningMesh!=null)Destroy(warningMesh);foreach(var material in ownedMaterials)if(material!=null)Destroy(material);}
    }
}
