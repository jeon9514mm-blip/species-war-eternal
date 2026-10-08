using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed class HuntingMigrationReview : MonoBehaviour
    {
        public HuntingSimulation Simulation {get;private set;}
        public int RenderedFrames {get;private set;}
        public int CatchupLimitHits {get;private set;}
        public Camera BattleCamera {get;private set;}
        readonly Dictionary<int,PaintedActor> actors=new();
        readonly List<int> stale=new();
        readonly List<(Combatant actor,Label health,Label skills,VisualElement hp)> cards=new();
        readonly List<BattleEvent> visualQueue=new();
        readonly List<Sprite> portraits=new();
        VisualElement root,modal,chainRow;
        Label stageLabel,currencyLabel,statusLabel,chainLabel;
        double accumulator,hudTimer;
        float speed=1;
        Font korean;
        PanelSettings panel;
        HuntingFeedback feedback;
        Material ownedFloorMaterial;
        string lastChain="제어 → 약화 → 추가 피해",selectedHero;

        void Start()
        {
            Application.targetFrameRate=60;
            Simulation=new HuntingSimulation(20);Simulation.OnEvent=Receive;
            CreateWorld();BuildHud();RebuildActors();BuildParty();
            Debug.Log("ETERNAL_HUNT_REVIEW_RUNNING: native hunting, 10 original heroes, isolated Lv20 fixture; player saves untouched.");
        }
        void CreateWorld()
        {
            var cameraObject=new GameObject("Hunting 45 degree camera");BattleCamera=cameraObject.AddComponent<Camera>();
            // At the 1600x900 reference, the 648px battle viewport displays
            // normalized 1.9m originals at 86.4px: 1.9*648/(2*7.125).
            BattleCamera.orthographic=true;BattleCamera.orthographicSize=9.2625f/1.3f;
            BattleCamera.clearFlags=CameraClearFlags.SolidColor;
            BattleCamera.backgroundColor=new Color(.025f,.035f,.038f);cameraObject.AddComponent<AudioListener>();
            cameraObject.transform.position=new Vector3(0,24,-24);cameraObject.transform.LookAt(Vector3.zero);
            BattleCamera.rect=new Rect(0,.18f,1,.72f);
            var sun=new GameObject("Warm directional light").AddComponent<Light>();sun.type=LightType.Directional;sun.intensity=.9f;sun.transform.rotation=Quaternion.Euler(50,-25,0);sun.shadows=LightShadows.Soft;
            var floor=GameObject.CreatePrimitive(PrimitiveType.Plane);floor.name="Original stone hunting field";floor.transform.localScale=new Vector3(6,1,4);
            var floorMaterial=Resources.Load<Material>("Eternal/Materials/Stone");
            ownedFloorMaterial=new Material(floorMaterial);
            // Imported texture GUIDs are generated locally. Resolve by stable
            // resource paths so a clean import never depends on those GUIDs.
            ownedFloorMaterial.SetTexture("_BaseMap",Resources.Load<Texture2D>("Eternal/Floor/stone_1024_albedo_ao"));
            ownedFloorMaterial.SetTexture("_MicroNormal",Resources.Load<Texture2D>("Eternal/Floor/stone_1024_micro_normal"));
            floor.GetComponent<Renderer>().sharedMaterial=ownedFloorMaterial;
            Destroy(floor.GetComponent<Collider>());
            feedback=new GameObject("Bounded hunting presentation").AddComponent<HuntingFeedback>();feedback.Initialize(BattleCamera);
        }
        void Receive(BattleEvent e)
        {
            // Events produced after frame setup are presented together. A visual
            // queue never replays simulation actions or carries reward authority.
            if(visualQueue.Count<256)visualQueue.Add(e);
            if(e.Kind=="cast")
            {
                var p=Simulation.Battle.Kits[e.Source].Profiles[e.Slot];
                lastChain=(e.Chain?"연계 성공 · ":"")+(string)p["skill"];selectedHero=e.Source;
            }
        }
        void Update()
        {
            if(Simulation==null)return;
            RenderedFrames++;double frame=Math.Min(Time.unscaledDeltaTime,.25f);
            if(!Simulation.Paused&&!Simulation.Defeated)accumulator+=frame*speed;
            int steps=0;
            while(accumulator>=.05&&steps<5){Simulation.Step(.05);accumulator-=.05;steps++;}
            if(accumulator>=.05){CatchupLimitHits++;accumulator%=.05;}
            float alpha=Simulation.Paused?1:Mathf.Clamp01((float)(accumulator/.05));
            RebuildActors();
            foreach(var combatant in Simulation.Battle.Heroes.Concat(Simulation.Battle.Enemies))
            {
                if(!actors.TryGetValue(combatant.Serial,out var view))continue;
                var position=Vector2.Lerp(combatant.PreviousPosition,combatant.Position,alpha);
                view.transform.position=new Vector3(position.x,.04f,position.y);
                view.MovingSpeed=combatant.Velocity.magnitude;
                if(combatant.Velocity.sqrMagnitude>.015f)view.Facing=combatant.Velocity;
                view.gameObject.SetActive(combatant.Alive);
            }
            foreach(var e in visualQueue)
            {
                if(e.Kind=="windup"&&actors.TryGetValue(e.SourceSerial,out var source))
                {source.AttackSeconds=.32f;var target=Simulation.Battle.Enemies.Concat(Simulation.Battle.Heroes).FirstOrDefault(a=>a.Serial==e.TargetSerial);if(target!=null)source.Facing=target.Position-new Vector2(source.transform.position.x,source.transform.position.z);}
                if((e.Kind=="damage"||e.Kind=="critical"||e.Kind=="hero_hit")&&actors.TryGetValue(e.TargetSerial,out var victim))victim.HitSeconds=.04f;
                feedback.Observe(e,Simulation);
            }
            visualQueue.Clear();hudTimer+=frame;if(hudTimer>=.10){hudTimer=0;RefreshHud();}
        }
        void RebuildActors()
        {
            var living=Simulation.Battle.Heroes.Concat(Simulation.Battle.Enemies).ToList();stale.Clear();
            foreach(var pair in actors)if(!living.Any(a=>a.Serial==pair.Key))stale.Add(pair.Key);
            foreach(int id in stale){Destroy(actors[id].gameObject);actors.Remove(id);}
            foreach(var actor in living)
            {
                if(actors.ContainsKey(actor.Serial))continue;
                bool hero=Simulation.Battle.Kits.ContainsKey(actor.Id);
                var painted=new GameObject(actor.Id+" #"+actor.Serial).AddComponent<PaintedActor>();
                painted.Initialize(actor.Id,hero?1.9f:1.35f,BattleCamera);painted.Driven=true;
                actors[actor.Serial]=painted;feedback.AddShadow(painted.transform,hero?.7f:.5f);
            }
        }
        static readonly Color Ink=new(.055f,.075f,.083f,.96f),Bronze=new(.77f,.64f,.52f),Parchment=new(.85f,.84f,.80f),Moss=new(.66f,.72f,.62f);
        void BuildHud()
        {
            panel=ScriptableObject.CreateInstance<PanelSettings>();panel.scaleMode=PanelScaleMode.ScaleWithScreenSize;panel.referenceResolution=new Vector2Int(1600,900);panel.match=.5f;
            panel.themeStyleSheet=Resources.Load<ThemeStyleSheet>("Eternal/UI/RuntimeTheme")??throw new InvalidOperationException("Runtime UI theme missing.");
            var document=gameObject.AddComponent<UIDocument>();document.panelSettings=panel;root=document.rootVisualElement;
            root.style.flexGrow=1;root.style.color=Parchment;root.style.fontSize=16;
            korean=Font.CreateDynamicFontFromOSFont(new[]{"Malgun Gothic","맑은 고딕","Arial"},16);root.style.unityFont=korean;
            var top=Box(root,"top",Ink);top.style.height=92;top.style.paddingLeft=24;top.style.paddingRight=24;
            var row=Row(top);row.style.flexGrow=1;row.style.alignItems=Align.Center;
            stageLabel=Text(row,"사냥터 1",23);stageLabel.style.flexGrow=1;
            currencyLabel=Text(row,"",17);currencyLabel.style.marginRight=28;
            Button(row,"일시정지",()=>Simulation.Paused=!Simulation.Paused);
            Button(row,"속도",()=>speed=speed==1?2:1);
            var subtitle=Text(top,"UNITY 전환 검수 · Lv20 독립 테스트 · 기존 저장 데이터 유지",12);subtitle.style.color=Moss;subtitle.style.marginBottom=12;
            var battleSpace=new VisualElement();battleSpace.style.flexGrow=1;battleSpace.pickingMode=PickingMode.Ignore;root.Add(battleSpace);
            var foot=Box(root,"foot",Ink);foot.style.height=174;foot.style.paddingLeft=14;foot.style.paddingRight=14;
            var statusRow=Row(foot);statusRow.style.height=29;statusRow.style.alignItems=Align.Center;
            statusLabel=Text(statusRow,"",13);statusLabel.style.flexGrow=1;
            chainLabel=Text(statusRow,lastChain,13);chainLabel.style.color=Bronze;
            chainRow=Row(foot);chainRow.name="party";chainRow.style.height=91;
            var nav=Row(foot);nav.style.flexGrow=1;nav.style.alignItems=Align.Center;
            foreach(string name in new[]{"사냥","영웅","도전","가방","메뉴"})
            {
                string route=name;var b=Button(nav,name,()=>OpenPanel(route));b.style.flexGrow=1;b.style.marginLeft=5;b.style.marginRight=5;
            }
            modal=Box(root,"inspection",Ink);modal.style.position=Position.Absolute;modal.style.right=18;modal.style.top=108;modal.style.bottom=188;modal.style.width=410;modal.style.display=DisplayStyle.None;modal.style.paddingLeft=18;modal.style.paddingRight=18;modal.style.paddingTop=16;
        }
        VisualElement Box(VisualElement parent,string name,Color color)
        {var e=new VisualElement{name=name};e.style.backgroundColor=color;e.style.borderTopWidth=e.style.borderBottomWidth=e.style.borderLeftWidth=e.style.borderRightWidth=1;e.style.borderTopColor=e.style.borderBottomColor=e.style.borderLeftColor=e.style.borderRightColor=new Color(.27f,.32f,.32f);parent.Add(e);return e;}
        static VisualElement Row(VisualElement parent){var row=new VisualElement();row.style.flexDirection=FlexDirection.Row;parent.Add(row);return row;}
        static Label Text(VisualElement parent,string value,int size){var l=new Label(value);l.style.fontSize=size;parent.Add(l);return l;}
        static Button Button(VisualElement parent,string title,Action action)
        {
            var b=new Button(action){text=title};b.style.height=35;b.style.backgroundColor=new Color(.10f,.14f,.15f);b.style.color=Parchment;
            b.style.minWidth=86;b.style.marginLeft=8;b.style.paddingLeft=12;b.style.paddingRight=12;b.style.unityTextAlign=TextAnchor.MiddleCenter;
            b.style.borderTopWidth=b.style.borderBottomWidth=b.style.borderLeftWidth=b.style.borderRightWidth=1;
            b.style.borderTopColor=b.style.borderBottomColor=b.style.borderLeftColor=b.style.borderRightColor=new Color(.31f,.37f,.37f);b.style.borderTopLeftRadius=b.style.borderTopRightRadius=b.style.borderBottomLeftRadius=b.style.borderBottomRightRadius=6;parent.Add(b);return b;
        }
        void BuildParty()
        {
            chainRow.Clear();cards.Clear();
            foreach(var h in Simulation.Battle.Heroes)
            {
                var card=new Button(()=>ShowHero(h.Id));card.style.flexGrow=1;card.style.flexBasis=0;card.style.marginLeft=3;card.style.marginRight=3;card.style.paddingLeft=8;card.style.paddingRight=5;card.style.backgroundColor=new Color(.09f,.12f,.13f);card.style.color=Parchment;
                card.style.flexDirection=FlexDirection.Column;card.style.alignItems=Align.Stretch;card.style.justifyContent=Justify.FlexStart;
                card.style.paddingTop=4;card.style.paddingBottom=4;card.style.borderTopWidth=card.style.borderBottomWidth=card.style.borderLeftWidth=card.style.borderRightWidth=1;
                card.style.borderTopColor=card.style.borderBottomColor=card.style.borderLeftColor=card.style.borderRightColor=new Color(.25f,.31f,.31f);
                chainRow.Add(card);string name=(string)Simulation.Catalog.Hero(h.Id)["name"];
                var header=Row(card);var image=new Image();image.style.width=38;image.style.height=43;image.scaleMode=ScaleMode.ScaleToFit;
                var f=OriginalCatalog.Atlas(h.Id).attack.frames[0];var texture=Resources.Load<Texture2D>("Eternal/Actors/"+h.Id+"/poses");
                var portrait=Sprite.Create(texture,new Rect(f.region[0],1024-f.region[1]-f.region[3],f.region[2],f.region[3]),new Vector2(.5f,.5f));portraits.Add(portrait);image.sprite=portrait;header.Add(image);
                var desc=new VisualElement();header.Add(desc);desc.style.flexGrow=1;
                Text(desc,name.Split(' ')[0],14);var hp=Text(desc,"Lv.20",11);hp.style.color=Moss;
                var skills=Text(card,"",11);skills.style.marginTop=2;skills.style.color=Bronze;
                var bar=new VisualElement();bar.style.height=3;bar.style.backgroundColor=Moss;bar.style.marginTop=4;card.Add(bar);cards.Add((h,hp,skills,bar));
            }
        }
        void RefreshHud()
        {
            stageLabel.text="사냥터 1  ·  "+Simulation.Stage+" 스테이지";
            currencyLabel.text="◈ 골드 "+Simulation.Gold.ToString("N0")+"   ·   성장 경험치 "+Simulation.Xp.ToString("N0");
            statusLabel.text=(Simulation.Defeated?"원정대 전멸":Simulation.Paused?"일시정지":"자동 사냥")+" · "+Simulation.Battle.Heroes.Count(h=>h.Alive)+"/10  ·  적 "+Simulation.Battle.Enemies.Count(e=>e.Alive)+"  ·  무리 "+Simulation.PacksCleared+"  ·  ×"+speed;
            chainLabel.text=lastChain;
            foreach(var c in cards)
            {var kit=Simulation.Battle.Kits[c.actor.Id];c.health.text="HP "+(int)(c.actor.HpRatio*100)+"%";c.hp.style.width=Length.Percent((float)c.actor.HpRatio*100);c.skills.text="스킬 "+kit.Cooldowns.GetValueOrDefault("a1").ToString("F1")+"s · 궁극 "+(int)c.actor.Ultimate+"%";}
        }
        void PanelHeader(string title)
        {modal.Clear();modal.style.display=DisplayStyle.Flex;var row=Row(modal);var heading=Text(row,title,22);heading.style.flexGrow=1;Button(row,"닫기",()=>modal.style.display=DisplayStyle.None);}
        void ShowHero(string id)
        {
            var h=Simulation.Catalog.Hero(id);PanelHeader((string)h["name"]);Text(modal,(string)h["identity"]+" · "+(string)h["role_group"],14);
            var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            foreach(var skill in h["skills"])
            {
                var block=new VisualElement();block.style.marginTop=18;scroll.Add(block);
                var title=Text(block,(string)skill["skill"],18);title.style.color=Bronze;
                var detail=Text(block,(string)skill["effect"],14);detail.style.whiteSpace=WhiteSpace.Normal;
                Text(block,(string)skill["slot"]+" · "+((string)skill["slot"]=="passive"?"조건 발동":(string)skill["slot"]=="ultimate"?"궁극기 게이지 100%":skill["cooldown"]+"초"),12);
            }
        }
        void OpenPanel(string route)
        {
            if(route=="사냥"){modal.style.display=DisplayStyle.None;return;}
            if(route=="영웅")
            {
                PanelHeader("영웅 30명 · 원래 스킬 확인");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
                foreach(string id in Simulation.Catalog.HeroIds){string selected=id;Button(scroll,(string)Simulation.Catalog.Hero(id)["name"],()=>ShowHero(selected));}return;
            }
            PanelHeader(route+" · 이관 상태");var note=Text(modal,route=="도전"?"세 지역 전용 레이드의 패턴·회피·무력화·카운터를 이관 중입니다.":route=="가방"?"기존 장비·세트·프리셋·빠른 장착 규칙을 이관 중입니다.":"성장·수호신·진영·저장 데이터 이관 검증 중입니다.",16);note.style.whiteSpace=WhiteSpace.Normal;
            Text(modal,"이 검수 화면은 기존 저장 파일을 읽거나 덮어쓰지 않습니다.",13).style.whiteSpace=WhiteSpace.Normal;
        }
        void OnDestroy()
        {foreach(var p in actors.Values)if(p!=null)Destroy(p.gameObject);foreach(var p in portraits)Destroy(p);if(panel!=null)Destroy(panel);if(korean!=null)Destroy(korean);if(ownedFloorMaterial!=null)Destroy(ownedFloorMaterial);if(BattleCamera!=null)Destroy(BattleCamera.gameObject);if(feedback!=null)Destroy(feedback.gameObject);}
    }
}
