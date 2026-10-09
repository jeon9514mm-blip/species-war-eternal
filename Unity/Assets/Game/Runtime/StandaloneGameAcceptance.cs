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
        static string report,profile;static bool resume;
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
            yield return Click("아우렐리아"+(resume?" 이어하기":" 시작"));yield return new WaitForSecondsRealtime(.4f);
            Check(Game!=null&&Game.PersistentPlayer&&(bool?)Game.ReviewState.Snapshot()["native_review_fixture"]!=true,"persistent player excludes review seed");
            yield return Click("일시정지");Check(Game.Simulation.Paused,"hunt paused through pointer");
            if(resume)
            {
                var prior=JObject.Parse(File.ReadAllText(report));saved=(JObject)prior["expected"];
                Check(JToken.DeepEquals(Game.ReviewState.Snapshot(),saved),"exact saved state restored in a second process");
                Check(Game.Simulation.Zone==(string)saved["unity_hunt_zone"]&&Game.Simulation.PacksCleared==(int)saved["unity_pack_total"],"restored zone and hunt cursor");
                Check(Game.Simulation.Battle.Heroes.Select(h=>h.Id).SequenceEqual(Game.ReviewState.DeployedHeroes()),"restored party drives actual actors");
                Check(!Game.Simulation.Chain.Enabled,"restored chain toggle");yield return Capture("native-continued-hunt");yield break;
            }
            Check(Game.ReviewState.WalletGold==500&&Game.Simulation.Battle.Heroes.Count==10,"fresh level one party and wallet");
            Check(FindAnyObjectByType<HuntEnvironmentPresentation>().HasPainting&&FindAnyObjectByType<HuntEnvironmentPresentation>().Zone=="gray_meadow","native meadow painting");yield return Capture("hunt-meadow-native");
            long gold=Game.ReviewState.WalletGold;
            yield return Click("빠른 성장");yield return Capture("native-growth");yield return Click("강화 ·",true);Check(Game.ReviewState.WalletGold<gold,"equipment enhancement spends stored wallet");yield return Click("닫기");
            yield return Click("연계 순서");yield return Click("자동 연계 ON");Check(!Game.Simulation.Chain.Enabled,"chain toggle writes player profile");yield return Click("닫기");
            yield return Click("원정대");var toggle=UI.Query<Toggle>().ToList().First(t=>Visible(t)&&t.value);yield return Pointer(toggle,"remove first party hero");yield return Click("편성 저장");
            Check(Game.ReviewState.DeployedHeroes().Count==10&&Game.ReviewState.Snapshot()["unity_next_party"]!=null,"party queued while current wave remains intact");yield return Capture("native-party-edit");yield return Click("닫기");
            yield return Click("일시정지");float wait=Time.realtimeSinceStartup;
            while(Game.Simulation.PacksCleared<1&&!Game.Simulation.Defeated){if(Time.realtimeSinceStartup-wait>60)throw new InvalidOperationException("First natural hunt reward exceeded 60 seconds.");yield return null;}
            Check(Game.Simulation.PacksCleared>=1&&!Game.ReviewState.SavePending,"natural wave reward persisted");
            yield return new WaitForSecondsRealtime(.2f);yield return Click("일시정지");Check(Game.Simulation.Battle.Heroes.Count==9&&Game.ReviewState.DeployedHeroes().Count==9,"queued nine heroes applied to next wave");
            Check((int)Game.ReviewState.Snapshot()["wallet_xp"]>=22,"actual hunt grants stored XP");yield return Capture("native-player-hunt");
            yield return Click("사냥터");yield return Click((string)HuntingSimulation.Canonical["zones"]["forgotten_mine"]["name"]);yield return Click("일시정지");
            Check(Game.Simulation.Zone=="forgotten_mine","native zone travel");
            Check(FindAnyObjectByType<HuntEnvironmentPresentation>().HasPainting&&FindAnyObjectByType<HuntEnvironmentPresentation>().Zone=="forgotten_mine","native mine painting");yield return Capture("hunt-mine-native");
            yield return Click("사냥터");yield return Click((string)HuntingSimulation.Canonical["zones"]["moonrest_forest"]["name"]);yield return Click("일시정지");
            Check(FindAnyObjectByType<HuntEnvironmentPresentation>().HasPainting&&FindAnyObjectByType<HuntEnvironmentPresentation>().Zone=="moonrest_forest","native moonlit forest painting");yield return Capture("hunt-forest-native");
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
            var result=new JObject{{"passed",error.Length==0},{"phase",resume?"second_process_reload":"first_process"},{"error",error},{"comparisons",checks},{"elapsed_seconds",Time.realtimeSinceStartup-started},{"scratch_name",Path.GetFileName(profile.TrimEnd(Path.DirectorySeparatorChar))},{"expected",saved},{"trace",trace},{"environments",environments},{"note","Development-only scratch profiles. Actual Input System pointer actions, authored counter practice, training-result retry and a second process reload; no real user files or performance benchmark."}};
            File.WriteAllText(report,result.ToString());yield return new WaitForSecondsRealtime(.3f);Application.Quit(error.Length==0?0:1);
        }
    }
}
#endif
