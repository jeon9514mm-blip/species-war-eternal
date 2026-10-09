using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;

namespace Eternal.UnityMigration
{
    // Read-only effects of confirmed combat events. No damage/reward clocks,
    // painted character surfaces, global timeScale or camera shake are used.
    public sealed class RoyalGroveCombatFeedback : MonoBehaviour
    {
        sealed class Stroke
        {public LineRenderer line;public float age,lifetime;public Vector3 from,to;public bool projectile;public Color color;}
        sealed class Popup
        {public TextMesh text;public Vector3 origin;public float age;public Color color;}
        readonly List<Stroke> strokes=new();
        readonly List<Popup> popups=new();
        readonly Dictionary<int,LineRenderer> health=new();
        Material lineMaterial;
        Camera cameraView;
        LineRenderer selectedRing;
        Font font;
        public void Initialize(Camera camera)
        {
            cameraView=camera;lineMaterial=new Material(Resources.Load<Shader>("Eternal/GraphicsRebuild/GroveWorldLines")){name="Grove combat world lines"};
            lineMaterial.SetColor("_BaseColor",Color.white);font=Resources.Load<Font>("Eternal/Fonts/Outfit-ExtraBold");
            selectedRing=Line("Selected hero ground ring",.026f,new Color(.82f,.69f,.39f));selectedRing.loop=true;selectedRing.positionCount=64;
        }
        LineRenderer Line(string name,float width,Color color)
        {
            var go=new GameObject(name);go.transform.SetParent(transform,false);var line=go.AddComponent<LineRenderer>();
            line.sharedMaterial=lineMaterial;line.widthMultiplier=width;line.positionCount=2;line.startColor=line.endColor=color;
            line.numCapVertices=3;line.numCornerVertices=3;line.useWorldSpace=true;line.shadowCastingMode=ShadowCastingMode.Off;line.receiveShadows=false;return line;
        }
        static Vector3 At(Vector2 p,float height)=>new(p.x,height,p.y);
        public void Observe(BattleEvent item,CombatEncounter battle)
        {
            if(item.Kind=="damage"||item.Kind=="critical"||item.Kind=="hero_hit"||item.Kind=="heal")
            {
                if(item.Amount<=0)return;
                Color color=item.Kind=="heal"?new Color(.60f,.91f,.59f):item.Kind=="critical"?new Color(1,.81f,.30f):item.Kind=="hero_hit"?new Color(.92f,.53f,.45f):new Color(.88f,.86f,.78f);
                Number(item.Position,(item.Kind=="heal"?"+":"")+item.Amount.ToString("N0"),color);
                if(item.Kind=="heal")Ring(At(item.Position,.10f),.65f,.42f,color);
                else Impact(At(item.Position,1.1f),color);
            }
            if(item.Kind=="windup")
            {
                var source=battle.Heroes.Concat(battle.Enemies).FirstOrDefault(a=>a.Serial==item.SourceSerial);
                var target=battle.Heroes.Concat(battle.Enemies).FirstOrDefault(a=>a.Serial==item.TargetSerial);
                if(source==null||target==null)return;
                if(source.Id=="mira"||source.Id=="fallen_elf")
                {
                    Color color=source.Id=="mira"?new Color(.85f,.70f,.40f):new Color(.61f,.34f,.73f);
                    var line=Line("Arrow flight",.034f,color);strokes.Add(new Stroke{line=line,from=At(source.Position,1.15f),to=At(target.Position,1.15f),lifetime=.18f,projectile=true,color=color});
                }
            }
            if(item.Kind=="cast")
            {
                var source=battle.Heroes.FirstOrDefault(h=>h.Serial==item.SourceSerial);if(source==null)return;
                Color color=source.Id=="elisia"?new Color(.50f,.80f,.44f):source.Id=="mira"?new Color(.88f,.52f,.30f):new Color(.43f,.64f,.89f);
                Ring(At(source.Position,.08f),item.Slot=="ultimate"?1.6f:.9f,.6f,color);
            }
        }
        void Number(Vector2 position,string value,Color color)
        {
            if(font==null)return;
            if(popups.Count>=32){Destroy(popups[0].text.gameObject);popups.RemoveAt(0);}
            var go=new GameObject("Confirmed damage "+value);go.transform.SetParent(transform,false);var text=go.AddComponent<TextMesh>();
            text.font=font;text.GetComponent<MeshRenderer>().sharedMaterial=font.material;text.text=value;text.fontSize=36;text.characterSize=.09f;text.anchor=TextAnchor.MiddleCenter;text.alignment=TextAlignment.Center;text.color=color;
            go.transform.position=At(position,2.15f);popups.Add(new Popup{text=text,origin=go.transform.position,color=color});
        }
        void Impact(Vector3 p,Color color)
        {
            for(int i=0;i<5;i++)
            {
                float angle=i*Mathf.PI*2/5;var d=new Vector3(Mathf.Cos(angle),.3f,Mathf.Sin(angle));
                var line=Line("Settled hit spark",.035f,color);line.SetPosition(0,p+d*.10f);line.SetPosition(1,p+d*.35f);
                strokes.Add(new Stroke{line=line,lifetime=.12f,color=color});
            }
        }
        void Ring(Vector3 center,float radius,float duration,Color color)
        {
            var line=Line("Cast ground accent",.035f,color);line.loop=true;line.positionCount=48;
            for(int i=0;i<48;i++){float angle=i*Mathf.PI*2/48;line.SetPosition(i,center+new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle))*radius);}
            strokes.Add(new Stroke{line=line,lifetime=duration,color=color});
        }
        public void Advance(float dt,CombatEncounter battle,Combatant selected)
        {
            selectedRing.enabled=selected?.Alive==true;
            if(selectedRing.enabled)for(int i=0;i<64;i++){float a=i*Mathf.PI*2/64;selectedRing.SetPosition(i,At(selected.Position,.022f)+new Vector3(Mathf.Cos(a),0,Mathf.Sin(a))*.68f);}
            var existing=new HashSet<int>();
            foreach(var actor in battle.Heroes.Concat(battle.Enemies))
            {
                existing.Add(actor.Serial);
                if(!health.TryGetValue(actor.Serial,out var bar)){bar=Line("Actor health "+actor.Serial,.045f,Color.white);health[actor.Serial]=bar;}
                bar.enabled=actor.Alive;if(!bar.enabled)continue;
                bool hero=battle.Kits.ContainsKey(actor.Id);float height=hero?2.35f:FallenMonsterCatalog.Height(actor.Id)+.18f;
                Vector3 p=At(actor.Position,height),right=cameraView.transform.right*.42f;
                bar.SetPosition(0,p-right);bar.SetPosition(1,Vector3.Lerp(p-right,p+right,(float)actor.HpRatio));
                bar.startColor=bar.endColor=hero?new Color(.48f,.75f,.49f):new Color(.75f,.33f,.31f);
            }
            foreach(int serial in health.Keys.Where(id=>!existing.Contains(id)).ToArray()){Destroy(health[serial].gameObject);health.Remove(serial);}
            for(int i=strokes.Count-1;i>=0;i--)
            {
                var stroke=strokes[i];stroke.age+=dt;float t=Mathf.Clamp01(stroke.age/stroke.lifetime);
                if(t>=1){Destroy(stroke.line.gameObject);strokes.RemoveAt(i);continue;}
                if(stroke.projectile){var p=Vector3.Lerp(stroke.from,stroke.to,t);stroke.line.SetPosition(0,p);stroke.line.SetPosition(1,Vector3.Lerp(stroke.from,stroke.to,Mathf.Max(0,t-.20f)));}
                stroke.line.widthMultiplier=(stroke.projectile?.034f:.035f)*(1-t*.7f);
            }
            for(int i=popups.Count-1;i>=0;i--)
            {
                var popup=popups[i];popup.age+=dt;if(popup.age>.70f){Destroy(popup.text.gameObject);popups.RemoveAt(i);continue;}
                popup.text.transform.position=popup.origin+Vector3.up*(popup.age*.9f);popup.text.transform.rotation=cameraView.transform.rotation;
                Color color=popup.color;color.a=Mathf.Clamp01((.70f-popup.age)/.20f);popup.text.color=color;
            }
        }
        public void Clear()
        {
            foreach(var stroke in strokes)if(stroke.line!=null)Destroy(stroke.line.gameObject);strokes.Clear();
            foreach(var popup in popups)if(popup.text!=null)Destroy(popup.text.gameObject);popups.Clear();
            foreach(var bar in health.Values)if(bar!=null)Destroy(bar.gameObject);health.Clear();
        }
        void OnDestroy(){Clear();if(lineMaterial!=null)Destroy(lineMaterial);}
    }
}
