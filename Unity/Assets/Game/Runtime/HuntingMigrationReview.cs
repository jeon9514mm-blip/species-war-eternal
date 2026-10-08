using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview : MonoBehaviour
    {
        public HuntingSimulation Simulation {get;private set;}
        public GameStateCommands ReviewState=>Simulation?.PlayerState;
        public Newtonsoft.Json.Linq.JObject ReviewSnapshot {get;private set;}
        public RaidSimulation Raid {get;private set;}
        public CombatEncounter ActiveBattle=>Raid?.Battle??Simulation.Battle;
        public int RenderedFrames {get;private set;}
        public int CatchupLimitHits {get;private set;}
        public Camera BattleCamera {get;private set;}
        public readonly FrameBudgetProbe FrameCost=new();
        public HuntingFeedback Feedback=>feedback;
        readonly Dictionary<int,PaintedActor> actors=new();
        readonly Dictionary<string,Stack<PaintedActor>> enemyViews=new(StringComparer.Ordinal);
        readonly Dictionary<string,PaintedActor> heroViews=new(StringComparer.Ordinal);
        public int ReusedEnemyViews {get;private set;}
        public int ReusedHeroViews {get;private set;}
        readonly List<int> stale=new();
        readonly List<Combatant> drawActors=new(24);
        readonly HashSet<int> presentIds=new();
        readonly Dictionary<int,(float remaining,float untilSample)> trails=new();
        readonly List<int> finishedTrails=new();
        PaintedAfterImages afterImages;
        readonly List<(Combatant actor,Label health,Label skills,VisualElement hp)> cards=new();
        readonly List<BattleEvent> visualQueue=new();
        readonly List<Sprite> portraits=new();
        readonly Dictionary<string,Sprite> inspectionPortraits=new(StringComparer.Ordinal);
        readonly Dictionary<string,Button> navigation=new(StringComparer.Ordinal);
        VisualElement root,modal,chainRow,raidCommands,bossBar,bossTrack,mechanicBar,mechanicTrack;
        VisualElement currencyBadges;
        VisualElement huntStageTrack,huntStageFill,huntActions;
        Label raidInfo;
        Button dodgeButton,counterButton,autoEvadeButton,trainingButton,counterPracticeButton;
        Label stageLabel,currencyLabel,goldLabel,gemLabel,statusLabel,chainLabel,fixtureLabel;
        double accumulator,hudTimer;
        float speed=1;
        Font korean;
        bool ownsKorean;
        PanelSettings panel;
        HuntingFeedback feedback;
        Material ownedFloorMaterial;
        GameObject worldRoot,huntFloor;
        RaidArenaPresentation raidMap;
        readonly Dictionary<string,RaidArenaPresentation> raidMaps=new(StringComparer.Ordinal);
        string lastChain="제어 → 약화 → 추가 피해",selectedHero;
        string huntNotice="";
        float huntNoticeUntil;
        ReviewLaunchSettings launch;

        void Start()
        {
            Application.targetFrameRate=60;
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);ReviewSnapshot=ReviewStateFixture.Create(catalog);
            var state=new GameStateCommands(catalog,ReviewSnapshot,snapshot=>{ReviewSnapshot=snapshot;return true;});
            Simulation=new HuntingSimulation(20,9514,state);Simulation.OnEvent=Receive;Simulation.Chain.Enabled=true;
            CreateWorld();BuildHud();RebuildActors();BuildParty();
            launch=ReviewLaunchSettings.Load();if(launch.HasRaid)StartRaid(launch.initialRaidZone);
            if(launch.initialPanel=="growth")ShowGrowth("leonhardt");else if(launch.initialPanel=="bag")ShowInventory();else if(launch.initialPanel=="menu")ShowStateMenu();
            Debug.Log("ETERNAL_HUNT_REVIEW_RUNNING: native hunting, 10 original heroes, isolated Lv20 fixture; player saves untouched.");
        }
        void CreateWorld()
        {
            var cameraObject=new GameObject("Hunting 45 degree camera");BattleCamera=cameraObject.AddComponent<Camera>();
            worldRoot=new GameObject("Owned battle environment");cameraObject.transform.SetParent(worldRoot.transform,false);
            // At the 1600x900 reference, the 648px battle viewport displays
            // normalized 1.9m originals at 86.4px: 1.9*648/(2*7.125).
            BattleCamera.orthographic=true;BattleCamera.orthographicSize=9.2625f/1.3f;
            BattleCamera.allowHDR=true;BattleCamera.GetUniversalAdditionalCameraData().renderPostProcessing=true;
            BattleCamera.clearFlags=CameraClearFlags.SolidColor;
            BattleCamera.backgroundColor=new Color(.025f,.035f,.038f);cameraObject.AddComponent<AudioListener>();
            cameraObject.transform.position=new Vector3(0,24,-24);cameraObject.transform.LookAt(Vector3.zero);
            BattleCamera.rect=new Rect(0,.18f,1,.72f);
            var sun=new GameObject("Warm directional light").AddComponent<Light>();sun.type=LightType.Directional;sun.intensity=1;sun.transform.rotation=Quaternion.Euler(50,-25,0);sun.shadows=LightShadows.Soft;
            sun.transform.SetParent(worldRoot.transform,false);
            var post=new GameObject("Battle bloom and vignette").AddComponent<Volume>();post.transform.SetParent(worldRoot.transform,false);post.isGlobal=true;post.sharedProfile=Resources.Load<VolumeProfile>("Eternal/Materials/BattlePost");
            var floor=GameObject.CreatePrimitive(PrimitiveType.Plane);floor.name="Original stone hunting field";floor.transform.localScale=new Vector3(6,1,4);
            floor.transform.SetParent(worldRoot.transform,false);huntFloor=floor;
            var floorMaterial=Resources.Load<Material>("Eternal/Materials/Stone");
            ownedFloorMaterial=new Material(floorMaterial);
            ownedFloorMaterial.SetVector("_TileSize",new Vector4(3.05f,3.6f,0,0));
            // Imported texture GUIDs are generated locally. Resolve by stable
            // resource paths so a clean import never depends on those GUIDs.
            ownedFloorMaterial.SetTexture("_BaseMap",Resources.Load<Texture2D>("Eternal/Floor/stone_1024_albedo_ao"));
            ownedFloorMaterial.SetTexture("_MicroNormal",Resources.Load<Texture2D>("Eternal/Floor/stone_1024_micro_normal"));
            var paintedSlabs=Resources.Load<Texture2D>("Eternal/Environment/painted-slabs-v1");
            if(paintedSlabs!=null){ownedFloorMaterial.SetTexture("_PaintedMap",paintedSlabs);ownedFloorMaterial.SetFloat("_PaintedSlabs",1);}
            floor.GetComponent<Renderer>().sharedMaterial=ownedFloorMaterial;
            Destroy(floor.GetComponent<Collider>());
            feedback=new GameObject("Bounded hunting presentation").AddComponent<HuntingFeedback>();feedback.Initialize(BattleCamera);
            afterImages=new PaintedAfterImages(feedback.transform);
        }
        void Receive(BattleEvent e)
        {
            if(e.Kind=="loot"&&Raid==null&&Simulation?.PlayerState!=null)
            {
                int xp=(int)HuntingSimulation.Canonical["zones"][Simulation.Zone]["xp"];
                var settled=ReviewState.SettleReviewHuntPack(Simulation.PacksCleared,e.Amount,xp);
                huntNotice=settled.Message;huntNoticeUntil=Time.unscaledTime+3;
                if(settled.Ok)Simulation.RefreshHeroGrowth();
            }
            // Events produced after frame setup are presented together. A visual
            // queue never replays simulation actions or carries reward authority.
            if(visualQueue.Count<256)visualQueue.Add(e);
            if(e.Kind=="cast")
            {
                var p=ActiveBattle.Kits[e.Source].Profiles[e.Slot];
                lastChain=(e.Chain?"연계 성공 · ":"")+(string)p["skill"];selectedHero=e.Source;
            }
        }
        void Update()
        {
            if(Simulation==null)return;
            FrameCost.Begin();
            RenderedFrames++;double frame=Math.Min(Time.unscaledDeltaTime,.25f);
            bool paused=Raid?.Paused??Simulation.Paused;
            bool running=Raid?.Running??!Simulation.Defeated;
            if(!paused&&running)accumulator+=frame*speed;
            int steps=0;
            while(accumulator>=.05&&steps<5){if(Raid!=null)Raid.Step(.05);else Simulation.Step(.05);accumulator-=.05;steps++;}
            if(Raid!=null&&launch.pauseAfterSeconds>0&&Raid.Elapsed>=launch.pauseAfterSeconds){Raid.Paused=true;launch.pauseAfterSeconds=0;}
            if(accumulator>=.05){CatchupLimitHits++;accumulator%=.05;}
            float alpha=paused||!running?1:Mathf.Clamp01((float)(accumulator/.05));
            RebuildActors();
            feedback.RaidWarningVisible=Raid!=null&&(Raid.Warning!=null||Raid.SecondWarning!=null);
            var center=Vector2.zero;int alive=0;foreach(var hero in ActiveBattle.Heroes)if(hero.Alive){center+=hero.Position;alive++;}if(alive>0)feedback.SetExpeditionCenter(center/alive);
            foreach(var combatant in drawActors)
            {
                if(!actors.TryGetValue(combatant.Serial,out var view))continue;
                var position=Vector2.Lerp(combatant.PreviousPosition,combatant.Position,alpha);
                view.transform.position=new Vector3(position.x,.04f,position.y);
                view.MovingSpeed=paused||!running?0:combatant.Velocity.magnitude*speed;
                if(combatant.Velocity.sqrMagnitude>.015f)view.Facing=combatant.Velocity;
                view.gameObject.SetActive(combatant.Alive);
            }
            foreach(var e in visualQueue)
            {
                if(e.Kind=="windup"&&actors.TryGetValue(e.SourceSerial,out var source))
                {source.AttackSeconds=.32f;Combatant target=null;foreach(var a in drawActors)if(a.Serial==e.TargetSerial){target=a;break;}if(target!=null)source.Facing=target.Position-new Vector2(source.transform.position.x,source.transform.position.z);}
                if((e.Kind=="damage"||e.Kind=="critical"||e.Kind=="hero_hit")&&actors.TryGetValue(e.TargetSerial,out var victim))victim.HitSeconds=.04f;
                if(e.Kind=="cast"&&actors.ContainsKey(e.SourceSerial))trails[e.SourceSerial]=(.4f,0);
                feedback.Observe(e,ActiveBattle);
            }
            UpdateAfterImages((float)frame);
            visualQueue.Clear();hudTimer+=frame;if(hudTimer>=.10){hudTimer=0;RefreshHud();}
            // Counter windows are shorter than the ordinary text refresh. Keep
            // actionable buttons current on every rendered frame.
            if(Raid!=null)RefreshRaidActions();
            FrameCost.End();
        }
        void UpdateAfterImages(float dt)
        {
            afterImages.Advance(dt);finishedTrails.Clear();
            // Enumerate stable rendered actors, not a dictionary being changed.
            foreach(var actor in drawActors)
            {
                if(!trails.TryGetValue(actor.Serial,out var trail))continue;
                if(!actor.Alive||!actors.TryGetValue(actor.Serial,out var view)){finishedTrails.Add(actor.Serial);continue;}
                trail.remaining-=dt;trail.untilSample-=dt;
                if(trail.remaining<=0){finishedTrails.Add(actor.Serial);continue;}
                if(trail.untilSample<=0){if(view.MovingSpeed>.20f)afterImages.Capture(view.CapturePose());trail.untilSample=.08f;}
                trails[actor.Serial]=trail;
            }
            foreach(int id in finishedTrails)trails.Remove(id);
        }
        void RebuildActors()
        {
            var battle=ActiveBattle;int count=battle.Heroes.Count+battle.Enemies.Count,index=0;
            bool changed=drawActors.Count!=count;
            if(!changed)
            {foreach(var h in battle.Heroes)if(!ReferenceEquals(drawActors[index++],h)){changed=true;break;}
             if(!changed)foreach(var e in battle.Enemies)if(!ReferenceEquals(drawActors[index++],e)){changed=true;break;}}
            if(!changed)return;
            drawActors.Clear();presentIds.Clear();foreach(var h in battle.Heroes){drawActors.Add(h);presentIds.Add(h.Serial);}foreach(var e in battle.Enemies){drawActors.Add(e);presentIds.Add(e.Serial);}
            stale.Clear();foreach(var pair in actors)if(!presentIds.Contains(pair.Key))stale.Add(pair.Key);
            foreach(int id in stale)
            {
                var view=actors[id];
                if(view.IsHero){view.gameObject.SetActive(false);view.AttackSeconds=view.HitSeconds=view.MovingSpeed=0;heroViews[view.ActorId]=view;}
                else
                {
                    if(!enemyViews.TryGetValue(view.ActorId,out var pool)){pool=new Stack<PaintedActor>(4);enemyViews.Add(view.ActorId,pool);}
                    if(pool.Count<4){view.gameObject.SetActive(false);view.AttackSeconds=view.HitSeconds=view.MovingSpeed=0;pool.Push(view);}
                    else Destroy(view.gameObject);
                }
                actors.Remove(id);
            }
            foreach(int id in stale)trails.Remove(id);
            foreach(var actor in drawActors)
            {
                if(actors.ContainsKey(actor.Serial))continue;
                bool hero=ActiveBattle.Kits.ContainsKey(actor.Id);
                PaintedActor painted;
                if(hero&&heroViews.Remove(actor.Id,out var retained)&&retained!=null)
                {painted=retained;painted.gameObject.SetActive(true);ReusedHeroViews++;}
                else if(!hero&&enemyViews.TryGetValue(actor.Id,out var available)&&available.Count>0)
                {painted=available.Pop();painted.gameObject.SetActive(true);ReusedEnemyViews++;}
                else
                {
                    painted=new GameObject(actor.Id+" #"+actor.Serial).AddComponent<PaintedActor>();painted.transform.SetParent(worldRoot.transform,false);
                    painted.Initialize(actor.Id,hero?1.9f:Raid!=null?4.6f:1.35f,BattleCamera,hero);painted.Driven=true;
                    feedback.AddShadow(painted.transform,hero?.7f:Raid!=null?1.75f:.5f);
                }
                painted.name=actor.Id+" #"+actor.Serial;actors[actor.Serial]=painted;
            }
        }
        static readonly Color Ink=new(.055f,.075f,.083f,.96f),Bronze=new(.77f,.64f,.52f),Parchment=new(.85f,.84f,.80f),Moss=new(.66f,.72f,.62f);
        void BuildHud()
        {
            panel=ScriptableObject.CreateInstance<PanelSettings>();panel.scaleMode=PanelScaleMode.ScaleWithScreenSize;panel.referenceResolution=new Vector2Int(1600,900);panel.match=.5f;
            panel.themeStyleSheet=Resources.Load<ThemeStyleSheet>("Eternal/UI/RuntimeTheme")??throw new InvalidOperationException("Runtime UI theme missing.");
            var document=gameObject.AddComponent<UIDocument>();document.panelSettings=panel;root=document.rootVisualElement;
            var styles=Resources.Load<StyleSheet>("Eternal/UI/BattleUi");if(styles!=null)root.styleSheets.Add(styles);
            root.style.flexGrow=1;root.style.color=Parchment;root.style.fontSize=16;
            korean=Resources.Load<Font>("Eternal/Fonts/EternalKR-Regular");
            if(korean==null){korean=Font.CreateDynamicFontFromOSFont(new[]{"Malgun Gothic","맑은 고딕","Arial"},16);ownsKorean=true;}
            root.style.unityFont=korean;
            var top=Box(root,"top",Ink);top.style.height=92;top.style.paddingLeft=24;top.style.paddingRight=24;
            var row=Row(top);row.style.flexGrow=1;row.style.alignItems=Align.Center;
            stageLabel=Text(row,"사냥터 1",23);stageLabel.style.flexGrow=1;
            currencyBadges=Row(row);currencyBadges.style.marginRight=20;currencyBadges.style.alignItems=Align.Center;
            Label CurrencyBadge(string icon,Color accent,bool coin)
            {
                var badge=Row(currencyBadges);badge.style.alignItems=Align.Center;badge.style.height=35;badge.style.marginRight=8;badge.style.paddingLeft=10;badge.style.paddingRight=12;badge.style.backgroundColor=new Color(.09f,.13f,.14f);badge.style.borderTopLeftRadius=badge.style.borderTopRightRadius=badge.style.borderBottomLeftRadius=badge.style.borderBottomRightRadius=6;
                var mark=Text(badge,icon,coin?12:18);mark.style.width=20;mark.style.height=20;mark.style.marginRight=7;mark.style.paddingTop=mark.style.paddingBottom=0;mark.style.unityTextAlign=TextAnchor.MiddleCenter;mark.style.color=coin?Ink:accent;
                if(coin){mark.style.backgroundColor=accent;mark.style.borderTopLeftRadius=mark.style.borderTopRightRadius=mark.style.borderBottomLeftRadius=mark.style.borderBottomRightRadius=10;}
                return Text(badge,"",14);
            }
            goldLabel=CurrencyBadge("G",Bronze,true);gemLabel=CurrencyBadge("◆",new Color(.45f,.82f,.82f),false);
            currencyLabel=Text(row,"",17);currencyLabel.style.marginRight=28;
            Button(row,"일시정지",()=>{if(Raid!=null)Raid.Paused=!Raid.Paused;else Simulation.Paused=!Simulation.Paused;});
            Button(row,"속도",()=>speed=speed==1?2:1);
            bossTrack=new VisualElement{name="boss-health-track"};bossTrack.style.height=6;bossTrack.style.flexShrink=0;bossTrack.style.marginBottom=7;bossTrack.style.backgroundColor=new Color(.13f,.18f,.19f);bossTrack.style.display=DisplayStyle.None;top.Add(bossTrack);
            bossBar=new VisualElement{name="boss-health-fill"};bossBar.style.height=6;bossBar.style.backgroundColor=Bronze;bossTrack.Add(bossBar);
            huntStageTrack=new VisualElement{name="hunt-stage-track"};huntStageTrack.style.height=6;huntStageTrack.style.flexShrink=0;huntStageTrack.style.marginBottom=7;huntStageTrack.style.backgroundColor=new Color(.13f,.18f,.19f);top.Add(huntStageTrack);
            huntStageFill=new VisualElement{name="hunt-stage-fill"};huntStageFill.style.height=6;huntStageFill.style.backgroundColor=Moss;huntStageTrack.Add(huntStageFill);
            fixtureLabel=Text(top,"플레이테스트 · 임시 원정대 · 보상은 저장되지 않습니다",12);fixtureLabel.style.color=Moss;fixtureLabel.style.marginBottom=12;
            var battleSpace=new VisualElement();battleSpace.style.flexGrow=1;battleSpace.pickingMode=PickingMode.Ignore;root.Add(battleSpace);
            var foot=Box(root,"foot",Ink);foot.style.height=174;foot.style.paddingLeft=14;foot.style.paddingRight=14;
            var statusRow=Row(foot);statusRow.style.height=29;statusRow.style.alignItems=Align.Center;
            statusLabel=Text(statusRow,"",13);statusLabel.style.flexGrow=1;
            chainLabel=Text(statusRow,lastChain,13);chainLabel.style.color=Bronze;
            huntActions=Row(statusRow);
            var quickGrowth=Button(huntActions,"빠른 성장",()=>ShowGrowth(Simulation.Battle.Heroes[0].Id));quickGrowth.style.height=25;quickGrowth.style.fontSize=12;
            var quickGear=Button(huntActions,"장비 추천",()=>
            {
                if(!GrowthAllowed)return;StateCommand(ReviewState.RecommendEquip,()=>{});huntNotice=growthMessage;huntNoticeUntil=Time.unscaledTime+3;RefreshHud();
            });quickGear.style.height=25;quickGear.style.fontSize=12;
            Button(statusRow,"연계 순서",ShowChain).style.height=25;
            chainRow=Row(foot);chainRow.name="party";chainRow.style.height=91;
            var nav=Row(foot);nav.style.flexGrow=1;nav.style.alignItems=Align.Center;
            foreach(string name in new[]{"사냥","영웅","도전","가방","메뉴"})
            {
                string route=name;var b=Button(nav,name,()=>OpenPanel(route));b.style.flexGrow=1;b.style.marginLeft=5;b.style.marginRight=5;
                navigation[route]=b;
            }
            SelectNavigation("사냥");
            modal=Box(root,"inspection",Ink);modal.style.position=Position.Absolute;modal.style.right=18;modal.style.top=108;modal.style.bottom=188;modal.style.width=410;modal.style.display=DisplayStyle.None;modal.style.paddingLeft=18;modal.style.paddingRight=18;modal.style.paddingTop=16;
            raidCommands=Box(root,"raid-actions",Ink);raidCommands.style.position=Position.Absolute;raidCommands.style.left=18;raidCommands.style.right=18;raidCommands.style.bottom=184;raidCommands.style.height=87;raidCommands.style.display=DisplayStyle.None;raidCommands.style.paddingLeft=12;raidCommands.style.paddingRight=12;
            raidInfo=Text(raidCommands,"",14);raidInfo.style.height=24;raidInfo.style.unityTextAlign=TextAnchor.MiddleCenter;
            var commands=Row(raidCommands);commands.style.alignItems=Align.Center;
            Button(commands,"추적 복귀",()=>Raid?.ResumeFormation()).style.flexGrow=1;
            Button(commands,"스킬",()=>Raid?.ManualCast(false)).style.flexGrow=1;
            Button(commands,"각성",()=>Raid?.ManualCast(true)).style.flexGrow=1;
            counterButton=Button(commands,"카운터",()=>Raid?.Counter());counterButton.style.flexGrow=1;
            autoEvadeButton=Button(commands,"자동 회피 ON",()=>{if(Raid!=null)Raid.AutoEvade=!Raid.AutoEvade;});autoEvadeButton.style.flexGrow=1;
            autoEvadeButton.tooltip="자동 회피를 끄면 지정한 대열과 정면 카운터 위치를 유지합니다. 긴급 회피는 계속 사용할 수 있습니다.";
            dodgeButton=Button(commands,"긴급 회피",()=>Raid?.Dodge());dodgeButton.style.flexGrow=1;
            trainingButton=Button(commands,"패턴 훈련",()=>{if(Raid!=null)StartRaid(Raid.Zone,Raid.ReviewLevel==100?50:100);});trainingButton.style.flexGrow=1;
            trainingButton.tooltip="Lv.50 임시 원정대로 같은 보스 패턴을 연습합니다. 현재 전투는 새로 시작하며 저장 기록과 보상은 바뀌지 않습니다.";
            counterPracticeButton=Button(commands,"카운터 연습",()=>Raid?.BeginCounterPractice());counterPracticeButton.style.flexGrow=1;
            counterPracticeButton.tooltip="기존 부채꼴 패턴을 재현합니다. 훈련 동안 평타·자동 스킬을 쉬고 정면 카운터와 회피를 연습하세요.";
            mechanicTrack=new VisualElement{name="raid-mechanic-track"};mechanicTrack.style.height=6;mechanicTrack.style.flexShrink=0;mechanicTrack.style.marginTop=8;mechanicTrack.style.backgroundColor=new Color(.13f,.18f,.19f);raidCommands.Add(mechanicTrack);
            mechanicBar=new VisualElement{name="raid-mechanic-fill"};mechanicBar.style.height=6;mechanicBar.style.backgroundColor=Moss;mechanicTrack.Add(mechanicBar);
            battleSpace.pickingMode=PickingMode.Position;
            battleSpace.RegisterCallback<PointerDownEvent>(e=>
            {
                if(Raid==null||e.button!=0)return;
                var screen=new Vector3(e.position.x/root.worldBound.width*Screen.width,(1-e.position.y/root.worldBound.height)*Screen.height,0);
                var ray=BattleCamera.ScreenPointToRay(screen);var plane=new Plane(Vector3.up,Vector3.zero);
                if(plane.Raycast(ray,out float distance)){var point=ray.GetPoint(distance);Raid.Rally(new Vector2(point.x,point.z));}
            });
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
            if(cards.Count==ActiveBattle.Heroes.Count&&cards.Select(c=>c.actor.Id).SequenceEqual(ActiveBattle.Heroes.Select(h=>h.Id)))
            {for(int i=0;i<cards.Count;i++){var card=cards[i];cards[i]=(ActiveBattle.Heroes[i],card.health,card.skills,card.hp);}return;}
            chainRow.Clear();cards.Clear();foreach(var portrait in portraits)Destroy(portrait);portraits.Clear();
            foreach(var h in ActiveBattle.Heroes)
            {
                var card=new Button(()=>ShowHero(h.Id)){name="party-card-"+h.Id};card.style.flexGrow=1;card.style.flexBasis=0;card.style.marginLeft=3;card.style.marginRight=3;card.style.paddingLeft=8;card.style.paddingRight=5;card.style.backgroundColor=new Color(.09f,.12f,.13f);card.style.color=Parchment;
                card.style.flexDirection=FlexDirection.Column;card.style.alignItems=Align.Stretch;card.style.justifyContent=Justify.FlexStart;
                card.style.paddingTop=4;card.style.paddingBottom=4;card.style.borderTopWidth=card.style.borderBottomWidth=card.style.borderLeftWidth=card.style.borderRightWidth=1;
                card.style.borderTopColor=card.style.borderBottomColor=card.style.borderLeftColor=card.style.borderRightColor=new Color(.25f,.31f,.31f);
                chainRow.Add(card);string name=(string)Simulation.Catalog.Hero(h.Id)["name"];
                var header=Row(card);header.style.height=48;header.style.flexShrink=0;var image=new Image();image.style.width=38;image.style.height=43;image.style.flexShrink=0;image.scaleMode=ScaleMode.ScaleToFit;
                image.sprite=InspectionPortrait(h.Id);header.Add(image);
                var desc=new VisualElement();header.Add(desc);desc.style.flexGrow=1;desc.style.minWidth=0;
                Label CardLine(VisualElement parent,string value,int fontSize,int height,string key)
                {
                    var label=Text(parent,value,fontSize);label.name=key;label.style.height=height;label.style.flexShrink=0;
                    label.style.marginTop=label.style.marginBottom=label.style.paddingTop=label.style.paddingBottom=0;
                    label.style.whiteSpace=WhiteSpace.NoWrap;label.style.overflow=Overflow.Hidden;label.style.textOverflow=TextOverflow.Ellipsis;
                    label.style.unityTextAlign=TextAnchor.MiddleLeft;return label;
                }
                CardLine(desc,name.Split(' ')[0],13,25,"party-name");var hp=CardLine(desc,"Lv."+(Raid?.ReviewLevel??20),10,20,"party-health");hp.style.color=Moss;
                var skills=CardLine(card,"",10,19,"party-skills");skills.style.color=Bronze;
                var bar=new VisualElement();bar.style.height=3;bar.style.backgroundColor=Moss;bar.style.marginTop=4;card.Add(bar);cards.Add((h,hp,skills,bar));
            }
        }
        void RefreshHud()
        {
            fixtureLabel.text=Raid!=null?(Raid.ReviewLevel==50?"패턴 훈련":"플레이테스트")+" · Lv"+Raid.ReviewLevel+" 임시 원정대 · 보상은 저장되지 않습니다":"플레이테스트 · Lv20 임시 원정대 · 보상은 저장되지 않습니다";
            huntStageTrack.style.display=huntActions.style.display=Raid==null?DisplayStyle.Flex:DisplayStyle.None;
            if(Raid==null)
            {
                int aliveEnemies=Simulation.Battle.Enemies.Count(e=>e.Alive);
                float fraction=Simulation.NextPack>0?0:1-aliveEnemies/(float)Math.Max(1,Simulation.Battle.Enemies.Count);
                huntStageFill.style.width=Length.Percent((Simulation.PacksCleared%5+fraction)*20);
                fixtureLabel.text+=" · 무리 "+Simulation.PacksCleared%5+"/5";
            }
            stageLabel.text=Raid!=null?(string)Raid.ZoneData["boss"]+" · PHASE "+Raid.Phase:"사냥터 1  ·  "+Simulation.Stage+" 스테이지";
            currencyLabel.text=Raid!=null?"HP "+Raid.Boss.Hp.ToString("N0")+" / "+Raid.Boss.MaxHp.ToString("N0")+" · "+TimeSpan.FromSeconds(Math.Max(0,240-Raid.Elapsed)).ToString(@"mm\:ss"):"◈ 골드 "+ReviewState.WalletGold.ToString("N0")+"   ·   ◆ 젬 "+ReviewState.WalletGems.ToString("N0");
            currencyBadges.style.display=Raid==null?DisplayStyle.Flex:DisplayStyle.None;currencyLabel.style.display=Raid!=null?DisplayStyle.Flex:DisplayStyle.None;
            goldLabel.text=ReviewState.WalletGold.ToString("N0");gemLabel.text=ReviewState.WalletGems.ToString("N0");
            statusLabel.text=Raid!=null?(Raid.Paused?"일시정지":Raid.Running?"레이드 전투":Raid.EventText)+" · 원정대 "+ActiveBattle.Heroes.Count(h=>h.Alive)+"/10 · 피해 "+Raid.DamageDealt.ToString("N0"):(Simulation.Defeated?"원정대 전멸":Simulation.Paused?"일시정지":"자동 사냥")+" · "+Simulation.Battle.Heroes.Count(h=>h.Alive)+"/10  ·  적 "+Simulation.Battle.Enemies.Count(e=>e.Alive)+"  ·  무리 "+Simulation.PacksCleared+"  ·  ×"+speed;
            if(Raid==null&&Time.unscaledTime<huntNoticeUntil)statusLabel.text+=" · "+huntNotice;
            var chain=Raid?.Chain??Simulation.Chain;
            if(chain.Current is ChainSkill next)
            {
                var p=ActiveBattle.Kits[next.Hero].Profiles[next.Slot];
                chainLabel.text=(chain.Enabled?"연계 "+(chain.Cursor+1)+"/"+chain.Entries.Count+" · ":"연계 OFF · ")+(string)p["skill"]+" · "+(next.Slot=="ultimate"?"게이지 ":"")+chain.Remaining().ToString("F1")+(next.Slot=="ultimate"?"% 남음":"초");
            }
            else chainLabel.text=lastChain;
            foreach(var c in cards)
            {var kit=ActiveBattle.Kits[c.actor.Id];c.health.text="HP "+(int)(c.actor.HpRatio*100)+"%";c.hp.style.width=Length.Percent((float)c.actor.HpRatio*100);c.skills.text="스킬 "+kit.Cooldowns.GetValueOrDefault("a1").ToString("F1")+"s · 궁극 "+(int)c.actor.Ultimate+"%";}
            if(Raid!=null)
            {
                RefreshRaidMechanic();bossBar.style.width=Length.Percent((float)Raid.Boss.HpRatio*100);
                RefreshRaidActions();
            }
        }
        void RefreshRaidMechanic()
        {
            // These fills read the simulation's existing counters. They never
            // change combat, create a second timer or pretend HP is stagger.
            string mechanic="";float progress=0;Color color=Moss;
            if(Raid.Warning!=null)
            {
                bool immune=Raid.ControlImmunity>0;
                mechanic=(immune?"제어 면역 · 위험 구역 회피":"무력화 "+Raid.BreakGauge.ToString("F0")+" / 100")+" · 공격까지 "+Raid.TelegraphRemaining.ToString("F1")+"초";
                progress=immune?0:(float)Raid.BreakGauge/100;color=immune?new Color(.8f,.32f,.34f):new Color(.45f,.77f,.79f);
            }
            else if(Raid.SecondWarning!=null){mechanic="후속 충격 · "+Raid.SecondWaveRemaining.ToString("F1")+"초";color=new Color(.8f,.32f,.34f);}
            else if(Raid.GuardHp>0){mechanic="갑주 파괴 · "+Raid.GuardHp.ToString("N0")+" / "+Raid.GuardMax.ToString("N0");progress=1-(float)Raid.GuardHp/Math.Max(1,Raid.GuardMax);color=Bronze;}
            else if(Raid.AddHp>0){mechanic="수정핵 제거 · "+Raid.AddCount+"개 · 체력 "+Raid.AddHp.ToString("N0");progress=1-(float)Raid.AddHp/Math.Max(1,Raid.AddMax);}
            else if(Raid.DpsRemaining>0){mechanic="월식 의식 저지 · "+Raid.DpsRemaining.ToString("F1")+"초 · "+Raid.DpsDamage.ToString("N0")+" / "+Raid.DpsTarget.ToString("N0");progress=(float)Raid.DpsDamage/Math.Max(1,Raid.DpsTarget);color=Bronze;}
            raidInfo.text=mechanic.Length>0?mechanic:Raid.EventText;
            raidInfo.style.color=color;raidInfo.tooltip=Raid.EventText;
            mechanicTrack.style.visibility=mechanic.Length>0?Visibility.Visible:Visibility.Hidden;
            mechanicBar.style.width=Length.Percent(Mathf.Clamp01(progress)*100);mechanicBar.style.backgroundColor=color;
        }
        void PanelHeader(string title)
        {modal.Clear();modal.style.display=DisplayStyle.Flex;var row=Row(modal);var heading=Text(row,title,22);heading.style.flexGrow=1;Button(row,"닫기",()=>modal.style.display=DisplayStyle.None);}
        void ShowHero(string id)
        {
            var h=Simulation.Catalog.Hero(id);PanelHeader((string)h["name"]);
            var intro=Row(modal);intro.style.alignItems=Align.Center;intro.style.marginTop=10;intro.style.marginBottom=6;
            var art=new Image{sprite=InspectionPortrait(id),scaleMode=ScaleMode.ScaleToFit};art.style.width=98;art.style.height=128;art.style.marginRight=14;intro.Add(art);
            var identity=new VisualElement();identity.style.flexGrow=1;intro.Add(identity);
            Text(identity,(string)h["class"]+" · "+(string)h["role_group"],15).style.whiteSpace=WhiteSpace.Normal;
            Text(identity,((string)h["faction"]=="aurelia"?"아우렐리아":"녹스페라")+" · "+(string)h["race"]+" · "+((string)h["reach"]=="melee"?"근접":"원거리"),12).style.color=Moss;
            Text(identity,(string)h["identity_profile"]["trait"],13).style.whiteSpace=WhiteSpace.Normal;
            var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            if(ReviewState.IsFactionHero(id))
            {
                var profile=ReviewState.CombatProfile(id);Text(scroll,"Lv."+ReviewState.HeroProgress(id).level+" · "+ReviewState.Grade(id)+" · 공격 "+profile["attack"]+" · 체력 "+profile["max_hp"],13).style.color=Moss;
                Button(scroll,"성장 · 장비",()=>ShowGrowth(id)).style.marginLeft=0;
            }
            foreach(var skill in h["skills"])
            {
                var block=new VisualElement();block.style.marginTop=18;scroll.Add(block);
                var title=Text(block,(string)skill["skill"],18);title.style.color=Bronze;
                var detail=Text(block,(string)skill["effect"],14);detail.style.whiteSpace=WhiteSpace.Normal;
                string slot=(string)skill["slot"];string label=slot=="passive"?"패시브":slot=="a1"?"주력 스킬":slot=="a2"?"보조 스킬":"궁극기";
                Text(block,label+" · "+(slot=="passive"?"조건 발동":slot=="ultimate"?"궁극기 게이지 100%":skill["cooldown"]+"초"),12);
            }
        }
        Sprite InspectionPortrait(string id)
        {
            if(inspectionPortraits.TryGetValue(id,out var found))return found;
            var f=OriginalCatalog.Atlas(id).attack.frames[0];var texture=Resources.Load<Texture2D>("Eternal/Actors/"+id+"/poses");
            var sprite=Sprite.Create(texture,new Rect(f.region[0],1024-f.region[1]-f.region[3],f.region[2],f.region[3]),new Vector2(.5f,.5f));inspectionPortraits.Add(id,sprite);return sprite;
        }
        void ShowRoster()
        {
            PanelHeader("영웅 도감 · 30명");var ids=Simulation.Catalog.HeroIds.ToList();
            VisualElement Make()
            {
                var card=new Button();card.AddToClassList("hero-roster-card");card.clicked+=()=>{if(card.userData is string id)ShowHero(id);};
                var art=new Image{name="hero-art",scaleMode=ScaleMode.ScaleToFit};art.AddToClassList("hero-art");card.Add(art);
                var text=new VisualElement();text.style.flexGrow=1;card.Add(text);
                var name=new Label{name="hero-name"};name.AddToClassList("hero-roster-name");text.Add(name);
                var detail=new Label{name="hero-detail"};detail.AddToClassList("hero-roster-detail");text.Add(detail);return card;
            }
            void Bind(VisualElement card,int index)
            {
                string id=ids[index];var h=Simulation.Catalog.Hero(id);card.userData=id;card.Q<Image>("hero-art").sprite=InspectionPortrait(id);
                card.Q<Label>("hero-name").text=(string)h["name"];
                card.Q<Label>("hero-detail").text=((string)h["faction"]=="aurelia"?"아우렐리아":"녹스페라")+" · "+(string)h["role_group"]+" · "+((string)h["reach"]=="melee"?"근접":"원거리");
            }
            var list=new ListView(ids,66,Make,Bind){selectionType=SelectionType.None};list.style.flexGrow=1;list.style.marginTop=8;
            list.unbindItem=(item,_)=>{item.userData=null;item.Q<Image>("hero-art").sprite=null;};modal.Add(list);
        }
        void OpenPanel(string route)
        {
            SelectNavigation(route);
            if(route=="사냥"){EndRaid();modal.style.display=DisplayStyle.None;return;}
            if(route=="영웅")
            {
                ShowRoster();return;
            }
            if(route=="도전")
            {
                PanelHeader("지역 레이드");
                Text(modal,"Lv.100 독립 검수 원정대 · 기존 영웅·스킬 유지",13).style.whiteSpace=WhiteSpace.Normal;
                foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
                {
                    string id=zone;var data=Newtonsoft.Json.Linq.JObject.Parse(OriginalCatalog.Required("legacy-catalogs").text);
                    var z=data["zones"][id];var design=data["catalogs"]["raid"]["data"]["RAIDS"][id];
                    Button(modal,(string)z["boss"],()=>StartRaid(id)).style.marginTop=22;
                    Text(modal,(string)design["description"],14).style.whiteSpace=WhiteSpace.Normal;
                }
                return;
            }
            if(route=="가방")ShowInventory();else ShowStateMenu();
        }
        void SelectNavigation(string route)
        {
            foreach(var tab in navigation)
            {
                bool active=tab.Key==route;tab.Value.style.backgroundColor=active?new Color(.17f,.23f,.20f):new Color(.10f,.14f,.15f);tab.Value.style.color=active?Moss:Parchment;
                tab.Value.style.borderBottomWidth=active?3:1;tab.Value.style.borderBottomColor=active?Bronze:new Color(.31f,.37f,.37f);
            }
        }
        void ShowChain()
        {
            var chain=Raid?.Chain??Simulation.Chain;
            PanelHeader("원정대 스킬 연계");
            Button(modal,chain.Enabled?"자동 연계 ON":"자동 연계 OFF",()=>{chain.Enabled=!chain.Enabled;ShowChain();});
            var info=Text(modal,"순서를 바꾸거나 스킬을 교체하세요. 실제 시전이 성공해야 다음 단계로 넘어갑니다. 회복·보호 스킬은 긴급 상황에 먼저 사용합니다.",13);info.style.whiteSpace=WhiteSpace.Normal;info.style.marginTop=12;
            var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            for(int i=0;i<chain.Entries.Count;i++)
            {
                int index=i;var s=chain.Entries[i];var p=ActiveBattle.Kits[s.Hero].Profiles[s.Slot];
                var row=Row(list);row.style.marginTop=14;row.style.alignItems=Align.Center;
                var label=Text(row,(i+1)+". "+(string)p["skill"],16);label.style.flexGrow=1;label.style.color=i==chain.Cursor?Moss:Parchment;
                var up=Button(row,"↑",()=>{chain.Move(index,-1);ShowChain();});up.style.minWidth=28;up.style.width=28;up.style.paddingLeft=up.style.paddingRight=0;up.SetEnabled(i>0);
                var down=Button(row,"↓",()=>{chain.Move(index,1);ShowChain();});down.style.minWidth=28;down.style.width=28;down.style.paddingLeft=down.style.paddingRight=0;down.SetEnabled(i<chain.Entries.Count-1);
                var replace=Button(list,"교체 · "+(string)Simulation.Catalog.Hero(s.Hero)["name"],()=>ChooseChainSkill(index));replace.style.marginLeft=0;
            }
        }
        void ChooseChainSkill(int index)
        {
            var chain=Raid?.Chain??Simulation.Chain;
            PanelHeader("연계 "+(index+1)+"번 스킬 선택");var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            foreach(var hero in ActiveBattle.Heroes)
            foreach(string slot in new[]{"a1","a2","ultimate"})
            {
                var selected=new ChainSkill(hero.Id,slot);var p=ActiveBattle.Kits[hero.Id].Profiles[slot];
                Button(list,(string)Simulation.Catalog.Hero(hero.Id)["name"]+" · "+(string)p["skill"],()=>{chain.Set(index,selected);ShowChain();});
            }
        }
        public void StartRaid(string zone,int reviewLevel=100)
        {
            if(Simulation==null)return;if(raidMap!=null)raidMap.gameObject.SetActive(false);
            SelectNavigation("도전");
            Raid=new RaidSimulation(zone,reviewLevel,9514,Simulation.Battle.Heroes.Select(h=>h.Id).ToArray());Raid.OnEvent=Receive;
            ResetViews();accumulator=0;visualQueue.Clear();huntFloor.SetActive(false);feedback.SetRaidMode(true);
            if(raidMaps.TryGetValue(zone,out var retained)&&retained!=null){raidMap=retained;raidMap.Rebind(Raid);raidMap.gameObject.SetActive(true);}
            else{raidMap=new GameObject("Dedicated raid arena · "+zone).AddComponent<RaidArenaPresentation>();raidMap.Initialize(Raid,ownedFloorMaterial);raidMaps[zone]=raidMap;}
            raidCommands.style.display=DisplayStyle.Flex;bossTrack.style.display=DisplayStyle.Flex;modal.style.display=DisplayStyle.None;speed=1;BuildParty();RebuildActors();RefreshHud();
        }
        public void EndRaid()
        {
            if(Raid==null)return;Raid=null;ResetViews();if(raidMap!=null)raidMap.gameObject.SetActive(false);raidMap=null;
            SelectNavigation("사냥");
            accumulator=0;visualQueue.Clear();huntFloor.SetActive(true);feedback.SetRaidMode(false);raidCommands.style.display=DisplayStyle.None;bossTrack.style.display=DisplayStyle.None;BuildParty();RebuildActors();RefreshHud();
        }
        void RefreshRaidActions()
        {
            if(Raid==null)return;
            trainingButton.text=Raid.ReviewLevel==50?"Lv100 전투":"패턴 훈련";trainingButton.SetEnabled(!Raid.Paused);
            counterPracticeButton.style.display=Raid.ReviewLevel==50&&Raid.Zone!="forgotten_mine"?DisplayStyle.Flex:DisplayStyle.None;counterPracticeButton.SetEnabled(Raid.Running&&!Raid.Paused&&!Raid.CounterPractice);
            autoEvadeButton.text=Raid.AutoEvade?"자동 회피 ON":"자동 회피 OFF";autoEvadeButton.SetEnabled(Raid.Running&&!Raid.Paused);
            autoEvadeButton.style.color=Raid.AutoEvade?Moss:Bronze;
            dodgeButton.text=Raid.DodgeCooldown>0?"회피 "+Raid.DodgeCooldown.ToString("F1")+"초":"긴급 회피";dodgeButton.SetEnabled(Raid.Running&&!Raid.Paused&&Raid.DodgeCooldown<=0);
            bool ready=Raid.CounterReady;counterButton.SetEnabled(ready);counterButton.style.backgroundColor=ready?new Color(.12f,.36f,.54f):new Color(.10f,.14f,.15f);
            counterButton.tooltip=ready?"정면 카운터로 보스 공격 차단":Raid.CounterWindowOpen?"보스 정면에 움직일 수 있는 영웅이 필요합니다.":"부채꼴 공격 직전 정면에서 사용";
        }
        void ResetViews(bool dispose=false)
        {
            foreach(var actor in actors.Values)if(actor!=null)
            {
                if(dispose)Destroy(actor.gameObject);
                else if(actor.IsHero){actor.gameObject.SetActive(false);actor.AttackSeconds=actor.HitSeconds=actor.MovingSpeed=0;heroViews[actor.ActorId]=actor;}
                else
                {if(!enemyViews.TryGetValue(actor.ActorId,out var pool)){pool=new Stack<PaintedActor>(4);enemyViews.Add(actor.ActorId,pool);}if(pool.Count<4){actor.gameObject.SetActive(false);actor.AttackSeconds=actor.HitSeconds=actor.MovingSpeed=0;pool.Push(actor);}else Destroy(actor.gameObject);}
            }
            actors.Clear();drawActors.Clear();presentIds.Clear();trails.Clear();afterImages?.Clear();
        }
        void OnDestroy()
        {ResetViews(true);foreach(var pool in enemyViews.Values)foreach(var view in pool)if(view!=null)Destroy(view.gameObject);enemyViews.Clear();foreach(var view in heroViews.Values)if(view!=null)Destroy(view.gameObject);heroViews.Clear();afterImages?.Dispose();foreach(var p in portraits)Destroy(p);foreach(var p in inspectionPortraits.Values)if(p!=null)Destroy(p);if(panel!=null)Destroy(panel);if(ownsKorean&&korean!=null)Destroy(korean);if(ownedFloorMaterial!=null)Destroy(ownedFloorMaterial);if(worldRoot!=null)Destroy(worldRoot);foreach(var arena in raidMaps.Values)if(arena!=null)Destroy(arena.gameObject);raidMaps.Clear();if(feedback!=null)Destroy(feedback.gameObject);OriginalReliefMesh.Clear();}
    }
}
