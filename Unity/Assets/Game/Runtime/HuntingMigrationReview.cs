using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

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
        readonly List<(Combatant actor,Label health,Label skills,VisualElement hp,VisualElement ultimate,Button slot,Image art)> cards=new();
        readonly List<BattleEvent> visualQueue=new();
        readonly List<Sprite> portraits=new();
        readonly Dictionary<string,Sprite> inspectionPortraits=new(StringComparer.Ordinal);
        readonly Dictionary<string,Button> navigation=new(StringComparer.Ordinal);
        VisualElement root,modal,chainRow,raidCommands,bossBar,bossTrack,mechanicBar,mechanicTrack;
        VisualElement currencyBadges;
        VisualElement huntStageTrack,huntStageFill,huntActions;
        Label raidInfo;
        Button counterButton,autoEvadeButton,trainingButton,counterPracticeButton,breakSkillButton;
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
        HuntEnvironmentPresentation huntEnvironment;
        readonly Dictionary<string,RaidArenaPresentation> raidMaps=new(StringComparer.Ordinal);
        string lastChain="제어 → 약화 → 추가 피해",selectedHero;
        string huntNotice="";
        float huntNoticeUntil;
        ReviewLaunchSettings launch;

        void Start()
        {
            Application.targetFrameRate=60;
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            if(playerSession!=null)Simulation=CreatePlayerHunt();
            else
            {
                ReviewSnapshot=ReviewStateFixture.Create(catalog);var state=new GameStateCommands(catalog,ReviewSnapshot,snapshot=>{ReviewSnapshot=snapshot;return true;});
                Simulation=new HuntingSimulation(20,9514,state);Simulation.Chain.Enabled=true;
            }
            Simulation.OnEvent=Receive;speed=(float)L.F(ReviewState.Snapshot()["battle_speed"],1);
            CreateWorld();BuildHud();RebuildActors();BuildParty();InstallRoyalHud();
            launch=ReviewLaunchSettings.Load();if(launch.HasRaid)StartRaid(launch.initialRaidZone);
            if(launch.initialPanel=="growth")ShowGrowth("leonhardt");else if(launch.initialPanel=="bag")ShowInventory();else if(launch.initialPanel=="menu")ShowStateMenu();
            Debug.Log(playerSession!=null?"ETERNAL_NATIVE_PLAYER_RUNNING: own Unity profile; original Godot save files are never write targets.":"ETERNAL_HUNT_REVIEW_RUNNING: native hunting, 10 original heroes, isolated Lv20 fixture; player saves untouched.");
        }
        void CreateWorld()
        {
            var cameraObject=new GameObject("Hunting 45 degree camera");BattleCamera=cameraObject.AddComponent<Camera>();
            worldRoot=new GameObject("Owned battle environment");cameraObject.transform.SetParent(worldRoot.transform,false);
            // The battle camera clears only its inset viewport. Clear the full
            // display first so translucent HUD panels cannot retain old glyphs.
            var backing=new GameObject("Full display HUD clear").AddComponent<Camera>();backing.transform.SetParent(worldRoot.transform,false);backing.depth=-100;backing.cullingMask=0;backing.clearFlags=CameraClearFlags.SolidColor;backing.backgroundColor=new Color(.025f,.035f,.038f,1);backing.allowHDR=false;backing.allowMSAA=false;
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
            if(PersistentPlayer)floor.transform.localScale=new Vector3(10,1,8);
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
            huntEnvironment=worldRoot.AddComponent<HuntEnvironmentPresentation>();huntEnvironment.Initialize(BattleCamera,floor.GetComponent<Renderer>(),ownedFloorMaterial,Simulation.Zone,PersistentPlayer);
            Destroy(floor.GetComponent<Collider>());
            feedback=new GameObject("Bounded hunting presentation").AddComponent<HuntingFeedback>();feedback.Initialize(BattleCamera);feedback.HitPresented=serial=>{if(actors.TryGetValue(serial,out var view))view.HitSeconds=.04f;};feedback.ConfigureExpandedHunt(PersistentPlayer);
            feedback.Lens=feedback.gameObject.AddComponent<BattleLensPresentation>();feedback.Lens.Initialize(BattleCamera,post);
            afterImages=new PaintedAfterImages(feedback.transform);
        }
        void Receive(BattleEvent e)
        {
            if(e.Kind=="pack"&&Raid==null&&huntEnvironment!=null)huntEnvironment.Bind(Simulation.Zone);
            if(e.Kind=="loot"&&Raid==null&&Simulation?.PlayerState!=null)
            {
                var levels=Simulation.Battle.Heroes.ToDictionary(h=>h.Id,h=>ReviewState.HeroProgress(h.Id).level);
                int xp=(int)HuntingSimulation.Canonical["zones"][Simulation.Zone]["xp"];
                var settled=playerSession!=null?ReviewState.SettleUnityPack(Simulation.PacksCleared,e.Amount,xp,Simulation.Battle.Enemies.Count):ReviewState.SettleReviewHuntPack(Simulation.PacksCleared,e.Amount,xp);
                huntNotice=settled.Message;huntNoticeUntil=Time.unscaledTime+3;
                if(settled.Ok&&playerSession!=null)playerPartyRefresh|=!ReviewState.DeployedHeroes().SequenceEqual(Simulation.Battle.Heroes.Select(h=>h.Id))||ReviewState.Formation!=Simulation.Formation;
                if(settled.Ok){Simulation.RefreshHeroGrowth();foreach(var hero in Simulation.Battle.Heroes)if(ReviewState.HeroProgress(hero.Id).level>levels[hero.Id]&&visualQueue.Count<256)visualQueue.Add(new BattleEvent("level_up",hero,"progress",hero));}
                if(playerSession!=null)
                {
                    if(settled.Ok&&!settled.SavePending&&++productivityPacks>=12){ReviewState.RecordHuntProductivity(productivitySeconds,productivityPacks);productivityPacks=0;productivitySeconds=0;}
                    PauseForSaveFailure();
                }
            }
            if(e.Kind=="victory"&&playerSession!=null&&Raid!=null&&!playerRaidTraining)
            {playerRaidReward=ReviewState.SettleUnityRaid(Raid.Zone,playerRaidAttempt,Math.Min(12,Raid.GuardBreaks*2+Raid.AddWaves*2+Raid.DpsPassed*3+Math.Min(3,Raid.Interrupts)));if(playerRaidReward.Ok)Simulation.RefreshHeroGrowth();PauseForSaveFailure();}
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
            bool paused=(Raid?.Paused??Simulation.Paused)||(Raid==null&&!ChallengeActive&&PersistentPlayer&&ReviewState.HasDeferredUnityLoot);
            bool running=Raid?.Running??!Simulation.Defeated;
            if(!paused&&running){accumulator+=frame*speed;if(PersistentPlayer&&Raid==null&&!ChallengeActive)productivitySeconds+=frame;}
            int steps=0;
            while(!paused&&accumulator>=.05&&steps<5){if(Raid!=null)Raid.Step(.05);else Simulation.Step(.05);accumulator-=.05;steps++;if(playerPartyRefresh||Raid==null&&!ChallengeActive&&PersistentPlayer&&ReviewState.HasDeferredUnityLoot)break;}
            if(playerPartyRefresh&&!ReviewState.SavePending&&!ReviewState.HasDeferredUnityLoot){playerPartyRefresh=false;RestartPlayerHunt(true);}
            if(Raid!=null&&launch.pauseAfterSeconds>0&&Raid.Elapsed>=launch.pauseAfterSeconds){Raid.Paused=true;launch.pauseAfterSeconds=0;}
            if(accumulator>=.05){CatchupLimitHits++;accumulator%=.05;}
            UpdateChallenge();
            TickLegacyWorld();
            StampActivity();
            float alpha=paused||!running?1:Mathf.Clamp01((float)(accumulator/.05));
            RebuildActors();
            feedback.RaidWarningVisible=Raid!=null&&(Raid.Warning!=null||Raid.SecondWarning!=null);
            feedback.Lens.Warning=feedback.RaidWarningVisible;
            feedback.SuppressCombatPopups=InspectionIsOpen||Raid!=null&&!Raid.Running;
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
                if(e.Kind=="cast"&&actors.ContainsKey(e.SourceSerial))trails[e.SourceSerial]=(.4f,0);
                feedback.Observe(e,ActiveBattle);
                if(e.Kind=="monster_skill")ObserveSkillFeed(e,FallenMonsterCatalog.Skill(e.Source),"monster");
                ObserveCastPresentation(e);ObserveRaidResolution(e);
            }
            UpdateAfterImages((float)frame);
            visualQueue.Clear();hudTimer+=frame;if(hudTimer>=.10){hudTimer=0;RefreshHud();}
            // Counter windows are shorter than the ordinary text refresh. Keep
            // actionable buttons current on every rendered frame.
            if(Raid!=null)RefreshRaidActions();
            RefreshSkillPresentation();
            RefreshRaidPresentation();
            RefreshMovementJoystick();
            ApplyRoyalHudLayout();
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
                    painted.Initialize(actor.Id,hero?1.9f:Raid!=null?4.6f:FallenMonsterCatalog.Contains(actor.Id)?FallenMonsterCatalog.Height(actor.Id):1.35f,BattleCamera,hero);painted.Driven=true;
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
            root.AddToClassList("hunt-hud");root.style.flexGrow=1;root.style.color=Parchment;root.style.fontSize=16;
            korean=Resources.Load<Font>("Eternal/Fonts/EternalKR-Regular");
            if(korean==null){korean=Font.CreateDynamicFontFromOSFont(new[]{"Malgun Gothic","맑은 고딕","Arial"},16);ownsKorean=true;}
            root.style.unityFont=korean;
            huntHeader=Box(root,"top",Ink);huntHeader.AddToClassList("hunt-header");huntHeader.style.height=94;huntHeader.style.flexShrink=0;
            huntHeader.style.paddingLeft=huntHeader.style.paddingRight=20;huntHeader.style.paddingTop=8;huntHeader.style.paddingBottom=7;
            var row=Row(huntHeader);row.name="hunt-header-main";row.style.height=43;row.style.flexShrink=0;row.style.alignItems=Align.Center;
            stageLabel=Text(row,"사냥터 1",22);stageLabel.name="hunt-stage-title";stageLabel.style.flexGrow=1;stageLabel.style.minWidth=0;stageLabel.style.marginRight=18;EllipsizeHud(stageLabel);
            currencyBadges=Row(row);currencyBadges.style.marginRight=12;currencyBadges.style.alignItems=Align.Center;currencyBadges.style.flexShrink=0;
            Label CurrencyBadge(string icon,Color accent)
            {
                var badge=Row(currencyBadges);badge.AddToClassList("hunt-currency");badge.style.alignItems=Align.Center;badge.style.height=34;badge.style.marginRight=6;
                badge.style.paddingLeft=8;badge.style.paddingRight=10;badge.style.backgroundColor=new Color(.09f,.13f,.14f);RoundHud(badge,8);
                var mark=new GodotHudIcon(icon,accent);mark.style.width=mark.style.height=21;mark.style.marginRight=6;badge.Add(mark);
                var value=Text(badge,"",14);value.style.marginLeft=value.style.marginRight=0;return value;
            }
            goldLabel=CurrencyBadge("coin",Bronze);gemLabel=CurrencyBadge("gem",new Color(.45f,.82f,.82f));
            currencyLabel=Text(row,"",14);currencyLabel.style.marginRight=12;currencyLabel.style.minWidth=0;EllipsizeHud(currencyLabel);
            if(playerSession!=null)CompactHudButton(row,"편성",ShowPlayerParty,64);
            pauseHudButton=CompactHudButton(row,"일시정지",()=>{if(playerSession!=null&&ReviewState.SavePending){PauseForSaveFailure();return;}if(Raid!=null)Raid.Paused=!Raid.Paused;else Simulation.Paused=!Simulation.Paused;RefreshHud();},96);
            speedHudButton=CompactHudButton(row,"×1",()=>{speed=speed==1?2:1;RefreshHud();},52);speedHudButton.tooltip="사냥 배속 전환 · ×1 / ×2";
            CompactHudButton(row,"관리",ShowHuntControls,62).tooltip="빠른 성장 · 장비 추천 · 사냥터 · 연계 설정";
            bossTrack=HudTrack(huntHeader,"boss-health-track",4);bossTrack.style.display=DisplayStyle.None;bossBar=HudFill(bossTrack,"boss-health-fill",Bronze);
            huntStageTrack=HudTrack(huntHeader,"hunt-stage-track",4);huntStageFill=HudFill(huntStageTrack,"hunt-stage-fill",Bronze);
            fixtureLabel=Text(huntHeader,"플레이테스트 · 임시 원정대 · 보상은 저장되지 않습니다",12);fixtureLabel.name="hunt-progress-caption";fixtureLabel.style.color=Moss;
            fixtureLabel.style.height=21;fixtureLabel.style.marginTop=3;fixtureLabel.style.marginBottom=0;EllipsizeHud(fixtureLabel);
            huntBattleSpace=new VisualElement{name="hunt-battle-space"};huntBattleSpace.style.flexGrow=1;huntBattleSpace.style.minHeight=0;root.Add(huntBattleSpace);
            huntDock=Box(root,"foot",Ink);huntDock.AddToClassList("hunt-unified-dock");huntDock.style.height=150;huntDock.style.flexShrink=0;
            huntDock.style.paddingLeft=huntDock.style.paddingRight=14;huntDock.style.paddingTop=4;huntDock.style.paddingBottom=4;
            var statusRow=Row(huntDock);statusRow.name="hunt-live-status";statusRow.style.height=25;statusRow.style.flexShrink=0;statusRow.style.alignItems=Align.Center;
            statusLabel=Text(statusRow,"",12);statusLabel.style.flexGrow=1;statusLabel.style.minWidth=0;EllipsizeHud(statusLabel);
            chainLabel=Text(statusRow,lastChain,11);chainLabel.style.color=Bronze;chainLabel.style.maxWidth=320;chainLabel.style.marginRight=8;EllipsizeHud(chainLabel);
            huntActions=Row(statusRow);huntActions.style.flexShrink=0;
            if(playerSession!=null){var revive=CompactHudButton(huntActions,"다시 사냥",()=>RestartPlayerHunt(false),92);revive.name="hunt-revive";revive.style.height=24;}
            chainHudButton=CompactHudButton(huntActions,"연계 펼치기",ToggleChainDeck,104);chainHudButton.name="hunt-chain-expand";chainHudButton.style.height=24;chainHudButton.style.fontSize=11;chainHudButton.tooltip="수동 스킬 6칸과 연계 순서 설정을 펼칩니다.";
            chainRow=Row(huntDock);chainRow.name="party";chainRow.AddToClassList("hunt-hero-strip");chainRow.style.height=68;chainRow.style.flexShrink=0;chainRow.style.justifyContent=Justify.Center;chainRow.style.alignItems=Align.Center;
            var nav=Row(huntDock);nav.name="hunt-bottom-navigation";nav.style.height=45;nav.style.flexShrink=0;nav.style.alignItems=Align.Center;
            nav.Insert(0,new RoyalHudSurface());nav.style.position=Position.Relative;
            var royalStyle=Resources.Load<StyleSheet>("Eternal/UI/RoyalHunt");if(royalStyle!=null)root.styleSheets.Add(royalStyle);
            string[] routes={"사냥","영웅","레이드","던전","진영전","가방"},icons={"sword","hero","raid","dungeon","war","bag"};
            for(int i=0;i<routes.Length;i++)
            {
                string route=routes[i];var b=Button(nav,"",()=>OpenPanel(route));b.name="navigation-"+route;b.AddToClassList("hunt-nav-button");
                b.style.flexGrow=1;b.style.flexBasis=0;b.style.minWidth=0;b.style.height=40;b.style.marginLeft=b.style.marginRight=3;
                b.style.flexDirection=FlexDirection.Row;b.style.alignItems=Align.Center;b.style.justifyContent=Justify.Center;
                var icon=new GodotHudIcon(icons[i],Parchment,true);icon.style.width=icon.style.height=23;icon.style.marginRight=9;b.Add(icon);
                var label=Text(b,route,15);label.pickingMode=PickingMode.Ignore;navigation[route]=b;
            }
            SelectNavigation("사냥");
            modal=Box(root,"inspection",Ink);modal.style.position=Position.Absolute;modal.style.right=18;modal.style.top=108;modal.style.bottom=166;modal.style.width=410;modal.style.display=DisplayStyle.None;modal.style.paddingLeft=18;modal.style.paddingRight=18;modal.style.paddingTop=16;
            raidCommands=Box(root,"raid-actions",Ink);raidCommands.style.position=Position.Absolute;raidCommands.style.left=18;raidCommands.style.right=18;raidCommands.style.bottom=184;raidCommands.style.height=124;raidCommands.style.display=DisplayStyle.None;raidCommands.style.paddingLeft=12;raidCommands.style.paddingRight=12;
            raidInfo=Text(raidCommands,"",14);raidInfo.style.height=24;raidInfo.style.unityTextAlign=TextAnchor.MiddleCenter;
            var commands=Row(raidCommands);commands.style.alignItems=Align.Center;
            Button(commands,"스킬",()=>Raid?.ManualCast(false)).style.flexGrow=1;
            Button(commands,"각성",()=>Raid?.ManualCast(true)).style.flexGrow=1;
            counterButton=Button(commands,"카운터",()=>Raid?.Counter());counterButton.style.flexGrow=1;
            breakSkillButton=Button(commands,"무력화 지원",()=>Raid?.CastBreakSkill());breakSkillButton.style.flexGrow=1;
            var tactics=Row(raidCommands);tactics.style.alignItems=Align.Center;tactics.style.marginTop=5;
            followButton=Button(tactics,"추적 복귀",()=>Raid?.ResumeFormation());followButton.style.flexGrow=1;
            spreadButton=Button(tactics,"산개 대형",()=>Raid?.SpreadFormation());spreadButton.style.flexGrow=1;spreadButton.tooltip="두 줄로 간격을 벌립니다. 조이스틱을 드래그하면 직접 이동으로 전환합니다.";
            autoEvadeButton=Button(tactics,"자동 회피 ON",()=>{if(Raid!=null)Raid.AutoEvade=!Raid.AutoEvade;});autoEvadeButton.style.flexGrow=1;
            autoEvadeButton.tooltip="자동 대열의 회피를 설정합니다. 조이스틱 직접 이동 중에는 자동 회피가 개입하지 않습니다.";
            trainingButton=Button(tactics,"패턴 훈련",()=>{if(Raid!=null){if(playerSession!=null)StartRaid(Raid.Zone,50,!playerRaidTraining);else StartRaid(Raid.Zone,Raid.ReviewLevel==100?50:100);}});trainingButton.style.flexGrow=1;
            trainingButton.tooltip="Lv.50 임시 원정대로 같은 보스 패턴을 연습합니다. 현재 전투는 새로 시작하며 저장 기록과 보상은 바뀌지 않습니다.";
            counterPracticeButton=Button(tactics,"카운터 연습",()=>{if(playerSession==null||playerRaidTraining)Raid?.BeginCounterPractice();});counterPracticeButton.style.flexGrow=1;
            counterPracticeButton.tooltip="기존 부채꼴 패턴을 재현합니다. 훈련 동안 평타·자동 스킬을 쉬고 정면 카운터와 회피를 연습하세요.";
            mechanicTrack=new VisualElement{name="raid-mechanic-track"};mechanicTrack.style.height=6;mechanicTrack.style.flexShrink=0;mechanicTrack.style.marginTop=8;mechanicTrack.style.backgroundColor=new Color(.13f,.18f,.19f);raidCommands.Add(mechanicTrack);
            mechanicBar=new VisualElement{name="raid-mechanic-fill"};mechanicBar.style.height=6;mechanicBar.style.backgroundColor=Moss;mechanicTrack.Add(mechanicBar);
            BuildSkillPresentation();BuildCombatReadability();BuildRaidPresentation();BuildMovementJoystick();BuildChainStrip();
            chainStrip.style.visibility=Visibility.Hidden;
            BuildHuntMapTools(huntBattleSpace);
            huntBattleSpace.RegisterCallback<PointerDownEvent>(e=>
            {
                if(Raid==null||e.button!=0)return;
                var bounds=root.worldBound;var screen=new Vector3((e.position.x-bounds.x)/bounds.width*Screen.width,(1-(e.position.y-bounds.y)/bounds.height)*Screen.height,0);
                var ray=BattleCamera.ScreenPointToRay(screen);var plane=new Plane(Vector3.up,Vector3.zero);
                if(plane.Raycast(ray,out float distance)){var point=ray.GetPoint(distance);Raid.Rally(new Vector2(point.x,point.z));}
            });
            BindHuntHudGeometry();
            PrepareInspectionChrome();
        }
        VisualElement Box(VisualElement parent,string name,Color color)
        {var e=new VisualElement{name=name};e.style.backgroundColor=color;e.style.borderTopWidth=e.style.borderBottomWidth=e.style.borderLeftWidth=e.style.borderRightWidth=1;e.style.borderTopColor=e.style.borderBottomColor=e.style.borderLeftColor=e.style.borderRightColor=new Color(.27f,.32f,.32f);parent.Add(e);return e;}
        static VisualElement Row(VisualElement parent){var row=new VisualElement();row.style.flexDirection=FlexDirection.Row;parent.Add(row);return row;}
        static Label Text(VisualElement parent,string value,int size){var l=new Label(value);l.style.fontSize=size;parent.Add(l);return l;}
        static Button Button(VisualElement parent,string title,Action action)
        {
            var b=new Button(action){text=title};b.AddToClassList("eternal-button");
            b.style.height=40;b.style.minWidth=86;b.style.marginLeft=8;
            b.style.paddingLeft=12;b.style.paddingRight=12;b.style.unityTextAlign=TextAnchor.MiddleCenter;
            parent.Add(b);return b;
        }
        void BuildParty()
        {
            if(cards.Count==ActiveBattle.Heroes.Count&&cards.Select(c=>c.actor.Id).SequenceEqual(ActiveBattle.Heroes.Select(h=>h.Id)))
            {for(int i=0;i<cards.Count;i++){var card=cards[i];cards[i]=(ActiveBattle.Heroes[i],card.health,card.skills,card.hp,card.ultimate,card.slot,card.art);}return;}
            chainRow.Clear();cards.Clear();foreach(var portrait in portraits)Destroy(portrait);portraits.Clear();
            // Godot LandscapeHuntHud: name, original portrait, level/state,
            // 3px HP gauge and 2px awakening gauge in one compact 10-hero strip.
            foreach(var h in ActiveBattle.Heroes)
            {
                var card=new Button(()=>ShowHero(h.Id)){name="party-card-"+h.Id};card.AddToClassList("hunt-hero-card");
                card.style.flexGrow=1;card.style.flexBasis=0;card.style.minWidth=0;card.style.maxWidth=180;card.style.height=64;
                card.style.marginTop=card.style.marginBottom=0;card.style.marginLeft=card.style.marginRight=2;card.style.paddingLeft=card.style.paddingRight=6;card.style.paddingTop=2;card.style.paddingBottom=2;
                card.style.flexDirection=FlexDirection.Column;card.style.alignItems=Align.Stretch;card.style.justifyContent=Justify.FlexStart;
                card.style.backgroundColor=new Color(.09f,.12f,.13f);card.style.color=Parchment;RoundHud(card,7);
                card.style.borderTopWidth=card.style.borderBottomWidth=card.style.borderLeftWidth=card.style.borderRightWidth=1;
                card.style.borderTopColor=card.style.borderBottomColor=card.style.borderLeftColor=card.style.borderRightColor=new Color(.25f,.31f,.31f);chainRow.Add(card);
                var title=Text(card,((string)Simulation.Catalog.Hero(h.Id)["name"]).Split(' ')[0],13);title.name="party-name";title.style.height=16;title.style.flexShrink=0;title.style.marginTop=title.style.marginBottom=title.style.paddingTop=title.style.paddingBottom=0;EllipsizeHud(title);title.pickingMode=PickingMode.Ignore;
                var body=Row(card);body.style.height=34;body.style.flexShrink=0;body.pickingMode=PickingMode.Ignore;
                var art=new Image{sprite=InspectionPortrait(h.Id),scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};art.AddToClassList("hunt-party-art");art.style.width=42;art.style.height=34;art.style.flexShrink=0;art.style.marginRight=5;body.Add(art);
                var copy=new VisualElement{pickingMode=PickingMode.Ignore};copy.style.flexGrow=1;copy.style.minWidth=0;body.Add(copy);
                var level=Text(copy,"",12);level.name="party-health";level.style.height=17;level.style.color=Moss;
                var skill=Text(copy,"준비",11);skill.name="party-skills";skill.style.height=17;skill.style.color=Bronze;
                foreach(var line in new[]{level,skill}){line.pickingMode=PickingMode.Ignore;line.style.flexShrink=0;line.style.marginTop=line.style.marginBottom=line.style.paddingTop=line.style.paddingBottom=0;EllipsizeHud(line);}
                var hpTrack=HudTrack(card,"party-hp-track",3);hpTrack.style.marginTop=1;var hp=HudFill(hpTrack,"party-hp-fill",Moss);
                var ultTrack=HudTrack(card,"party-ultimate-track",2);ultTrack.style.marginTop=1;var ultimate=HudFill(ultTrack,"party-ultimate-fill",Bronze);
                cards.Add((h,level,skill,hp,ultimate,card,art));
            }
        }
        void RefreshHud()
        {
            RefreshRoyalHud();
            RefreshChainStrip();
            RefreshHuntHudControls();
            fixtureLabel.text=Raid!=null?(Raid.ReviewLevel==50?"패턴 훈련":"플레이테스트")+" · Lv"+Raid.ReviewLevel+" 임시 원정대 · 보상은 저장되지 않습니다":"플레이테스트 · Lv20 임시 원정대 · 보상은 저장되지 않습니다";
            RefreshPlayerStatus();
            huntStageTrack.style.display=huntActions.style.display=Raid==null?DisplayStyle.Flex:DisplayStyle.None;
            if(Raid==null)
            {
                int aliveEnemies=Simulation.Battle.Enemies.Count(e=>e.Alive);
                float fraction=Simulation.NextPack>0?0:1-aliveEnemies/(float)Math.Max(1,Simulation.Battle.Enemies.Count);
                huntStageFill.style.width=Length.Percent((Simulation.PacksCleared%5+fraction)*20);
                fixtureLabel.text+=" · 무리 "+(Simulation.PacksCleared%5)+"/5";
            }
            stageLabel.text=Raid!=null?(string)Raid.ZoneData["boss"]+" · PHASE "+Raid.Phase:(playerSession!=null?"끝없는 사냥터 · "+HuntStageWorld.Atmosphere(Simulation.Stage):"사냥터 1")+"  ·  "+Simulation.Stage+" 스테이지";
            currencyLabel.text=Raid!=null?"HP "+Raid.Boss.Hp.ToString("N0")+" / "+Raid.Boss.MaxHp.ToString("N0")+" · "+TimeSpan.FromSeconds(Math.Max(0,240-Raid.Elapsed)).ToString(@"mm\:ss"):"◈ 골드 "+ReviewState.WalletGold.ToString("N0")+"   ·   ◆ 젬 "+ReviewState.WalletGems.ToString("N0");
            currencyBadges.style.display=Raid==null?DisplayStyle.Flex:DisplayStyle.None;currencyLabel.style.display=Raid!=null?DisplayStyle.Flex:DisplayStyle.None;
            goldLabel.text=ReviewState.WalletGold.ToString("N0");gemLabel.text=ReviewState.WalletGems.ToString("N0");
            statusLabel.text=Raid!=null?(Raid.Paused?"일시정지":Raid.Running?"레이드 전투":Raid.EventText)+" · "+Raid.MovementOrder+" · 원정대 "+ActiveBattle.Heroes.Count(h=>h.Alive)+"/"+ActiveBattle.Heroes.Count+" · 피해 "+Raid.DamageDealt.ToString("N0"):(Simulation.Defeated?"원정대 전멸":Simulation.Paused?"일시정지":Simulation.ManualMovementActive?"직접 이동":"자동 사냥")+" · "+Simulation.Battle.Heroes.Count(h=>h.Alive)+"/"+Simulation.Battle.Heroes.Count+"  ·  적 "+Simulation.Battle.Enemies.Count(e=>e.Alive)+"  ·  무리 "+Simulation.PacksCleared+"  ·  ×"+speed;
            if(Raid==null&&Time.unscaledTime<huntNoticeUntil)statusLabel.text+=" · "+huntNotice;
            if(Raid==null&&!ChallengeActive&&PersistentPlayer&&ReviewState.HasDeferredUnityLoot)statusLabel.text="장비 보관 대기 · 가방을 정리하고 보관함에서 수령하세요.";
            statusLabel.tooltip=statusLabel.text;
            if(ChallengeActive){stageLabel.text=(L.Flag(activeChallenge.Entry["practice"])?"[연습] ":"")+activeChallenge.Title;statusLabel.text="원정대 "+ActiveBattle.Heroes.Count(h=>h.Alive)+" / "+ActiveBattle.Heroes.Count+" · 적 "+ActiveBattle.Enemies.Count(e=>e.Alive)+" · "+Math.Max(0,activeChallenge.Limit-activeChallenge.Elapsed).ToString("F1")+"초 · 피해 "+activeChallenge.Damage;}
            RefreshHuntMapTools();
            var chain=Raid?.Chain??Simulation.Chain;
            if(chain.Current is ChainSkill next)
            {
                var p=ActiveBattle.Kits[next.Hero].Profiles[next.Slot];
                chainLabel.text=(chain.Enabled?"연계 "+(chain.Cursor+1)+"/"+chain.Entries.Count+" · ":"연계 OFF · ")+(string)p["skill"]+" · "+(next.Slot=="ultimate"?"게이지 ":"")+chain.Remaining().ToString("F1")+(next.Slot=="ultimate"?"% 남음":"초");
            }
            else chainLabel.text=lastChain;
            chainLabel.tooltip=chainLabel.text;
            foreach(var c in cards)
            {
                var h=c.actor;var kit=ActiveBattle.Kits[h.Id];
                string status=h.Stun>0?"기절":h.Bleed>0?"출혈":h.ArmorBreak>0?"방어 파쇄":h.Weaken>0?"약화":h.Vulnerable>0?"노출":h.Shield>0?"보호":h.Guard>0?"방어":"";
                int level=Raid?.ReviewLevel??(ReviewState!=null&&ReviewState.IsFactionHero(h.Id)?ReviewState.HeroProgress(h.Id).level:20);
                c.health.text="Lv."+level;c.health.style.color=h.Debuffed?new Color(.94f,.53f,.47f):h.Shield>0?new Color(.45f,.78f,.81f):Moss;
                double a1=kit.Cooldowns.GetValueOrDefault("a1"),a2=kit.Cooldowns.GetValueOrDefault("a2");double cooldown=Math.Min(a1,a2);
                c.skills.text=!h.Alive?"전투불능":status.Length>0?status:h.Ultimate>=100?"각성":cooldown>0?Math.Ceiling(cooldown)+"초":"준비";
                c.skills.style.color=!h.Alive?new Color(.90f,.49f,.46f):h.Ultimate>=100?new Color(.98f,.82f,.43f):Bronze;
                c.hp.style.width=Length.Percent(Mathf.Clamp01((float)h.HpRatio)*100);c.hp.style.backgroundColor=h.HpRatio<=.25?new Color(.94f,.47f,.47f):h.HpRatio<=.5?new Color(.93f,.75f,.40f):new Color(.44f,.84f,.55f);
                c.ultimate.style.width=Length.Percent(Mathf.Clamp01((float)h.Ultimate/100)*100);c.ultimate.style.backgroundColor=h.Ultimate>=100?new Color(1,.81f,.35f):Bronze;
                c.art.style.opacity=h.Alive?1:.35f;c.slot.style.opacity=h.Alive?1:.60f;
                c.slot.tooltip=(string)Simulation.Catalog.Hero(h.Id)["name"]+" · Lv."+level+" · "+(string)Simulation.Catalog.Hero(h.Id)["role_group"]+
                    "\nHP "+h.Hp.ToString("N0")+" / "+h.MaxHp.ToString("N0")+" · 각성 "+(int)h.Ultimate+"%"+
                    "\n주력 "+a1.ToString("F1")+"초 · 보조 "+a2.ToString("F1")+"초"+
                    "\n보호막 "+h.Shield.ToString("N0")+" · 방어 "+h.Guard.ToString("F1")+"초"+
                    "\n기절 "+h.Stun.ToString("F1")+"초 · 약화 "+h.Weaken.ToString("F1")+"초 · 노출 "+h.Vulnerable.ToString("F1")+"초"+
                    "\n방어 파쇄 "+h.ArmorBreak.ToString("F1")+"초 · 출혈 "+h.Bleed.ToString("F1")+"초";
            }
            if(Raid!=null)
            {
                RefreshRaidMechanic();bossBar.style.width=Length.Percent((float)Raid.Boss.HpRatio*100);
                RefreshRaidActions();
            }
        }
        void RefreshRaidMechanic()
        {
            if(!Raid.Running){raidInfo.text=Raid.EventText;raidInfo.style.color=Bronze;mechanicTrack.style.visibility=Visibility.Hidden;return;}
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
        void PanelHeader(string title) => OpenInspection(title);
        void ShowHero(string id) => ShowHeroShowcase(id);
        Sprite InspectionPortrait(string id)
        {
            if(inspectionPortraits.TryGetValue(id,out var found))return found;
            var f=OriginalCatalog.Atlas(id).attack.frames[0];var texture=OriginalCatalog.Texture(id);
            var sprite=Sprite.Create(texture,new Rect(f.region[0],1024-f.region[1]-f.region[3],f.region[2],f.region[3]),new Vector2(.5f,.5f));inspectionPortraits.Add(id,sprite);return sprite;
        }
        void ShowRoster()
        {
            PanelHeader("영웅 도감 · 30명");var ids=Simulation.Catalog.HeroIds.ToList();
            var search=new TextField("이름 찾기");search.style.height=30;search.style.marginTop=12;search.style.fontSize=13;modal.Add(search);
            var filterRow=Row(modal);filterRow.style.marginTop=8;filterRow.style.marginBottom=4;
            var factionFilter=new DropdownField("진영",new List<string>{"전체","아우렐리아","녹스페라"},0);
            var roleFilter=new DropdownField("역할",new List<string>{"전체","탱커","딜러","서포터","컨트롤러"},0);
            foreach(var field in new BaseField<string>[] {search,factionFilter,roleFilter})
            {
                field.labelElement.style.minWidth=0;field.labelElement.style.width=42;field.labelElement.style.color=Moss;
                field.AddToClassList("roster-filter");
            }
            foreach(var field in new VisualElement[]{factionFilter,roleFilter}){field.style.flexGrow=1;field.style.flexBasis=0;field.style.minWidth=0;field.style.fontSize=12;filterRow.Add(field);}
            var count=Text(modal,"영웅 30 / 30 · 원화를 눌러 스킬 보기",11);count.style.color=Moss;count.style.marginTop=4;
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
                bool deployed=ReviewState.DeployedHeroes().Contains(id);card.style.borderLeftWidth=deployed?3:1;card.style.borderLeftColor=deployed?Moss:new Color(.25f,.31f,.31f);
            }
            var list=new ListView(ids,66,Make,Bind){selectionType=SelectionType.None};list.style.flexGrow=1;list.style.marginTop=8;
            list.unbindItem=(item,_)=>{item.userData=null;item.Q<Image>("hero-art").sprite=null;};modal.Add(list);
            void Filter()
            {
                string query=(search.value??"").Trim();ids.Clear();
                foreach(string id in Simulation.Catalog.HeroIds)
                {
                    var h=Simulation.Catalog.Hero(id);string faction=(string)h["faction"]=="aurelia"?"아우렐리아":"녹스페라";
                    if(factionFilter.value!="전체"&&factionFilter.value!=faction||roleFilter.value!="전체"&&roleFilter.value!=(string)h["role_group"])continue;
                    string searchable=(string)h["name"]+" "+(string)h["class"]+" "+(string)h["race"];
                    if(query.Length>0&&searchable.IndexOf(query,StringComparison.OrdinalIgnoreCase)<0)continue;ids.Add(id);
                }
                list.Rebuild();count.text="영웅 "+ids.Count+" / 30 · 원화를 눌러 스킬 보기";
            }
            search.RegisterValueChangedCallback(_=>Filter());factionFilter.RegisterValueChangedCallback(_=>Filter());roleFilter.RegisterValueChangedCallback(_=>Filter());
        }
        void OpenPanel(string route)
        {
            if(ChallengeActive)FinishActiveChallenge(true);
            SelectNavigation(route);
            if(route=="사냥"){EndRaid();CloseInspection();return;}
            if(route=="영웅")
            {
                OpenHeroManagement();return;
            }
            if(route=="도전"||route=="레이드")
            {
                ShowRaidSelection();
                return;
            }
            if(route=="진영전")
            {
                ShowFactionWar();return;
            }
            if(route=="던전")ShowDungeons();else if(route=="가방")ShowInventory();else ShowStateMenu();
        }
        void SelectNavigation(string route)
        {
            RoyalHud?.SyncRoute(route);
            foreach(var tab in navigation)
            {
                bool active=tab.Key==(route=="도전"?"레이드":route);tab.Value.style.backgroundColor=active?new Color(.29f,.23f,.13f,.22f):Color.clear;tab.Value.style.color=active?new Color(1,.86f,.57f):Parchment;
                tab.Value.style.borderBottomWidth=active?3:1;tab.Value.style.borderBottomColor=active?Bronze:new Color(.31f,.37f,.37f);
            }
        }
        void ShowChain()
        {
            var chain=Raid?.Chain??Simulation.Chain;
            PanelHeader("원정대 스킬 연계");
            Button(modal,chain.Enabled?"자동 연계 ON":"자동 연계 OFF",()=>{chain.Enabled=!chain.Enabled;SavePlayerChain();ShowChain();}).SetEnabled(CanEditChain);
            var info=Text(modal,"순서를 바꾸거나 스킬을 교체하세요. 실제 시전이 성공해야 다음 단계로 넘어갑니다. 회복·보호 스킬은 긴급 상황에 먼저 사용합니다.",13);info.style.whiteSpace=WhiteSpace.Normal;info.style.marginTop=12;
            var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            for(int i=0;i<chain.Entries.Count;i++)
            {
                int index=i;var s=chain.Entries[i];var p=ActiveBattle.Kits[s.Hero].Profiles[s.Slot];
                var row=Row(list);row.style.marginTop=14;row.style.alignItems=Align.Center;
                var label=Text(row,(i+1)+". "+(string)p["skill"],16);label.style.flexGrow=1;label.style.color=i==chain.Cursor?Moss:Parchment;
                var up=Button(row,"↑",()=>{chain.Move(index,-1);SavePlayerChain();ShowChain();});up.style.minWidth=28;up.style.width=28;up.style.paddingLeft=up.style.paddingRight=0;up.SetEnabled(CanEditChain&&i>0);
                var down=Button(row,"↓",()=>{chain.Move(index,1);SavePlayerChain();ShowChain();});down.style.minWidth=28;down.style.width=28;down.style.paddingLeft=down.style.paddingRight=0;down.SetEnabled(CanEditChain&&i<chain.Entries.Count-1);
                var replace=Button(list,"교체 · "+(string)Simulation.Catalog.Hero(s.Hero)["name"],()=>ChooseChainSkill(index));replace.style.marginLeft=0;replace.SetEnabled(CanEditChain);
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
                Button(list,(string)Simulation.Catalog.Hero(hero.Id)["name"]+" · "+(string)p["skill"],()=>{chain.Set(index,selected);SavePlayerChain();ShowChain();}).SetEnabled(CanEditChain);
            }
        }
        public void StartRaid(string zone,int reviewLevel=100,bool training=false)
        {
            if(Simulation==null||!PreparePlayerRaid(zone,ref reviewLevel,training))return;if(raidMap!=null)raidMap.gameObject.SetActive(false);
            ResetSkillPresentation();
            SelectNavigation("도전");
            Raid=new RaidSimulation(zone,reviewLevel,9514,Simulation.Battle.Heroes.Select(h=>h.Id).ToArray(),playerSession!=null&&!playerRaidTraining?ReviewState:null);Raid.OnEvent=Receive;
            RestoreRaidChain();
            ResetViews();accumulator=0;visualQueue.Clear();huntFloor.SetActive(false);feedback.SetRaidMode(true);
            if(raidMaps.TryGetValue(zone,out var retained)&&retained!=null){raidMap=retained;raidMap.Rebind(Raid);raidMap.gameObject.SetActive(true);}
            else{raidMap=new GameObject("Dedicated raid arena · "+zone).AddComponent<RaidArenaPresentation>();raidMap.Initialize(Raid,ownedFloorMaterial);raidMaps[zone]=raidMap;}
            raidCommands.style.display=DisplayStyle.Flex;bossTrack.style.display=DisplayStyle.Flex;modal.style.display=DisplayStyle.None;speed=1;BuildParty();RebuildActors();RefreshHud();
        }
        public void EndRaid()
        {
            if(Raid==null)return;Raid=null;ResetViews();if(raidMap!=null)raidMap.gameObject.SetActive(false);raidMap=null;
            ResetSkillPresentation();
            SelectNavigation("사냥");
            accumulator=0;visualQueue.Clear();huntFloor.SetActive(true);feedback.SetRaidMode(false);raidCommands.style.display=DisplayStyle.None;bossTrack.style.display=DisplayStyle.None;BuildParty();RebuildActors();RefreshHud();
        }
        void RefreshRaidActions()
        {
            if(Raid==null)return;
            bool active=Raid.Running&&!Raid.Paused;
            spreadButton.SetEnabled(active);followButton.SetEnabled(active);
            spreadButton.style.color=Raid.MovementOrder=="산개"?Bronze:Parchment;followButton.style.color=Raid.MovementOrder=="역할 추적"?Bronze:Parchment;
            trainingButton.text=playerSession!=null?(playerRaidTraining?"원정대 전투":"패턴 훈련"):Raid.ReviewLevel==50?"Lv100 전투":"패턴 훈련";trainingButton.SetEnabled(!Raid.Paused);
            counterPracticeButton.style.display=Raid.ReviewLevel==50&&(playerSession==null||playerRaidTraining)&&Raid.Zone!="forgotten_mine"?DisplayStyle.Flex:DisplayStyle.None;counterPracticeButton.SetEnabled(Raid.Running&&!Raid.Paused&&!Raid.CounterPractice);
            autoEvadeButton.text=Raid.AutoEvade?"자동 회피 ON":"자동 회피 OFF";autoEvadeButton.SetEnabled(Raid.Running&&!Raid.Paused&&!Raid.ManualMovementActive);
            autoEvadeButton.style.color=Raid.AutoEvade?Moss:Bronze;
            bool ready=Raid.CounterReady;counterButton.SetEnabled(ready);counterButton.style.backgroundColor=ready?new Color(.12f,.36f,.54f):new Color(.10f,.14f,.15f);
            breakSkillButton.SetEnabled(Raid.BreakSkillReady);breakSkillButton.tooltip=Raid.BreakSkillHint;breakSkillButton.style.color=Raid.BreakSkillReady?Moss:Parchment;
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
