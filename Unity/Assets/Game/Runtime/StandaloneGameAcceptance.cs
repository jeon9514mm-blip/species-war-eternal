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
        static string report,profile;static bool resume;static int bandStart;
        JObject saved;readonly JArray trace=new(),environments=new();int checks;string error="";float started;
        HuntingMigrationReview Game=>FindAnyObjectByType<HuntingMigrationReview>();
        VisualElement UI=>FindObjectsByType<UIDocument>().First(d=>d.isActiveAndEnabled).rootVisualElement;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void Install()
        {
            if(!Debug.isDebugBuild)return;var args=Environment.GetCommandLineArgs();int flag=Array.IndexOf(args,"--eternal-game-qa");if(flag<0||flag+1>=args.Length)return;
            string build=Path.GetFullPath(Path.Combine(Application.dataPath,".."))+Path.DirectorySeparatorChar;report=Path.GetFullPath(args[flag+1]);
            if(!report.StartsWith(build,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Game QA output must stay inside the build.");
            resume=args.Contains("--qa-resume");string folder=resume?(string)JObject.Parse(File.ReadAllText(report))["scratch_name"]:"qa-profiles-"+Guid.NewGuid().ToString("N");
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
            yield return null;var ui=UI;Button b=null;
            for(int attempt=0;attempt<14;attempt++)
            {
                var matches=ui.Query<Button>().ToList().Where(b=>b.enabledInHierarchy&&(prefix?(b.text??"").StartsWith(text,StringComparison.Ordinal):b.text==text)).ToArray();b=matches.FirstOrDefault(Visible);if(b!=null)break;
                var target=matches.FirstOrDefault();var scroll=target?.GetFirstAncestorOfType<ScrollView>();if(scroll==null)break;
                var center=scroll.contentViewport.worldBound.center;var point=new Vector2(center.x/ui.worldBound.width*Screen.width,(1-center.y/ui.worldBound.height)*Screen.height);
                using(StateEvent.From(Mouse.current,out var e)){Mouse.current.position.WriteValueIntoEvent(point,e);Mouse.current.scroll.WriteValueIntoEvent(new Vector2(0,-240),e);InputSystem.QueueEvent(e);}InputSystem.Update();
                for(int frame=0;frame<4;frame++)yield return null;
            }
            if(b==null)throw new InvalidOperationException("Visible enabled button not found: "+text);
            yield return Pointer(b,text);
        }
        bool Visible(VisualElement element)
        {
            if(!element.visible||element.worldBound.width<=0||element.worldBound.height<=0)return false;
            for(var p=element;p!=null;p=p.parent)if(p.resolvedStyle.display==DisplayStyle.None||p.resolvedStyle.visibility==Visibility.Hidden||p is ScrollView s&&!s.contentViewport.worldBound.Contains(element.worldBound.center))return false;
            return UI.worldBound.Contains(element.worldBound.center);
        }
        IEnumerator Pointer(VisualElement element,string label)
        {
            var ui=UI;var bound=element.worldBound;var point=new Vector2(bound.center.x/ui.worldBound.width*Screen.width,(1-bound.center.y/ui.worldBound.height)*Screen.height);
            void Queue(bool down){using(StateEvent.From(Mouse.current,out var e)){Mouse.current.position.WriteValueIntoEvent(point,e);Mouse.current.leftButton.WriteValueIntoEvent(down?1f:0f,e);InputSystem.QueueEvent(e);}InputSystem.Update();}
            Queue(true);yield return null;Queue(false);trace.Add(new JObject{{"input",label},{"frame",Time.frameCount},{"x",point.x},{"y",point.y}});
            for(int i=0;i<5;i++)yield return null;
        }
        IEnumerator FirstPartyToggle()
        {
            for(int attempt=0;attempt<14;attempt++)
            {
                var toggle=UI.Query<Toggle>().ToList().FirstOrDefault(t=>Visible(t)&&t.value);
                if(toggle!=null){yield return Pointer(toggle,"remove first visible party hero");yield break;}
                var target=UI.Query<Toggle>().ToList().FirstOrDefault(t=>t.value);var scroll=target?.GetFirstAncestorOfType<ScrollView>();if(scroll==null)break;
                var center=scroll.contentViewport.worldBound.center;var point=new Vector2(center.x/UI.worldBound.width*Screen.width,(1-center.y/UI.worldBound.height)*Screen.height);
                using(StateEvent.From(Mouse.current,out var e)){Mouse.current.position.WriteValueIntoEvent(point,e);Mouse.current.scroll.WriteValueIntoEvent(new Vector2(0,-240),e);InputSystem.QueueEvent(e);}InputSystem.Update();for(int frame=0;frame<4;frame++)yield return null;
            }
            throw new InvalidOperationException("Visible chosen party toggle not found.");
        }
        IEnumerator Capture(string name)
        {
            yield return new WaitForEndOfFrame();var world=FindAnyObjectByType<HuntEnvironmentPresentation>();
            if(world!=null){var texture=Resources.Load<Texture2D>(world.ArtResource);environments.Add(new JObject{{"capture",name},{"zone",world.Zone},{"painting_active",world.HasPainting},{"width",texture.width},{"height",texture.height},{"runtime_format",texture.format.ToString()}});}
            ScreenCapture.CaptureScreenshot(Path.Combine(Path.GetDirectoryName(report),name+".png"));yield return new WaitForSecondsRealtime(.3f);
        }
        IEnumerator Suite()
        {
            Application.runInBackground=true;Application.targetFrameRate=60;AudioListener.volume=0;started=Time.realtimeSinceStartup;
            yield return new WaitForSecondsRealtime(2);Check(Mouse.current!=null&&FindAnyObjectByType<EternalBootstrap>()!=null,"real native faction entry");
            yield return Capture(resume?"native-entry-resume":"native-entry");
            yield return Click("아우렐리아"+(resume||bandStart>0?" 이어하기":" 시작"));yield return new WaitForSecondsRealtime(.4f);
            Check(Game!=null&&Game.PersistentPlayer&&(bool?)Game.ReviewState.Snapshot()["native_review_fixture"]!=true,"persistent player excludes review seed");
            yield return Click("일시정지");Check(Game.Simulation.Paused,"hunt paused through pointer");
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
            yield return Click("빠른 성장");yield return Capture("native-growth");yield return Click("강화 ·",true);Check(Game.ReviewState.WalletGold<gold,"equipment enhancement spends stored wallet");yield return Click("닫기");
            yield return Click("연계 순서");yield return Click("자동 연계 ON");Check(!Game.Simulation.Chain.Enabled,"chain toggle writes player profile");yield return Click("닫기");
            yield return Click("원정대");yield return Click("뒤로");yield return Click("편성 1 저장");
            Check((string)Game.ReviewState.Snapshot()["unity_party_presets"]?["0"]?["heroes"]?[0]==Game.ReviewState.DeployedHeroes()[1],"party order preset persists");yield return Capture("party-formation-native");
            yield return FirstPartyToggle();yield return Click("편성 저장");
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
            yield return Click("긴급 회피");Check(Game.Raid.DodgeCooldown>0&&Game.ReviewState.WalletGold==balance,"training controls and no wallet reward");
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
            var result=new JObject{{"passed",error.Length==0},{"phase",bandStart>0?"stage_boundary_"+bandStart:resume?"second_process_reload":"first_process"},{"error",error},{"comparisons",checks},{"elapsed_seconds",Time.realtimeSinceStartup-started},{"scratch_name",Path.GetFileName(profile.TrimEnd(Path.DirectorySeparatorChar))},{"expected",saved},{"trace",trace},{"environments",environments},{"note","Development-only scratch profiles. Actual pointer zoom, ordered party preset, natural monster drops, naturally cleared 499/999 boundary waves, authored counter practice and a second process reload; no real user files or performance benchmark."}};
            File.WriteAllText(report,result.ToString());yield return new WaitForSecondsRealtime(.3f);Application.Quit(error.Length==0?0:1);
        }
    }
}
#endif
