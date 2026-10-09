using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Eternal.UnityMigration
{
    // Six reusable visual nodes describe the aggregate raid mechanic. No collider,
    // gameplay target or Update-owned clock is created.
    public sealed class RaidMechanicPresentation : MonoBehaviour
    {
        readonly List<GameObject> nodes=new();
        readonly List<LineRenderer> rings=new(),links=new();
        readonly List<Material> materials=new();
        Mesh facet;
        RaidSimulation raid;
        Material bronze,crystal,lunar;
        public RaidMechanicView View {get;private set;}
        public int VisibleNodes {get;private set;}
        public void Bind(RaidSimulation simulation){raid=simulation;Sync();}
        public void Initialize(RaidSimulation simulation)
        {
            raid=simulation;facet=FacetedShard();
            Material Make(Color color)
            {var material=new Material(Resources.Load<Material>("Eternal/Materials/Particles"));material.SetFloat("_SoftDot",0);material.SetFloat("_ClipArena",1);material.SetVector("_ArenaBounds",new Vector4(RaidFootprint.Floor.xMin,RaidFootprint.Floor.yMin,RaidFootprint.Floor.xMax,RaidFootprint.Floor.yMax));material.SetColor("_Tint",color);material.renderQueue=2975;materials.Add(material);return material;}
            bronze=Make(new Color(.83f,.68f,.43f,.88f));crystal=Make(new Color(.46f,.80f,.82f,.90f));lunar=Make(new Color(.68f,.56f,.90f,.82f));
            for(int i=0;i<6;i++)
            {
                var node=new GameObject("Aggregate raid mechanic visual "+i);node.transform.SetParent(transform,false);node.AddComponent<MeshFilter>().sharedMesh=facet;var renderer=node.AddComponent<MeshRenderer>();renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;nodes.Add(node);
                LineRenderer Line(string label,int points,bool loop,float width)
                {var line=new GameObject(label).AddComponent<LineRenderer>();line.transform.SetParent(transform,false);line.useWorldSpace=false;line.loop=loop;line.widthMultiplier=width;line.positionCount=points;line.shadowCastingMode=ShadowCastingMode.Off;line.receiveShadows=false;return line;}
                rings.Add(Line("Mechanic pedestal "+i,48,true,.035f));links.Add(Line("Mechanic connection "+i,2,false,.025f));
            }
            Sync();
        }
        void LateUpdate(){Sync();}
        public void Sync()
        {
            View=RaidMechanicView.Read(raid);VisibleNodes=View.Visible?View.Count:0;if(facet==null)return;
            var material=View.Kind=="armor"?bronze:View.Kind=="crystal"?crystal:lunar;
            Color color=View.Kind=="armor"?new Color(.83f,.68f,.43f):View.Kind=="crystal"?new Color(.46f,.80f,.82f):new Color(.68f,.56f,.90f);
            color.a=View.Muted?.24f:.84f;material.SetColor("_Tint",color);
            float pulse=.96f+Mathf.Sin((float)(raid?.Elapsed??0)*2.3f)*.04f;
            for(int i=0;i<nodes.Count;i++)
            {
                bool visible=i<VisibleNodes;nodes[i].SetActive(visible);rings[i].gameObject.SetActive(visible);links[i].gameObject.SetActive(visible);if(!visible)continue;
                var p=View.Anchor(i);var node=nodes[i];node.GetComponent<Renderer>().sharedMaterial=material;
                float ratio=1-View.Progress;
                node.transform.localPosition=new Vector3(p.x,View.Kind=="armor"?.12f:.18f,p.y);
                node.transform.localScale=View.Kind=="armor"?new Vector3(.55f,.32f+ratio*.6f,.35f):View.Kind=="crystal"?new Vector3(.50f,.8f+ratio*.5f,.42f)*pulse:new Vector3(.38f,.30f,.38f)*pulse;
                node.transform.localRotation=Quaternion.Euler(0,View.Kind=="armor"?i*60:(float)(raid?.Elapsed??0)*12+i*120,View.Kind=="armor"?24:0);
                rings[i].sharedMaterial=links[i].sharedMaterial=material;
                float radius=View.Kind=="armor"?.55f:View.Kind=="crystal"?.85f:1.05f;
                for(int j=0;j<48;j++){float a=j*Mathf.PI*2/48;rings[i].SetPosition(j,new Vector3(p.x+Mathf.Cos(a)*radius,.13f,p.y+Mathf.Sin(a)*radius));}
                links[i].SetPosition(0,new Vector3(p.x,.14f,p.y));links[i].SetPosition(1,new Vector3(View.Center.x,.14f,View.Center.y));
            }
        }
        static Mesh FacetedShard()
        {
            var mesh=new Mesh{name="Bronze and crystal mechanic facets"};var v=new List<Vector3>();var c=new List<Color>();var t=new List<int>();
            for(int i=0;i<6;i++)
            {
                float a=i*Mathf.PI/3,b=(i+1)*Mathf.PI/3;int start=v.Count;
                v.Add(new Vector3(Mathf.Cos(a),.35f,Mathf.Sin(a)));v.Add(new Vector3(0,1.6f,0));v.Add(new Vector3(Mathf.Cos(b),.35f,Mathf.Sin(b)));
                float shade=.72f+i%3*.12f;c.AddRange(new[]{new Color(shade,shade,shade,1),Color.white,new Color(shade,shade,shade,1)});t.AddRange(new[]{start,start+1,start+2});
            }
            mesh.SetVertices(v);mesh.SetColors(c);mesh.SetTriangles(t,0);mesh.RecalculateBounds();return mesh;
        }
        void OnDestroy()
        {
            void Release(Object asset){if(asset==null)return;if(Application.isPlaying)Destroy(asset);else DestroyImmediate(asset);}
            Release(facet);foreach(var material in materials)Release(material);
        }
    }
}
