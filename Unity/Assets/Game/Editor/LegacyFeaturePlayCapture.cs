using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration.Editor
{
    [InitializeOnLoad]
    public static class LegacyFeaturePlayCapture
    {
        const string Active="Eternal.LegacyCapture.Active",Output="Eternal.LegacyCapture.Output";
        static readonly JArray shots=new();
        static readonly List<string> errors=new(),editorErrors=new();
        static HuntingMigrationReview game;
        static EditorWindow view;
        static int phase;
        static double next,deadline;
        static string pending;
        static readonly string[] names={"hunt","dungeons","war","goals","market","presets","practice","dungeon-battle","raid-battle","noxfera"};
        static LegacyFeaturePlayCapture()
        {EditorApplication.playModeStateChanged+=state=>{if(SessionState.GetBool(Active,false)&&state==PlayModeStateChange.EnteredPlayMode)Resume();};if(SessionState.GetBool(Active,false))EditorApplication.delayCall+=Resume;}
        public static void Begin()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Requires an idle capture checkout editor.");
            var args=Environment.GetCommandLineArgs();int index=Array.IndexOf(args,"-legacyCaptureOutput");string path=Path.GetFullPath(index>=0&&index+1<args.Length?args[index+1]:Path.Combine(Application.dataPath,"../../../native-legacy-play-capture"));Directory.CreateDirectory(path);SessionState.SetString(Output,path);SessionState.SetBool(Active,true);
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);ConfigureView();EditorApplication.EnterPlaymode();
        }
        static void ConfigureView()
        {
            Type type=typeof(UnityEditor.Editor).Assembly.GetType("UnityEditor.GameView",true);view=EditorWindow.GetWindow(type);view.Show();view.Focus();var assembly=type.Assembly;var sizesType=assembly.GetType("UnityEditor.GameViewSizes",true);var singleton=typeof(ScriptableSingleton<>).MakeGenericType(sizesType);object sizes=singleton.GetProperty("instance",BindingFlags.Public|BindingFlags.Static).GetValue(null);var groupType=assembly.GetType("UnityEditor.GameViewSizeGroupType",true);object group=sizesType.GetMethod("GetGroup").Invoke(sizes,new[]{Enum.Parse(groupType,EditorUserBuildSettings.activeBuildTarget==BuildTarget.Android?"Android":"Standalone")});var sizeType=assembly.GetType("UnityEditor.GameViewSize",true);var kindType=assembly.GetType("UnityEditor.GameViewSizeType",true);object size=Activator.CreateInstance(sizeType,BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance,null,new[]{Enum.Parse(kindType,"FixedResolution"),(object)1600,900,"Native feature capture 1600x900"},null);group.GetType().GetMethod("AddCustomSize").Invoke(group,new[]{size});int count=(int)group.GetType().GetMethod("GetTotalCount").Invoke(group,null);type.GetProperty("selectedSizeIndex",BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance).SetValue(view,count-1);view.Repaint();
        }
        static void Resume()
        {
            if(!EditorApplication.isPlaying)return;phase=-1;pending=null;errors.Clear();editorErrors.Clear();shots.Clear();game=null;deadline=EditorApplication.timeSinceStartup+180;next=EditorApplication.timeSinceStartup+2;Application.runInBackground=true;AudioListener.volume=0;Application.logMessageReceived-=Log;Application.logMessageReceived+=Log;EditorApplication.update-=Tick;EditorApplication.update+=Tick;ConfigureView();
        }
        static object Invoke(string name,params object[] args)=>typeof(HuntingMigrationReview).GetMethod(name,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(game,args);
        static void Tick()
        {
            try
            {
                if(!EditorApplication.isPlaying)return;if(EditorApplication.timeSinceStartup>deadline){errors.Add("Play capture timeout");Finish();return;}view?.Repaint();EditorApplication.QueuePlayerLoopUpdate();
                if(game==null)
                {
                    var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);var payload=NativePlayerSession.NewPayload(catalog,"aurelia");foreach(string hero in catalog.HeroIds.Where(h=>(string)catalog.Hero(h)["faction"]=="aurelia"))payload["hero_progress"][hero]["level"]=20;payload["gear_auto_equip"]=false;
                    string path=Path.Combine(SessionState.GetString(Output,""),"isolated-test-profile-"+Guid.NewGuid().ToString("N")+".json");var store=new NativeSessionStore(path,"aurelia");if(!store.Write(payload))throw new IOException("Isolated capture profile write failed");var session=new NativePlayerSession(catalog,payload,store);session.State.InitializeWar();session.State.SaveCombatPreset(0);game=new GameObject("Isolated native feature capture").AddComponent<HuntingMigrationReview>();game.BindPlayerSession(session);next=EditorApplication.timeSinceStartup+3;return;
                }
                if(game.Simulation==null||Screen.width!=1600||Screen.height!=900)return;
                if(EditorApplication.timeSinceStartup<next)return;
                if(pending!=null)
                {if(!File.Exists(pending)||new FileInfo(pending).Length<1024)return;pending=null;phase++;next=EditorApplication.timeSinceStartup+.7;if(phase>=names.Length){Finish();return;}}
                if(phase<0){phase=0;next=EditorApplication.timeSinceStartup+.7;return;}
                if(phase==0)Invoke("OpenPanel","사냥");else if(phase==1)Invoke("OpenPanel","던전");else if(phase==2)Invoke("OpenPanel","진영전");else if(phase==3)Invoke("ShowGoals","guide");else if(phase==4)Invoke("ShowMarket");else if(phase==5)Invoke("ShowCombatPresets");else if(phase==6)Invoke("ShowPractice");else if(phase==7){Invoke("StartChallenge","daily","gold_rush");game.Simulation.Paused=true;}else if(phase==8){Invoke("OpenPanel","사냥");game.StartRaid("gray_meadow",20,true);game.Raid.Paused=true;}else if(phase==9){game.EndRaid();Invoke("OpenPanel","사냥");var switched=game.ReviewState.SwitchAccountFaction("noxfera");if(!switched.Ok||switched.SavePending)throw new InvalidOperationException("Capture faction switch failed");Invoke("RestartPlayerHunt",false);game.Simulation.Paused=true;}
                var root=game.GetComponent<UIDocument>().rootVisualElement;var photographed=game.RoyalHud.GetComponent<UIDocument>().rootVisualElement;bool footer=new[]{"사냥","영웅","레이드","던전","진영전","가방"}.All(r=>photographed.Q<Button>("grove-navigation-"+r)!=null);if(!footer)errors.Add("Six native footer routes missing");if(phase==2&&root.Q("native-war-map")==null)errors.Add("Native war grid absent");if(phase==7&&game.Simulation.Challenge==null)errors.Add("Native dungeon combat absent");
                pending=Path.Combine(SessionState.GetString(Output,""),names[phase]+".png");ScreenCapture.CaptureScreenshot(pending);shots.Add(new JObject{{"file",names[phase]+".png"},{"screen_width",Screen.width},{"screen_height",Screen.height},{"native_party",game.ActiveBattle.Heroes.Count},{"native_heroes",new JArray(game.ActiveBattle.Heroes.Select(h=>h.Id))},{"six_footer_routes",footer},{"photographed_unity_hud",photographed.Q("grove-hero-rail")!=null},{"old_dock_hidden",root.Q("foot").resolvedStyle.display==DisplayStyle.None},{"simulation_ticks",game.Simulation.Ticks},{"save_pending",game.ReviewState.SavePending},{"actual_play_mode",EditorApplication.isPlaying}});next=EditorApplication.timeSinceStartup+1;
            }
            catch(Exception e){errors.Add(e.ToString());Finish();}
        }
        static void Log(string message,string stack,LogType type){if(type!=LogType.Error&&type!=LogType.Exception)return;if(stack.Contains("UnityEditor.Search.")){editorErrors.Add(message+"\n"+stack);return;}if(errors.Count<30)errors.Add(message+"\n"+stack);}
        static void Finish()
        {EditorApplication.update-=Tick;Application.logMessageReceived-=Log;SessionState.SetBool(Active,false);var report=new JObject{{"completed",shots.Count==names.Length&&errors.Count==0},{"captures",shots},{"errors",new JArray(errors)},{"editor_search_errors",new JArray(editorErrors)},{"note","Actual Unity Play-mode Game view. Isolated Lv20 test profile in this output directory. Published baseline art unchanged; no production APK or user save changed. Dungeon battle is paused for a readable frame."}};File.WriteAllText(Path.Combine(SessionState.GetString(Output,""),"capture-report.json"),report.ToString());Debug.Log("LEGACY_FEATURE_PLAY_CAPTURE: "+report["completed"]);EditorApplication.Exit(errors.Count==0?0:1);}
    }
}
