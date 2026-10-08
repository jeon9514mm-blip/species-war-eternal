#if UNITY_EDITOR || DEBUG
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using Newtonsoft.Json.Linq;
#if UNITY_EDITOR
using UnityEditor;
#endif
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace Eternal.UnityMigration.Editor
{
    // Real Input System press/release events separated by advancing native
    // frames. No button callback, simulation command or player save is invoked
    // directly. Allowed only against the explicit in-memory review seed.
    public static class NativeInputAcceptance
    {
        static readonly List<(string label,Func<bool> action)> steps=new();
        static readonly JArray trace=new(),raids=new();
        static HuntingMigrationReview review;
        static int index,lastFrame,delayFrames,checks,startFrame;
        static bool running,pressed;
        static Vector2 pointer;
        static float started,waitStarted;
        static int offense,attack,itemLevel,itemCost,huntTicks;
        static long gold;
        static string itemId;
        static ChainSkill[] chain;
        static int guardianCopies,heroShards;
        static string equipGuardian;
        static Mouse qaMouse;
        static bool counterRally;
        public static string ReportPath = "../checks/unity-migration-2026-10-08/native-ui-input.json";
        public static bool Running => running;
        public static string Begin()
        {
            if(running)throw new InvalidOperationException("Native input acceptance is already running.");
            review=UnityEngine.Object.FindAnyObjectByType<HuntingMigrationReview>();
            if(!Application.isPlaying||review?.ReviewState==null||(bool?)review.ReviewState.Snapshot()["native_review_fixture"]!=true)throw new InvalidOperationException("A fresh native in-memory review is required.");
            if(Mouse.current==null&&Application.isBatchMode)qaMouse=InputSystem.AddDevice<Mouse>("Isolated review QA mouse");
            if(Mouse.current==null)throw new InvalidOperationException("An Input System mouse is required.");
            steps.Clear();trace.Clear();raids.Clear();index=delayFrames=checks=0;lastFrame=-1;startFrame=Time.frameCount;started=Time.realtimeSinceStartup;pressed=false;
            Add("open hero navigation",()=>ClickText("영웅"));
            Add("open original Leonhardt portrait",()=>ClickData("leonhardt"));
            Add("open growth panel",()=>ClickText("성장 · 장비"));
            Add("capture research state",()=>{offense=review.ReviewState.HeroTree("leonhardt").offense;attack=review.Simulation.Battle.Heroes.First(h=>h.Id=="leonhardt").Attack;});
            Add("research offense through pointer",()=>ClickText("연구 +1",0));
            Add("verify research affects same live actor",()=>{Require(review.ReviewState.HeroTree("leonhardt").offense==offense+1,"research rank");Require(review.Simulation.Battle.Heroes.First(h=>h.Id=="leonhardt").Attack>attack,"live attack growth");});
            Add("open bag navigation",()=>ClickText("가방"));
            Add("capture bag state",()=>{gold=review.ReviewState.WalletGold;});
            Add("recommended equipment through pointer",()=>ClickText("추천 장착"));
            Add("verify recommendation preserves wallet and protected gear",()=>
            {
                var bag=review.ReviewState.Inventory();Require(bag.Count==5,"bag capacity");Require(review.ReviewState.WalletGold==gold,"recommendation wallet");Require(bag.Any(i=>(string)i["id"]=="native_review_gear_4"),"protected raid gear");Require(review.ReviewState.EquipmentPower("leonhardt")>50,"equipment refresh");itemId=(string)bag[0]["id"];
            });
            Add("select displaced equipment",()=>ClickData(itemId));
            Add("capture equipment enhancement",()=>{var item=Item();itemLevel=(int)item["level"];itemCost=LegacyGrowthEconomy.EquipmentCost((string)item["slot"],itemLevel);gold=review.ReviewState.WalletGold;});
            Add("enhance equipment through pointer",()=>ClickPrefix("강화 ·"));
            Add("verify exact enhancement level and cost",()=>{Require((int)Item()["level"]==itemLevel+1,"enhancement level");Require(review.ReviewState.WalletGold==gold-itemCost,"enhancement cost");});
            Add("lock gear through pointer",()=>ClickText("장비 잠금"));
            Add("verify lock disables decomposition",()=>{Require((bool)Item()["locked"],"gear lock");var b=Buttons().First(x=>((string)x["text"]).StartsWith("분해 ·",StringComparison.Ordinal));Require(!(bool)b["enabled"],"locked salvage disabled");});
            Add("unlock through pointer",()=>ClickText("잠금 해제"));
            Add("verify unlock",()=>Require(!(bool)Item()["locked"],"gear unlock"));
            Add("open skill-chain editor",()=>ClickText("연계 순서"));
            Add("capture chain order",()=>chain=review.Simulation.Chain.Entries.ToArray());
            Add("reorder chain through pointer",()=>ClickText("↓",0));
            Add("verify reordered chain",()=>{var entries=review.Simulation.Chain.Entries;Require(entries[0].Equals(chain[1])&&entries[1].Equals(chain[0]),"chain order");});
            Add("disable auto chain through pointer",()=>ClickText("자동 연계 ON"));
            Add("verify disabled chain",()=>Require(!review.Simulation.Chain.Enabled,"auto chain off"));
            Add("enable auto chain through pointer",()=>ClickText("자동 연계 OFF"));
            Add("verify enabled chain",()=>Require(review.Simulation.Chain.Enabled,"auto chain on"));
            Add("open state menu",()=>ClickText("메뉴"));
            Add("open summon panel",()=>ClickText("소환 · 수호신"));
            Add("capture free guardian state",()=>{gold=review.ReviewState.WalletGems;guardianCopies=review.ReviewState.OwnedGuardians().Sum(review.ReviewState.GuardianCopies);});
            Add("free guardian summon through pointer",()=>ClickText("첫 무료 수호신 소환"));
            Add("verify free guardian copy and wallet",()=>{Require(!review.ReviewState.GuardianFreeAvailable,"free summon consumed once");Require(review.ReviewState.WalletGems==gold,"free guardian wallet");Require(review.ReviewState.OwnedGuardians().Sum(review.ReviewState.GuardianCopies)==guardianCopies+1,"guardian copy awarded");});
            Add("capture original hero shard total",()=>heroShards=((JObject)review.ReviewState.Snapshot()["hero_shards"]).Properties().Sum(p=>(int)p.Value));
            Add("hero shard summon through pointer",()=>ClickText("영웅 조각 소환 · 젬 100"));
            Add("verify hero shards and exact currency",()=>{Require(review.ReviewState.WalletGems==gold-100,"hero summon currency");Require(((JObject)review.ReviewState.Snapshot()["hero_shards"]).Properties().Sum(p=>(int)p.Value)==heroShards+12,"hero shards awarded");});
            Add("open owned guardians",()=>ClickText("보유 수호신"));
            Add("equip another owned guardian if drawn",()=>{equipGuardian=review.ReviewState.OwnedGuardians().FirstOrDefault(id=>id!=review.ReviewState.EquippedGuardian);if(equipGuardian!=null)ClickText("수호신 장착");});
            Add("verify guardian equipment if applicable",()=>{if(equipGuardian!=null)Require(review.ReviewState.EquippedGuardian==equipGuardian,"guardian equipped");});
            var zones=JObject.Parse(OriginalCatalog.Required("legacy-catalogs").text)["zones"];
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                string current=zone;
                Add("open raid navigation "+zone,()=>ClickText("도전"));
                Add("capture retained hunt "+zone,()=>huntTicks=review.Simulation.Ticks);
                Add("enter regional boss "+zone,()=>ClickText((string)zones[current]["boss"]));
                Add("verify native raid route "+zone,()=>{Require(review.Raid?.Zone==current&&review.Raid.Running,"raid route");Require(review.Simulation.Ticks>=huntTicks,"hunt retained at transition");huntTicks=review.Simulation.Ticks;});
                Add("verify hunting remains suspended during raid "+zone,()=>Require(review.Simulation.Ticks==huntTicks,"hunt suspended"));
                Add("dodge through pointer "+zone,()=>ClickText("긴급 회피"));
                Add("verify dodge cooldown "+zone,()=>Require(review.Raid.DodgeCooldown>0,"raid dodge"));
                Add("rally through ground pointer "+zone,()=>ClickGround(new Vector2(-3,0)));
                Add("verify rally destination "+zone,()=>
                {
                    var field=typeof(RaidSimulation).GetField("rallyGoal",BindingFlags.Instance|BindingFlags.NonPublic);var value=(Vector2)field.GetValue(review.Raid);
                    Require(Vector2.Distance(value,new Vector2(-3,0))<.05f,"ground rally projection");
                });
                if(zone=="moonrest_forest")
                {
                    waitStarted=0;counterRally=false;
                    steps.Add(("observe counter opportunity",()=>
                    {
                        if(waitStarted==0)waitStarted=Time.realtimeSinceStartup;
                        if(!counterRally&&review.Raid.Warning?.Shape=="cone"&&review.Raid.TelegraphRemaining>.55)
                        {ClickGround(review.Raid.Warning.Center+review.Raid.Warning.Direction*4.5f);counterRally=true;return false;}
                        var button=Buttons().FirstOrDefault(b=>(string)b["text"]=="카운터"&&(bool)b["enabled"]);
                        if(review.Raid.CounterReady&&button!=null){Click(button,"카운터");return true;}
                        if(!review.Raid.Running||Time.realtimeSinceStartup-waitStarted>20)return true;return false;
                    }));
                }
                Add("record raid input evidence "+zone,()=>raids.Add(new JObject{{"zone",current},{"dodge_verified",true},{"rally_verified",true},{"native_ticks",review.Raid.Ticks},{"counter_successes",review.Raid.CounterSuccesses},{"counter_input_success_verified",review.Raid.CounterSuccesses>0}}));
                Add("return to hunting through pointer "+zone,()=>ClickText("사냥"));
                Add("verify retained hunting "+zone,()=>{Require(review.Raid==null,"return route");Require(review.Simulation.Ticks>=huntTicks,"retained hunt");});
            }
            running=true;
#if UNITY_EDITOR
            EditorApplication.update+=Tick;
#endif
            return "Native Input System UI acceptance started; poll Status().";
        }
        static JObject Item()=>review.ReviewState.Inventory().First(i=>(string)i["id"]==itemId);
        static void Add(string label,Action action)=>steps.Add((label,()=>{action();return true;}));
        static void Require(bool condition,string label){checks++;if(!condition)throw new InvalidOperationException("Native input assertion failed: "+label);}
        static IEnumerable<JObject> Buttons()=>((JArray)JObject.Parse(NativeUiVerification.Inspect())["buttons"]).Cast<JObject>();
        static void ClickText(string text,int ordinal=0)=>Click(Buttons().Where(b=>(string)b["text"]==text).Skip(ordinal).FirstOrDefault(),text);
        static void ClickPrefix(string prefix)=>Click(Buttons().FirstOrDefault(b=>((string)b["text"]).StartsWith(prefix,StringComparison.Ordinal)),prefix);
        static void ClickData(string id)=>Click(Buttons().FirstOrDefault(b=>(string)b["data"]==id),id);
        static void Click(JObject button,string label)
        {
            if(button==null||!(bool)button["enabled"])throw new InvalidOperationException("Visible enabled native button not found: "+label);
            pointer=new Vector2((float)button["x"],(float)button["y"]);QueueMouse(true);pressed=true;
            trace.Add(new JObject{{"input","mouse_down"},{"label",label},{"x",pointer.x},{"y",pointer.y},{"frame",Time.frameCount}});
        }
        static void ClickGround(Vector2 point)
        {
            var screen=review.BattleCamera.WorldToScreenPoint(new Vector3(point.x,0,point.y));pointer=new Vector2(screen.x,screen.y);QueueMouse(true);pressed=true;
            trace.Add(new JObject{{"input","mouse_down_ground"},{"x",pointer.x},{"y",pointer.y},{"frame",Time.frameCount}});
        }
        static void QueueMouse(bool down)
        {
            using(StateEvent.From(Mouse.current,out var eventPtr)){Mouse.current.position.WriteValueIntoEvent(pointer,eventPtr);Mouse.current.leftButton.WriteValueIntoEvent(down?1f:0f,eventPtr);InputSystem.QueueEvent(eventPtr);}
            InputSystem.Update();
        }
        public static void Tick()
        {
            if(!running)return;
            if(!Application.isPlaying){Finish(false,"Play mode ended before UI acceptance completed.");return;}
            if(lastFrame==Time.frameCount)return;lastFrame=Time.frameCount;
            try
            {
                if(Time.realtimeSinceStartup-started>120)throw new InvalidOperationException("Native input acceptance exceeded 120 seconds.");
                if(pressed){QueueMouse(false);pressed=false;delayFrames=2;return;}
                if(delayFrames>0){delayFrames--;return;}
                if(index>=steps.Count){Finish(true,"");return;}
                if(steps[index].action()){trace.Add(new JObject{{"step",steps[index].label},{"frame",Time.frameCount}});index++;}
            }
            catch(Exception error){Finish(false,error.Message);}
        }
        static void Finish(bool passed,string error)
        {
#if UNITY_EDITOR
            EditorApplication.update-=Tick;
#endif
            if(pressed&&Mouse.current!=null){QueueMouse(false);pressed=false;}running=false;
            var report=new JObject{{"passed",passed},{"error",error},{"comparisons",checks},{"steps_completed",index},{"steps_total",steps.Count},{"start_frame",startFrame},{"end_frame",Time.frameCount},{"elapsed_seconds",Time.realtimeSinceStartup-started},{"batch_editor",Application.isBatchMode},{"virtual_qa_mouse",qaMouse!=null},{"trace",trace.DeepClone()},{"raid_inputs",raids.DeepClone()},{"no_direct_ui_callbacks",true},{"real_player_io",false},{"note","Editor QA dispatches actual Input System mouse events across native frames. Batch Editor creates a virtual mouse when no hardware mouse exists and removes it afterward. Tests run only against the explicit memory-only review seed. Counter success is reported separately and may remain unverified if no eligible window occurred."}};
            report["development_player"]=!Application.isEditor&&Debug.isDebugBuild;
            File.WriteAllText(ReportPath,report.ToString());Debug.Log((passed?"ETERNAL_NATIVE_INPUT_PASSED ":"ETERNAL_NATIVE_INPUT_FAILED ")+error);
            if(qaMouse!=null){InputSystem.RemoveDevice(qaMouse);qaMouse=null;}
        }
        public static string Status()
        {if(running)return new JObject{{"running",true},{"step",index},{"total",steps.Count},{"label",index<steps.Count?steps[index].label:"done"},{"frames",Time.frameCount-startFrame}}.ToString();return File.Exists(ReportPath)?File.ReadAllText(ReportPath):"Not started.";}
    }
}
#endif
