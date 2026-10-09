#if DEBUG && !UNITY_EDITOR
using System;
using System.Collections;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    // Explicit development flag: scratch profiles stay inside this build.
    // All player actions are real pointer down/up events across native frames.
    public sealed class StandaloneGameAcceptance : MonoBehaviour
    {
        static string report,profile;static bool resume,raidMechanics,featureFocus,monsterFocus;static int bandStart;
        JObject saved;readonly JArray trace=new(),environments=new();int checks;string error="";float started;
        HuntingMigrationReview Game=>FindAnyObjectByType<HuntingMigrationReview>();
        VisualElement UI=>FindObjectsByType<UIDocument>().First(d=>d.isActiveAndEnabled).rootVisualElement;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void Install()
        {
            if(!Debug.isDebugBuild)return;var args=Environment.GetCommandLineArgs();int flag=Array.IndexOf(args,"--eternal-game-qa");if(flag<0||flag+1>=args.Length)return;
            string build=Path.GetFullPath(Path.Combine(Application.dataPath,".."))+Path.DirectorySeparatorChar;report=Path.GetFullPath(args[flag+1]);
            if(!report.StartsWith(build,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Game QA output must stay inside the build.");
            resume=args.Contains("--qa-resume");raidMechanics=args.Contains("--qa-raid-mechanics");featureFocus=args.Contains("--qa-feature-focus");monsterFocus=args.Contains("--qa-monster-focus");string folder=resume?(string)JObject.Parse(File.ReadAllText(report))["scratch_name"]:"qa-profiles-"+Guid.NewGuid().ToString("N");
            if(folder==null||folder.Length!=44||!folder.StartsWith("qa-profiles-",StringComparison.Ordinal)||!Guid.TryParseExact(folder[12..],"N",out _))throw new InvalidOperationException("Invalid isolated profile folder.");
            profile=Path.Combine(build,folder);EternalBootstrap.ProfileDirectoryOverride=profile;
            int bandFlag=Array.IndexOf(args,"--qa-band-start");
            if(bandFlag>=0&&bandFlag+1<args.Length)
            {
                if(!int.TryParse(args[bandFlag+1],out bandStart)||bandStart!=499&&bandStart!=999)throw new InvalidOperationException("Only explicit scratch band-boundary scenarios are supported.");
                var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);var payload=NativePlayerSession.NewPayload(catalog,"aurelia");
                payload["unity_pack_total"]=(bandStart-1)*5+4;payload["unity_hunt_zone"]=HuntStageWorld.Zone(bandStart);payload["unity_loot_salt"]="native-boundary-"+bandStart;
                foreach(var hero in ((JObject)payload["hero_progress"]).Properties())hero.Value["level"]=50;
                var store=new NativeSessionStore(Path.Combine(profile,"aurelia.json"),"aurelia");if(!store.Write(payload))throw new InvalidOperationException("Scratch boundary profile could not be written.");
            }
            var go=new GameObject("Explicit native game acceptance");DontDestroyOnLoad(go);go.AddComponent<StandaloneGameAcceptance>();
        }
        void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Native game input: "+label);trace.Add(new JObject{{"check",label},{"frame",Time.frameCount}});}
        IEnumerator Click(string text,bool prefix=false)
        {
            if(Game!=null&&!prefix&&new[]{"사냥","영웅","도전","가방","메뉴"}.Contains(text))
            {
                yield return CloseInspectionThroughPointer();yield return ClickName("navigation-"+text);yield break;
            }
            if(Game!=null&&!prefix&&text=="원정대")
            {
                yield return CloseInspectionThroughPointer();text="편성";
            }
            if(Game!=null&&!prefix&&new[]{"빠른 성장","장비 추천","연계 순서","사냥터"}.Contains(text)
                &&!UI.Query<Button>().ToList().Any(b=>b.text==text&&Visible(b)))
            {
                yield return CloseInspectionThroughPointer();yield return Click("관리");
            }
            if(Game!=null&&!prefix&&text=="일시정지"&&(Game.Raid?.Paused??Game.Simulation.Paused))text="사냥 재개";
            if(Game!=null&&!prefix&&text.StartsWith("×",StringComparison.Ordinal)&&UI.Q<Button>("hunt-zoom-"+text.Substring(1))!=null)
            {
                yield return ClickName("hunt-zoom-"+text.Substring(1));yield break;
            }
            yield return Target(()=>UI.Query<Button>().ToList().Where(b=>b.enabledInHierarchy&&(prefix?(b.text??"").StartsWith(text,StringComparison.Ordinal):b.text==text)).ToArray(),text);
        }
        IEnumerator CloseInspectionThroughPointer()
        {
            var modal=UI.Q<VisualElement>("inspection");
            if(modal!=null&&modal.resolvedStyle.display!=DisplayStyle.None)yield return ClickName("inspection-close");
        }
        IEnumerator ClickName(string name)=>Target(()=>UI.Query<Button>().ToList().Where(b=>b.name==name&&b.enabledInHierarchy).ToArray(),name);
        IEnumerator Target(Func<Button[]> candidates,string label)
        {
            yield return null;Button button=null;
            for(int attempt=0;attempt<14;attempt++)
            {
                var matches=candidates();button=matches.FirstOrDefault(Visible);if(button!=null)break;
                var target=matches.FirstOrDefault();var scroll=target?.GetFirstAncestorOfType<ScrollView>();if(scroll==null)break;
                var ui=UI;var bounds=scroll.contentViewport.worldBound;var center=bounds.center;
                var point=new Vector2((center.x-ui.worldBound.x)/ui.worldBound.width*Screen.width,(1-(center.y-ui.worldBound.y)/ui.worldBound.height)*Screen.height);
                float direction=target.worldBound.center.y<bounds.yMin?240:-240;
                using(StateEvent.From(Mouse.current,out var e)){Mouse.current.position.WriteValueIntoEvent(point,e);Mouse.current.scroll.WriteValueIntoEvent(new Vector2(0,direction),e);InputSystem.QueueEvent(e);}InputSystem.Update();
                for(int frame=0;frame<4;frame++)yield return null;
            }
            if(button==null)throw new InvalidOperationException("Visible enabled button not found: "+label);
            yield return Pointer(button,label);
        }
        bool Visible(VisualElement element)
        {
            if(element==null||!element.visible||element.worldBound.width<=0||element.worldBound.height<=0)return false;
            for(var p=element;p!=null;p=p.parent)if(p.resolvedStyle.display==DisplayStyle.None||p.resolvedStyle.visibility==Visibility.Hidden||p is ScrollView s&&!s.contentViewport.worldBound.Contains(element.worldBound.center))return false;
            return UI.worldBound.Contains(element.worldBound.center);
        }
        IEnumerator Pointer(VisualElement element,string label)
        {
            if(!Visible(element)||!element.enabledInHierarchy)throw new InvalidOperationException("Native pointer target unavailable: "+label);
            var ui=UI;var bound=element.worldBound;var picked=ui.panel.Pick(bound.center);
            while(picked!=null&&picked!=element)picked=picked.parent;
            if(picked!=element)throw new InvalidOperationException("Native pointer target is obstructed: "+label);
            var point=new Vector2((bound.center.x-ui.worldBound.x)/ui.worldBound.width*Screen.width,(1-(bound.center.y-ui.worldBound.y)/ui.worldBound.height)*Screen.height);
            void Queue(bool down){using(StateEvent.From(Mouse.current,out var e)){Mouse.current.position.WriteValueIntoEvent(point,e);Mouse.current.leftButton.WriteValueIntoEvent(down?1f:0f,e);InputSystem.QueueEvent(e);}InputSystem.Update();}
            Queue(true);yield return null;Queue(false);trace.Add(new JObject{{"input",label},{"frame",Time.frameCount},{"x",point.x},{"y",point.y}});
            for(int i=0;i<5;i++)yield return null;
        }
        IEnumerator RemoveFirstPartyHero()
        {
            var remove=UI.Q<VisualElement>("party-slot-grid")?.Query<Button>().ToList().FirstOrDefault(b=>b.name!=null&&b.name.StartsWith("party-slot-remove-",StringComparison.Ordinal));
            if(remove==null)throw new InvalidOperationException("Chosen party hero removal button not found.");
            yield return ClickName(remove.name);
        }
        IEnumerator Capture(string name)
        {
            yield return new WaitForEndOfFrame();var world=FindAnyObjectByType<HuntEnvironmentPresentation>();
            if(world!=null){var texture=Resources.Load<Texture2D>(world.ArtResource);environments.Add(new JObject{{"capture",name},{"zone",world.Zone},{"painting_active",world.HasPainting},{"width",texture.width},{"height",texture.height},{"runtime_format",texture.format.ToString()}});}
            ScreenCapture.CaptureScreenshot(Path.Combine(Path.GetDirectoryName(report),name+".png"));yield return new WaitForSecondsRealtime(.3f);
        }
        IEnumerator DragStick(Vector2 direction,float hold,string capture="")
        {
            var stick=UI.Q("movement-stick");Check(Visible(stick)&&stick.enabledInHierarchy,"visible enabled movement joystick");
            var center=stick.worldBound.center;var target=center+direction*stick.worldBound.width*.75f;
            void Queue(Vector2 p,bool down){var screen=new Vector2(p.x/UI.worldBound.width*Screen.width,(1-p.y/UI.worldBound.height)*Screen.height);using(StateEvent.From(Mouse.current,out var e)){Mouse.current.position.WriteValueIntoEvent(screen,e);Mouse.current.leftButton.WriteValueIntoEvent(down?1f:0f,e);InputSystem.QueueEvent(e);}InputSystem.Update();}
            Queue(center,true);yield return null;Queue(target,true);yield return new WaitForSecondsRealtime(hold);
            if(capture.Length>0)yield return Capture(capture);
            Queue(target,false);for(int i=0;i<5;i++)yield return null;
            trace.Add(new JObject{{"input","joystick press/drag outside/release"},{"frame",Time.frameCount},{"direction_x",direction.x},{"direction_y",direction.y}});
        }
        IEnumerator RaidMechanicsSuite()
        {
            long gold=Game.ReviewState.WalletGold;int packs=Game.Simulation.PacksCleared;
            yield return Click("일시정지");var huntBefore=Game.Simulation.Battle.Heroes.Select(h=>h.Position).ToArray();
            yield return DragStick(Vector2.right,.3f,"hunt-joystick-native");
            Check(Game.Simulation.ManualMovementActive&&Game.Simulation.ManualDirection==Vector2.zero,"hunt joystick release holds manual position");
            Check(Game.Simulation.Battle.Heroes.Select((h,i)=>Vector2.Distance(h.Position,huntBefore[i])).Average()>.1f,"hunt drag physically moves expedition");
            var held=Game.Simulation.Battle.Heroes.Select(h=>h.Position).ToArray();yield return new WaitForSecondsRealtime(.25f);
            Check(Game.Simulation.Battle.Heroes.Select((h,i)=>Vector2.Distance(h.Position,held[i])).All(d=>d<.001f),"released hunt stick stops movement");
            Check(FindAnyObjectByType<HuntingFeedback>().HuntZoom==1,"hunt drag preserves camera zoom");
            yield return Click("자동 추적");Check(!Game.Simulation.ManualMovementActive,"hunt pointer resumes automatic tracking");yield return Click("일시정지");
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                yield return Click("도전");yield return Capture("raid-selection-"+zone+"-native");
                yield return Click((string)HuntingSimulation.Canonical["zones"][zone]["boss"]);
                Check(Game.Raid!=null&&Game.Raid.Zone==zone&&Game.Raid.StateBound,"selected actual regional raid "+zone);
                yield return Click("패턴 훈련");Check(!Game.Raid.StateBound&&Game.Raid.ReviewLevel==50,"isolated training "+zone);
                Check(!UI.Query<Button>().ToList().Any(b=>(b.text??"").StartsWith("긴급 회피")),"emergency dodge button removed "+zone);
                yield return DragStick(Vector2.left,.25f,zone=="gray_meadow"?"raid-joystick-native":"");
                Check(Game.Raid.ManualMovementActive&&Game.Raid.ManualDirection==Vector2.zero&&Game.Raid.DodgeCooldown==0,"raid joystick release, no artificial dodge "+zone);
                var before=Game.Raid.Battle.Heroes.Select(h=>h.Position).ToArray();yield return Click("산개 대형");
                Check(Game.Raid.MovementOrder=="산개","pointer spread order "+zone);
                Check(Game.Raid.Battle.Heroes.Select((h,i)=>Vector2.Distance(h.Position,before[i])).All(d=>d<1.2f),"spread is physical movement, no snap "+zone);
                yield return Click("추적 복귀");Check(Game.Raid.MovementOrder=="역할 추적","pointer returns role movement "+zone);
                yield return Click("산개 대형");yield return Click("일시정지");
                Check(Game.Raid.Paused&&!UI.Query<Button>().ToList().First(b=>b.text=="산개 대형").enabledInHierarchy,"paused spread disabled "+zone);
                var raid=Game.Raid;raid.Boss.Attack=0;foreach(var hero in raid.Battle.Heroes){hero.AttackRemaining=1000;hero.Windup=-1;}
                foreach(int phase in new[]{2,3})
                {
                    raid.Boss.Hp=(int)(raid.Boss.MaxHp*(phase==2?.59:.29));raid.AdvancePhase();
                    for(int frame=0;frame<6;frame++)yield return null;
                    string kind=zone=="gray_meadow"?"armor":zone=="forgotten_mine"?"crystal":"ritual";
                    var mechanics=FindAnyObjectByType<RaidMechanicPresentation>();
                    Check(Game.VisibleRaidMechanic==kind&&mechanics.VisibleNodes==RaidMechanicView.Read(raid).Count,"native phase mechanic projection "+zone+phase);
                    Check(mechanics.GetComponentsInChildren<Collider>(true).Length==0,"native mechanic visuals have no collision "+zone+phase);
                    Check(Game.RaidPhaseBannerVisible,"native phase transition banner "+zone+phase);
                    Check(!UI.Q("raid-phase-transition").worldBound.Overlaps(UI.Q("raid-response").worldBound)&&!UI.Q("raid-phase-transition").worldBound.Overlaps(UI.Q("confirmed-skill-feed").worldBound),"phase banner clears response and skill feed "+zone+phase);
                    yield return Capture("raid-"+zone+"-phase"+phase+"-native");
                }
                // Explicit paused rendering fixture advances only its inspection clock.
                raid.Elapsed+=2;for(int frame=0;frame<6;frame++)yield return null;
                Check(Visible(UI.Q("raid-world-mechanic"))&&!Game.RaidPhaseBannerVisible,"phase intro yields to retained mechanic status "+zone);
                yield return Capture("raid-"+zone+"-mechanic-native");
                raid.StartWarning((JObject)raid.Design["phases"][2]);for(int frame=0;frame<6;frame++)yield return null;
                Check(!Game.RaidPhaseBannerVisible&&FindAnyObjectByType<RaidMechanicPresentation>().View.Muted,"warning has priority over phase decoration "+zone);
                Check(!Visible(UI.Q("raid-world-mechanic")),"warning hides mechanic tag "+zone);
                yield return Capture("raid-"+zone+"-warning-native");
                yield return Click("사냥");Check(Game.Raid==null&&Game.Simulation.PacksCleared==packs,"return retains hunt progress "+zone);
                Check(Game.ReviewState.WalletGold==gold,"training fixtures grant no rewards "+zone);
            }
        }
        IEnumerator FeatureFocusSuite()
        {
            long gold=Game.ReviewState.WalletGold;yield return Click("빠른 성장");
            Check(UI.Q("growth-party-selector").Query<Button>().ToList().Count==10,"growth exposes ten current heroes");
            yield return ClickName("growth-select-mira");
            Check(UI.Q<Label>("HeroIdentityName").text==(string)Game.Simulation.Catalog.Hero("mira")["name"]&&Game.ReviewState.WalletGold==gold,"hero navigation is read-only");
            Check(Visible(UI.Q("HeroStatGrid"))&&UI.Q("HeroGear_weapon")==null,"growth summary and exclusive growth tab");
            yield return ClickName("HeroTab_skills");
            Check(UI.Q("HeroStatGrid")==null&&UI.Q("HeroSkill_a1")!=null,"skills tab isolates original skills");
            yield return ClickName("HeroTab_growth");
            Check(Visible(UI.Q("HeroResearchPoints"))&&UI.Q("HeroSkill_a1")==null,"growth tab isolates its research controls");yield return Capture("growth-research-native");
            yield return ClickName("HeroTab_ascension");Check(Visible(UI.Q("HeroAscendAction"))&&!UI.Q<Button>("HeroAscendAction").enabledInHierarchy&&Game.ReviewState.WalletGold==gold,"low-level ascension remains gated without spending");yield return Capture("growth-rank-native");
            yield return ClickName("growth-select-orwin");Check(UI.Q<Button>("HeroTab_ascension").ClassListContains("is-selected")&&UI.Q("HeroAscendAction")!=null&&Game.ReviewState.WalletGold==gold,"hero switch retains selected growth tab");yield return ClickName("growth-select-mira");yield return ClickName("HeroTab_equipment");
            int attack=Game.Simulation.Battle.Heroes.First(h=>h.Id=="mira").Attack;
            Check(Visible(UI.Q<Button>("hero-gear-enhance-weapon")),"weapon enhancement visible without wheel search");
            yield return ClickName("hero-gear-enhance-weapon");Check(Game.ReviewState.WalletGold<gold&&Game.Simulation.Battle.Heroes.First(h=>h.Id=="mira").Attack>attack,"selected hero enhancement drives combat profile");
            yield return new WaitForSecondsRealtime(.2f);
            Check(Visible(UI.Q("HeroGear_weapon")),"growth retains gear section after enhancement");
            yield return Capture("growth-gear-native");yield return ClickName("HeroTab_skills");
            Check(UI.Q("PortraitContentScroll").Query<Image>().ToList().Count(i=>i.image!=null&&i.image.name.Contains("aurelia"))==4,"four original skill cards show the hero's painted sigil");
            Check(Game.Simulation.Catalog.Hero("mira")["skills"].All(s=>UI.Query<Label>().ToList().Any(l=>l.text==(string)s["skill"])),"all four original skill titles retained");
            yield return Capture("hero-skills-mira-native");yield return Click("닫기");
            yield return Click("일시정지");yield return new WaitForSecondsRealtime(2);yield return Capture("hunt-coordinated-native");
            Check(Game.Simulation.Battle.Heroes.Count==10&&Game.Simulation.EngagementEnemyCount>0&&Game.Simulation.EngagementEnemyCount<=6&&Game.Simulation.EngagementHeading.sqrMagnitude>.99f,"live ten-person coordinated engagement and heading");
            var paintedActors=FindObjectsByType<PaintedActor>();
            Check(paintedActors.Where(a=>a.IsHero).All(a=>a.HairCards==HeroDeepPresentation.For(a.ActorId).HairCards&&a.CapePoints==HeroDeepPresentation.For(a.ActorId).CapePoints),"native visible heroes use their authored cards and secondary point counts");
            Check(FindObjectsByType<PaintedFurShells>().Any(f=>f.Layers==6),"native furry hunting creatures have six sparse layers");
            float deadline=Time.realtimeSinceStartup+65;while(Game.Simulation.PacksCleared==0){if(Time.realtimeSinceStartup>deadline||Game.Simulation.Defeated)throw new InvalidOperationException("Coordinated hunt did not naturally settle a pack.");yield return null;}
            yield return Click("일시정지");Check(!Game.ReviewState.SavePending&&Game.ReviewState.Inventory().Any(i=>(string)i["origin"]=="hunt"),"coordinated natural reward persists");
            yield return Click("도전");yield return Click((string)HuntingSimulation.Canonical["zones"]["gray_meadow"]["boss"]);yield return Click("패턴 훈련");yield return Click("일시정지");
            var raid=Game.Raid;Check(!raid.StateBound,"break response fixture is unrewarded training");gold=Game.ReviewState.WalletGold;
            foreach(var hero in raid.Battle.Heroes){hero.AttackRemaining=1000;hero.Windup=-1;hero.Ultimate=100;foreach(string slot in new[]{"a1","a2"})raid.Battle.Kits[hero.Id].Cooldowns[slot]=0;}
            raid.ControlImmunity=0;raid.StartWarning((JObject)raid.Design["phases"][0]);yield return Click("일시정지");
            Check(raid.BreakSkillReady,"authored warning exposes an original stun skill");Check(UI.Q<Label>("raid-response-situation").text.Contains("무력화 지원 가능"),"native warning names actionable break response");yield return Capture("raid-break-ready-native");
            int interrupts=raid.Interrupts;double gauge=raid.BreakGauge;yield return Click("무력화 지원");
            Check(raid.Interrupts>interrupts||raid.BreakGauge>gauge,"actual pointer original skill increases stagger or interrupts");
            Check(Game.RaidResolutionVisible,"actual original-skill interrupt presents the success notice");yield return Capture("raid-resolution-native");
            Check(Game.ReviewState.WalletGold==gold&&raid.DodgeRemaining==0,"break support grants no reward or dodge immunity");
            yield return Click("일시정지");Check(RaidResponseView.Read(raid).Kind=="opening","successful break exposes original attack opportunity");yield return Capture("raid-opening-native");
            raid.ControlImmunity=6;raid.StartWarning((JObject)raid.Design["phases"][0]);for(int frame=0;frame<6;frame++)yield return null;
            Check(UI.Q<Label>("raid-response-situation").text.Contains("제어 면역")&&!raid.BreakSkillReady,"paused immune fixture shows physical movement guidance");yield return Capture("raid-movement-guidance-native");
            raid.ControlImmunity=0;raid.ApplyControl(1);
            yield return new WaitForSecondsRealtime(.12f);
            var feedback=FindAnyObjectByType<HuntingFeedback>();
            foreach(string id in new[]{"mira","orwin","kairen","valeria"})
            {
                var source=raid.Battle.Heroes.FirstOrDefault(h=>h.Id==id);var sampleBattle=raid.Battle;
                if(source==null){source=new Combatant{Id=id,Serial=9000,Hp=1,Position=raid.Battle.Heroes[0].Position};sampleBattle=new CombatEncounter();sampleBattle.Heroes.Add(source);sampleBattle.Enemies.Add(raid.Boss);}
                int hp=raid.Boss.Hp;double time=raid.Elapsed;
                // Explicit read-only presentation sample, not a rewarded cast.
                string kind=(string)((JArray)HuntingSimulation.Canonical["skill_vfx"]).First(p=>(string)p["signature"]==id+":a1")["kind"];
                bool support=kind=="heal"||kind=="barrier"||kind=="guard";
                feedback.SetRaidMode(true);
                var sample=new BattleEvent(support?(kind=="barrier"?"shield":kind):"cast",source,"a1",support?source:raid.Boss);
                var profile=new SkillVfxProfile((JObject)((JArray)HuntingSimulation.Canonical["skill_vfx"]).First(p=>(string)p["signature"]==id+":a1"));
                float flight=SkillVfxBatch.FlightDuration(profile,Vector2.Distance(source.Position,raid.Boss.Position),support);
                feedback.Observe(sample,sampleBattle);yield return new WaitForSecondsRealtime(.04f);
                if(flight>0)
                {
                    Check(feedback.PaintedFlightQuads>0&&feedback.PaintedImpactQuads==0&&feedback.AccentSkillQuads==0&&raid.Boss.Hp==hp&&raid.Elapsed==time,"native flight precedes visual impact without changing combat "+id);yield return Capture("skill-flight-"+id+"-native");
                    feedback.SetRaidMode(true);feedback.Observe(sample,sampleBattle);yield return new WaitForSecondsRealtime(flight+.04f);
                }
                Check(feedback.AccentSkillQuads>0&&feedback.HeroSigilQuads>0&&raid.Boss.Hp==hp&&raid.Elapsed==time,"native original-profile silhouette preview "+id);
                yield return Capture("skill-accent-"+id+"-native");yield return new WaitForSecondsRealtime(1.3f);
            }
            feedback.Lens.Critical();for(int frame=0;frame<2;frame++)yield return null;
            var lens=FindAnyObjectByType<UnityEngine.Rendering.Volume>().profile;
            Check(lens.TryGet<UnityEngine.Rendering.Universal.FilmGrain>(out var grain)&&grain.intensity.value>.05f&&lens.TryGet<UnityEngine.Rendering.Universal.ChromaticAberration>(out var chromatic)&&chromatic.intensity.value>0&&lens.TryGet<UnityEngine.Rendering.Universal.LensDistortion>(out var distortion)&&distortion.intensity.value<0,"native owned Volume contains the live cinematic pulse");
            Check(Time.timeScale==1&&raid.Paused,"lens sample preserves the simulation clock and time scale");yield return Capture("camera-deep-lens-native");
            yield return Click("사냥");Check(Game.Raid==null&&Game.ReviewState.WalletGold==gold,"return retains stored state");
        }
        IEnumerator MonsterFocusSuite()
        {
            Check(Game.Simulation.Battle.Enemies.Count==24,"native initial wave has 24 enemies");
            var actors=FindObjectsByType<PaintedActor>();
            foreach(string id in FallenMonsterCatalog.Ids)Check(actors.Any(a=>a.ActorId==id&&a.UsesRelief&&a.gameObject.activeInHierarchy),"native painted monster instantiated "+id);
            yield return Capture("hunt-monsters-expanded-native");
            yield return Click("사냥터");yield return Click("몬스터 도감");
            Check(FallenMonsterCatalog.Ids.All(id=>UI.Q("monster-card-"+id)?.Q<Image>()?.sprite!=null),"seven monster codex portraits loaded");
            UI.Q("monster-card-fallen_harpy").GetFirstAncestorOfType<ScrollView>().ScrollTo(UI.Q("monster-card-fallen_harpy"));yield return new WaitForSecondsRealtime(.2f);yield return Capture("monster-codex-new-species-native");yield return Click("닫기");
            long gold=Game.ReviewState.WalletGold;int packs=Game.Simulation.PacksCleared;
            yield return Click("일시정지");yield return new WaitForSecondsRealtime(8);yield return Click("일시정지");
            foreach(var enemy in Game.Simulation.Battle.Enemies.Where(e=>e.Alive))Check(Game.Simulation.ClearAt(enemy,enemy.Position),"native approach retains body clearance");
            FindAnyObjectByType<HuntingFeedback>().SetHuntZoom(2);yield return new WaitForSecondsRealtime(.3f);yield return Capture("hunt-monsters-combat-native");
            FindAnyObjectByType<HuntingFeedback>().SetHuntZoom(1);yield return Click("일시정지");
            float deadline=Time.realtimeSinceStartup+100;
            while(Game.Simulation.PacksCleared==packs){if(Time.realtimeSinceStartup>deadline||Game.Simulation.Defeated)throw new InvalidOperationException("Expanded wave did not naturally settle.");yield return null;}
            yield return Click("일시정지");
            Check(Game.ReviewState.WalletGold==gold+(int)HuntingSimulation.Canonical["zones"]["gray_meadow"]["gold"]&&!Game.ReviewState.SavePending,"expanded wave reward saved exactly once");
            yield return Capture("hunt-monsters-reward-native");
        }
        IEnumerator Suite()
        {
            Application.runInBackground=true;Application.targetFrameRate=60;AudioListener.volume=0;started=Time.realtimeSinceStartup;
            yield return new WaitForSecondsRealtime(2);Check(Mouse.current!=null&&FindAnyObjectByType<EternalBootstrap>()!=null,"real native faction entry");
            yield return Capture(resume?"native-entry-resume":"native-entry");
            yield return Click("아우렐리아"+(resume||bandStart>0?" 이어하기":" 시작"));yield return new WaitForSecondsRealtime(.4f);
            Check(Game!=null&&Game.PersistentPlayer&&(bool?)Game.ReviewState.Snapshot()["native_review_fixture"]!=true,"persistent player excludes review seed");
            yield return Click("일시정지");Check(Game.Simulation.Paused,"hunt paused through pointer");
            if(monsterFocus){yield return MonsterFocusSuite();saved=Game.ReviewState.Snapshot();yield break;}
            if(featureFocus){yield return FeatureFocusSuite();saved=Game.ReviewState.Snapshot();yield break;}
            if(raidMechanics){yield return RaidMechanicsSuite();saved=Game.ReviewState.Snapshot();yield break;}
            if(bandStart>0)
            {
                Check(Game.Simulation.Stage==bandStart&&Game.Simulation.Zone==HuntStageWorld.Zone(bandStart),"scratch previous-band runtime");yield return Capture("hunt-stage-"+bandStart+"-native");
                int previous=Game.Simulation.PacksCleared;long priorGold=Game.ReviewState.WalletGold;string oldZone=Game.Simulation.Zone;
                yield return Click("일시정지");float deadline=Time.realtimeSinceStartup+65;
                while(Game.Simulation.PacksCleared==previous||Game.Simulation.Zone==oldZone){if(Time.realtimeSinceStartup>deadline||Game.Simulation.Defeated)throw new InvalidOperationException("Natural boundary wave did not advance.");yield return null;}
                yield return Click("일시정지");
                Check(Game.Simulation.Stage==bandStart+1&&Game.Simulation.Zone==HuntStageWorld.Zone(bandStart+1),"natural stage boundary changes monster theme");
                Check(FindAnyObjectByType<HuntEnvironmentPresentation>().Zone==Game.Simulation.Zone,"natural stage boundary changes map atmosphere");
                Check(Game.ReviewState.WalletGold==priorGold+(int)HuntingSimulation.Canonical["zones"][oldZone]["gold"]&&(string)Game.ReviewState.Snapshot()["unity_last_loot"]?["zone"]==oldZone,"previous band rewards settled exactly once");
                yield return Capture("hunt-stage-"+(bandStart+1)+"-native");saved=Game.ReviewState.Snapshot();yield break;
            }
            if(resume)
            {
                var prior=JObject.Parse(File.ReadAllText(report));saved=(JObject)prior["expected"];
                Check(JToken.DeepEquals(Game.ReviewState.Snapshot(),saved),"exact saved state restored in a second process");
                Check(Game.Simulation.Zone==HuntStageWorld.Zone(1+(int)saved["unity_pack_total"]/5)&&Game.Simulation.PacksCleared==(int)saved["unity_pack_total"],"restored stage theme and hunt cursor");
                Check(Game.Simulation.Battle.Heroes.Select(h=>h.Id).SequenceEqual(Game.ReviewState.DeployedHeroes()),"restored party drives actual actors");
                Check(!Game.Simulation.Chain.Enabled,"restored chain toggle");yield return Capture("native-continued-hunt");yield break;
            }
            Check(Game.ReviewState.WalletGold==500&&Game.Simulation.Battle.Heroes.Count==10,"fresh level one party and wallet");
            Check(new[]{"orwin","caelum","kairen"}.All(OriginalCatalog.HasStyle),"three redesigned hero styles available");
            Check(FallenMonsterCatalog.Ids.All(id=>Game.Simulation.Battle.Enemies.Any(e=>e.Id==id)),"four fallen monster types spawn in the live wave");
            Check(FindAnyObjectByType<HuntEnvironmentPresentation>().HasPainting&&FindAnyObjectByType<HuntEnvironmentPresentation>().Zone=="gray_meadow","native meadow painting");yield return Capture("hunt-meadow-native");
            var feedback=FindAnyObjectByType<HuntingFeedback>();float overview=Game.BattleCamera.orthographicSize;
            Check(feedback.HuntZoom==1,"default distant overview");
            foreach(float zoom in new[]{1.5f,2f,3f})
            {
                yield return Click("×"+zoom.ToString("0.#",System.Globalization.CultureInfo.InvariantCulture));yield return new WaitForSecondsRealtime(.4f);
                Check(feedback.HuntZoom==zoom&&Math.Abs(Game.BattleCamera.orthographicSize-overview/zoom)<.04,"actual centered zoom "+zoom);yield return Capture("hunt-zoom-"+zoom.ToString("0.#",System.Globalization.CultureInfo.InvariantCulture)+"-native");
            }
            yield return Click("×1");yield return new WaitForSecondsRealtime(.3f);
            long gold=Game.ReviewState.WalletGold;
            yield return Click("빠른 성장");yield return ClickName("HeroTab_equipment");yield return Capture("native-growth");yield return ClickName("hero-gear-enhance-weapon");Check(Game.ReviewState.WalletGold<gold,"equipment enhancement spends stored wallet");yield return Click("닫기");
            yield return Click("연계 순서");yield return Click("자동 연계 ON");Check(!Game.Simulation.Chain.Enabled,"chain toggle writes player profile");yield return Click("닫기");
            yield return Click("원정대");yield return ClickName("party-slot-select-0");yield return ClickName("party-order-backward");yield return ClickName("party-preset-save");
            Check((string)Game.ReviewState.Snapshot()["unity_party_presets"]?["0"]?["heroes"]?[0]==Game.ReviewState.DeployedHeroes()[1],"party order preset persists");yield return Capture("party-formation-native");
            yield return RemoveFirstPartyHero();yield return Click("편성 저장");
            Check(Game.ReviewState.DeployedHeroes().Count==10&&Game.ReviewState.Snapshot()["unity_next_party"]!=null,"party queued while current wave remains intact");yield return Capture("native-party-edit");yield return Click("닫기");
            yield return Click("일시정지");float wait=Time.realtimeSinceStartup;
            while(Game.Simulation.PacksCleared<1&&!Game.Simulation.Defeated){if(Time.realtimeSinceStartup-wait>60)throw new InvalidOperationException("First natural hunt reward exceeded 60 seconds.");yield return null;}
            Check(Game.Simulation.PacksCleared>=1&&!Game.ReviewState.SavePending,"natural wave reward persisted");
            yield return new WaitForSecondsRealtime(.2f);yield return Click("일시정지");Check(Game.Simulation.Battle.Heroes.Count==9&&Game.ReviewState.DeployedHeroes().Count==9,"queued nine heroes applied to next wave");
            Check((int)Game.ReviewState.Snapshot()["wallet_xp"]>=22,"actual hunt grants stored XP");yield return Capture("native-player-hunt");
            Check(Game.ReviewState.Inventory().Any(i=>(string)i["origin"]=="hunt"),"natural monster drops persist in the actual bag");
            yield return Click("가방");Check(UI.Query<Button>().ToList().Any(b=>(b.text??"").StartsWith("보관함 ·")),"native bag exposes retained equipment mail");yield return Capture("hunt-loot-bag-native");yield return Click("닫기");
            yield return Click("사냥터");Check(UI.Query<Label>().ToList().Any(l=>(l.text??"").Contains("1~499")),"unified hunting stage range UI");yield return Capture("hunt-stage-ranges-native");
            yield return Click("몬스터 도감");Check(UI.Query<Label>().ToList().Count(l=>FallenMonsterCatalog.Ids.Select(FallenMonsterCatalog.Name).Contains(l.text))==4,"four names and actual painted portraits in monster guide");yield return Capture("fallen-monsters-native");yield return Click("닫기");
            yield return Click("도전");yield return Click((string)HuntingSimulation.Canonical["zones"]["gray_meadow"]["boss"]);
            Check(Game.Raid!=null&&Game.Raid.StateBound&&Game.Raid.Battle.Heroes.Count==9,"real raid uses actual party stats");long balance=Game.ReviewState.WalletGold;
            yield return Click("일시정지");yield return Click("연계 순서");yield return Click("자동 연계 OFF");yield return Click("↓");
            Check((bool?)Game.ReviewState.Snapshot()["unity_raid_chains"]?["gray_meadow"]?["enabled"]==true&&Game.Raid.Chain.Enabled&&!Game.Simulation.Chain.Enabled,"regional raid chain persists separately from hunt");
            yield return Click("닫기");yield return Click("일시정지");
            yield return Click("패턴 훈련");Check(Game.Raid!=null&&!Game.Raid.StateBound&&Game.Raid.ReviewLevel==50,"training isolates trial stats");
            Check(Game.Raid.Chain.Enabled,"saved regional chain restored on training restart");
            yield return DragStick(Vector2.left,.2f);Check(Game.Raid.ManualMovementActive&&Game.Raid.DodgeCooldown==0&&Game.ReviewState.WalletGold==balance,"training joystick and no wallet reward");yield return Click("추적 복귀");
            yield return Click("자동 회피 ON");yield return Click("카운터 연습");float cueWait=Time.realtimeSinceStartup;
            while(Game.VisibleRaidResponseKind!="counter"){if(Time.realtimeSinceStartup-cueWait>7)throw new InvalidOperationException("Authored counter response cue did not appear.");yield return null;}
            Check(Game.Raid.CounterPractice&&Game.Raid.CounterWindowOpen,"cue follows actual authored-practice timer");yield return Capture("raid-response-counter-native");
            float finishWait=Time.realtimeSinceStartup;
            while(Game.Raid.Running){if(Time.realtimeSinceStartup-finishWait>40)throw new InvalidOperationException("Natural training result exceeded 40 seconds.");yield return null;}
            yield return new WaitForSecondsRealtime(.2f);yield return Click("다시 도전");
            Check(!Game.Raid.StateBound&&Game.Raid.ReviewLevel==50&&Game.ReviewState.WalletGold==balance,"result retry preserves unrewarded training mode");
            yield return Capture("native-player-raid-training");yield return Click("사냥");Check(Game.Raid==null,"return to retained hunting");
            yield return Click("원정대");yield return Click("진영 선택 화면");yield return new WaitForSecondsRealtime(.3f);
            Check(FindAnyObjectByType<EternalBootstrap>()!=null&&Game==null,"return to faction entry");
            yield return Click("녹스페라 시작");yield return new WaitForSecondsRealtime(.3f);yield return Click("일시정지");
            Check(Game.ReviewState.Faction=="noxfera"&&Game.ReviewState.WalletGold==500&&Game.ReviewState.UnityPacks==0,"separate faction state");
            yield return Click("원정대");yield return Click("진영 선택 화면");yield return new WaitForSecondsRealtime(.3f);
            yield return Click("아우렐리아 이어하기");yield return new WaitForSecondsRealtime(.3f);yield return Click("일시정지");
            saved=Game.ReviewState.Snapshot();var store=new NativeSessionStore(NativeSessionStore.LatestPath(profile,"aurelia"),"aurelia");Check(JToken.DeepEquals(store.Read().Payload,saved),"on-disk payload equals active player state");
        }
        IEnumerator Start()
        {
            // Flatten nested enumerators so one exception becomes a bounded QA
            // failure report instead of silently abandoning a Unity coroutine.
            var stack=new System.Collections.Generic.Stack<IEnumerator>();stack.Push(Suite());
            while(stack.Count>0)
            {
                object next=null;bool moved=false;
                try{moved=stack.Peek().MoveNext();if(moved)next=stack.Peek().Current;}catch(Exception e){error=e.Message;stack.Clear();break;}
                if(!moved){stack.Pop();continue;}if(next is IEnumerator nested){stack.Push(nested);continue;}yield return next;
            }
            var result=new JObject{{"passed",error.Length==0},{"phase",monsterFocus?"monster_expansion_cp19":featureFocus?"four_reference_cp18":raidMechanics?"raid_mechanics_cp15":bandStart>0?"stage_boundary_"+bandStart:resume?"second_process_reload":"first_process"},{"error",error},{"comparisons",checks},{"elapsed_seconds",Time.realtimeSinceStartup-started},{"scratch_name",Path.GetFileName(profile.TrimEnd(Path.DirectorySeparatorChar))},{"expected",saved},{"trace",trace},{"environments",environments},{"note",monsterFocus?"Development scratch profile: seven actual painted species, 24 arrivals, legal approach and a naturally cleared wave with exactly-once stored reward. No FPS benchmark.":featureFocus?"Scratch-only real pointer hero selection, exclusive growth tabs, actual enhancement and natural hunt reward. Explicit unrewarded training warning/resources test original-skill stagger and paused immune guidance. Paused VFX samples separately show flight and impact without modifying combat; not gameplay casts or 120-skill visual acceptance. No FPS benchmark.":raidMechanics?"Development-only scratch profile. Real pointer raid selection, spread/follow controls and returns. Explicit paused level-50 training phase/telegraph fixtures test rendering; not natural phase progression or victory. No real user files or FPS benchmark.":"Development-only scratch profiles. Actual pointer zoom, ordered party preset, natural monster drops, naturally cleared 499/999 boundary waves, authored counter practice and a second process reload; no real user files or performance benchmark."}};
            File.WriteAllText(report,result.ToString());yield return new WaitForSecondsRealtime(.3f);Application.Quit(error.Length==0?0:1);
        }
    }
}
#endif
