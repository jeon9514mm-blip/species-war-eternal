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
using UnityEngine.UIElements;

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
        static int rewardPacks,rewardGold,rewardXp;
        static long walletXp;
        static string itemId;
        static string manualHero,manualSlot;
        static int manualBefore;
        static ChainSkill[] chain;
        static int guardianCopies,heroShards;
        static string equipGuardian;
        static Mouse qaMouse;
        static bool counterRally;
        static bool counterWindowCaptured;
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
            Add("expand manual skill strip through native pointer",()=>ClickName("hunt-chain-expand"));
            Add("verify party labels do not overlap after font import",()=>
            {
                var ui=review.GetComponent<UnityEngine.UIElements.UIDocument>().rootVisualElement;
                foreach(var hero in review.Simulation.Battle.Heroes)
                {
                    var card=ui.Q<UnityEngine.UIElements.Button>("party-card-"+hero.Id);
                    var name=card.Q<UnityEngine.UIElements.Label>("party-name").worldBound;
                    var hp=card.Q<UnityEngine.UIElements.Label>("party-health").worldBound;
                    var skill=card.Q<UnityEngine.UIElements.Label>("party-skills").worldBound;
                    Require(name.height>0&&hp.height>0&&skill.height>0,"visible party labels "+hero.Id);
                    Require(name.yMax<=hp.yMin+.1f&&hp.yMax<=skill.yMin+.1f,"separate party text rows "+hero.Id);
                }
                for(int i=0;i<review.Simulation.Chain.Entries.Count;i++)
                {
                    var tile=ui.Q<Button>("manual-chain-"+i);var title=tile.Q<Label>("chain-title").worldBound;var readiness=tile.Q<Label>("chain-ready").worldBound;
                    Require(title.yMax<=readiness.yMin+.1f&&readiness.yMax<=tile.worldBound.yMax+.1f,"chain labels remain inside tile "+i);
                }
            });
            Add("observe manual chain input availability",()=>waitStarted=Time.realtimeSinceStartup);
            steps.Add(("cast a ready chain tile through native pointer",()=>
            {
                var ui=review.GetComponent<UIDocument>().rootVisualElement;
                for(int i=0;i<review.Simulation.Chain.Entries.Count;i++)
                {
                    var entry=review.Simulation.Chain.Entries[i];var actor=review.Simulation.Battle.Heroes.First(h=>h.Id==entry.Hero);
                    var card=ui.Q<Button>("manual-chain-"+i);
                    if(actor.Windup>=0||!review.Simulation.CanManualCast(entry.Hero,entry.Slot)||!card.enabledInHierarchy)continue;
                    manualHero=entry.Hero;manualSlot=entry.Slot;manualBefore=review.Simulation.ManualSkillCasts;ClickData("manual-chain-"+i);return true;
                }
                if(Time.realtimeSinceStartup-waitStarted>20)throw new InvalidOperationException("No ready manual chain tile within 20 seconds.");return false;
            }));
            Add("verify exact manual route played an original skill",()=>{Require(review.Simulation.ManualSkillCasts==manualBefore+1,"native manual skill count");Require(review.Simulation.Battle.Kits[manualHero].Casts.GetValueOrDefault(manualSlot)>0,"native original skill execution");});
            Add("capture actual manual skill strip",()=>ScreenCapture.CaptureScreenshot(Path.Combine(Path.GetDirectoryName(ReportPath),"native-chain-strip.png")));
            Add("fold manual skill strip through native pointer",()=>ClickName("hunt-chain-expand"));
            Navigate("open hero navigation","영웅");
            Add("open original Leonhardt portrait",()=>ClickName("HeroRoster_leonhardt"));
            Add("open original skills tab",()=>ClickName("HeroTab_skills"));
            Add("verify original four skill identities",()=>
            {
                var ui=review.GetComponent<UIDocument>().rootVisualElement;
                foreach(var skill in review.Simulation.Catalog.Hero("leonhardt")["skills"])
                {
                    var block=ui.Q<VisualElement>("HeroSkill_"+(string)skill["slot"]);
                    Require(block!=null&&block.Query<Label>().ToList().Any(l=>l.text==(string)skill["skill"]),"original skill identity "+(string)skill["slot"]);
                }
            });
            Add("open equipment tab",()=>ClickName("HeroTab_equipment"));
            Add("verify all original equipment slots",()=>
            {
                var ui=review.GetComponent<UIDocument>().rootVisualElement;
                foreach(string slot in OriginalEquipmentRules.Slots)Require(ui.Q<VisualElement>("HeroGear_"+slot)!=null,"original equipment slot "+slot);
            });
            Add("open ascension tab",()=>ClickName("HeroTab_ascension"));
            Add("verify original progression actions",()=>
            {
                var ui=review.GetComponent<UIDocument>().rootVisualElement;
                Require(ui.Q<Button>("HeroAscendAction")!=null&&ui.Q<Button>("HeroBreakthroughAction")!=null,"ascension and breakthrough routes present");
            });
            Add("open growth tab",()=>ClickName("HeroTab_growth"));
            Add("capture research state",()=>{offense=review.ReviewState.HeroTree("leonhardt").offense;attack=review.Simulation.Battle.Heroes.First(h=>h.Id=="leonhardt").Attack;});
            Add("research offense through pointer",()=>ClickName("HeroResearch_offense"));
            Add("verify research affects same live actor",()=>{Require(review.ReviewState.HeroTree("leonhardt").offense==offense+1,"research rank");Require(review.Simulation.Battle.Heroes.First(h=>h.Id=="leonhardt").Attack>attack,"live attack growth");});
            Navigate("open bag navigation","가방");
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
            Navigate("open menu for chain settings","메뉴");
            Add("open expedition status",()=>ClickName("PortraitMenu_camp"));
            Add("open skill-chain editor",()=>ClickText("연계 순서"));
            Add("capture chain order",()=>chain=review.Simulation.Chain.Entries.ToArray());
            Add("reorder chain through pointer",()=>ClickText("↓",0));
            Add("verify reordered chain",()=>{var entries=review.Simulation.Chain.Entries;Require(entries[0].Equals(chain[1])&&entries[1].Equals(chain[0]),"chain order");});
            Add("disable auto chain through pointer",()=>ClickText("자동 연계 ON"));
            Add("verify disabled chain",()=>Require(!review.Simulation.Chain.Enabled,"auto chain off"));
            Add("enable auto chain through pointer",()=>ClickText("자동 연계 OFF"));
            Add("verify enabled chain",()=>Require(review.Simulation.Chain.Enabled,"auto chain on"));
            Navigate("open state menu","메뉴");
            Add("open summon panel",()=>ClickName("PortraitMenu_summon"));
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
                Navigate("open raid navigation "+zone,"도전");
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
                if(zone=="gray_meadow")
                {
                    Add("enter original-balance pattern training through pointer",()=>ClickText("패턴 훈련"));
                    Add("verify training keeps boss balance and changes temporary party level",()=>{Require(review.Raid.ReviewLevel==50,"training party level");Require(review.Raid.Boss.MaxHp==36000,"original meadow boss hp");});
                    Add("disable auto evasion through pointer for deliberate counter",()=>ClickText("자동 회피 ON"));
                    Add("verify manual raid positioning mode",()=>Require(!review.Raid.AutoEvade,"manual evasion selection"));
                    Add("start authored cone practice through pointer",()=>ClickText("카운터 연습"));
                    Add("verify explicit counter practice route",()=>Require(review.Raid.CounterPractice,"counter practice active"));
                    waitStarted=0;counterRally=false;counterWindowCaptured=false;
                    steps.Add(("observe counter opportunity",()=>
                    {
                        if(waitStarted==0)waitStarted=Time.realtimeSinceStartup;
                        if(!counterRally&&review.Raid.Warning?.Shape=="cone"&&review.Raid.TelegraphRemaining>.55)
                        {ClickGround(review.Raid.Warning.Center+review.Raid.Warning.Direction*4.5f);counterRally=true;return false;}
                        var button=Buttons().FirstOrDefault(b=>(string)b["text"]=="카운터"&&(bool)b["enabled"]);
                        if(review.Raid.CounterReady&&button!=null)
                        {
                            if(!counterWindowCaptured){ScreenCapture.CaptureScreenshot(Path.Combine(Path.GetDirectoryName(ReportPath),"native-counter-window.png"));counterWindowCaptured=true;return false;}
                            Click(button,"카운터");return true;
                        }
                        if(!review.Raid.Running||Time.realtimeSinceStartup-waitStarted>20)return true;return false;
                    }));
                    Add("verify native counter practice success",()=>{Require(review.Raid.CounterSuccesses>0,"native counter practice success");Require(!review.Raid.CounterPractice,"counter exits practice");});
                    int captureFrame=0;steps.Add(("wait for the actual counter HUD refresh",()=>{if(captureFrame==0)captureFrame=Time.frameCount+10;return Time.frameCount>=captureFrame;}));
                    Add("capture authored counter practice",()=>ScreenCapture.CaptureScreenshot(Path.Combine(Path.GetDirectoryName(ReportPath),"native-counter-practice.png")));
                }
                Add("record raid input evidence "+zone,()=>raids.Add(new JObject{{"zone",current},{"dodge_verified",true},{"rally_verified",true},{"native_ticks",review.Raid.Ticks},{"counter_successes",review.Raid.CounterSuccesses},{"counter_input_success_verified",review.Raid.CounterSuccesses>0},{"counter_scope",current=="gray_meadow"?"explicit authored cone practice":"no scripted practice"}}));
                Navigate("return to hunting through pointer "+zone,"사냥");
                Add("verify retained hunting "+zone,()=>{Require(review.Raid==null,"return route");Require(review.Simulation.Ticks>=huntTicks,"retained hunt");});
            }
            Add("capture continuing hunt rewards",()=>{rewardPacks=review.Simulation.PacksCleared;rewardGold=review.Simulation.Gold;rewardXp=review.Simulation.Xp;gold=review.ReviewState.WalletGold;walletXp=GameStateCommands.Integer(review.ReviewState.Snapshot()["wallet_xp"],0,0,GameStateCommands.CurrencyCap);waitStarted=Time.realtimeSinceStartup;});
            steps.Add(("observe an actual hunted pack settlement",()=>{if(review.Simulation.PacksCleared>rewardPacks)return true;if(Time.realtimeSinceStartup-waitStarted>45)throw new InvalidOperationException("No live hunted pack reward in 45 seconds.");return false;}));
            Add("verify actual hunt wallet and xp credit",()=>{var snapshot=review.ReviewState.Snapshot();Require((int)snapshot["native_review_settled_pack"]==review.Simulation.PacksCleared,"pack settlement cursor");Require(review.ReviewState.WalletGold==gold+review.Simulation.Gold-rewardGold,"live hunt gold");Require(GameStateCommands.Integer(snapshot["wallet_xp"],0,0,GameStateCommands.CurrencyCap)==walletXp+review.Simulation.Xp-rewardXp,"live hunt xp");});
            Add("open hunt management through pointer",()=>ClickText("관리"));
            Add("open quick growth through pointer",()=>ClickText("빠른 성장"));
            Add("verify quick growth destination",()=>Require(review.GetComponent<UIDocument>().rootVisualElement.Q<Button>("HeroResearch_offense")!=null,"quick growth research"));
            Add("close quick growth",()=>ClickText("닫기"));
            Add("capture quick equipment wallet",()=>gold=review.ReviewState.WalletGold);
            Add("reopen hunt management through pointer",()=>ClickText("관리"));
            Add("quick equipment through pointer",()=>ClickText("장비 추천"));
            Add("verify quick equipment preserves currency",()=>Require(review.ReviewState.WalletGold==gold,"quick equipment wallet"));
            Navigate("open a fresh raid for natural result flow","도전");
            Add("enter original meadow boss for natural victory",()=>ClickText((string)zones["gray_meadow"]["boss"]));
            Add("capture isolated raid wallet and retained hunt",()=>{gold=review.ReviewState.WalletGold;huntTicks=review.Simulation.Ticks;waitStarted=Time.realtimeSinceStartup;});
            steps.Add(("observe natural raid completion",()=>{if(!review.Raid.Running)return true;if(Time.realtimeSinceStartup-waitStarted>45)throw new InvalidOperationException("Natural meadow result did not arrive within 45 seconds.");return false;}));
            Add("verify actual raid result and unchanged hunt wallet",()=>{Require(review.Raid.Outcome=="victory","natural raid victory");Require(review.RaidResultVisible,"visible raid result");Require(review.ReviewState.WalletGold==gold,"isolated raid wallet unchanged");Require(review.Simulation.Ticks==huntTicks,"hunt stays suspended through result");Require(review.Feedback.SuppressCombatPopups,"combat numbers suppressed over result");Require(review.GetComponent<UIDocument>().rootVisualElement.Query<Label>().ToList().Any(l=>l.text.StartsWith("HP 0 /",StringComparison.Ordinal)),"boss header refreshed for final hp");});
            Add("capture actual native raid result",()=>ScreenCapture.CaptureScreenshot(Path.Combine(Path.GetDirectoryName(ReportPath),"native-raid-result.png")));
            Add("retry natural raid through pointer",()=>ClickText("다시 도전"));
            Add("verify retry clears prior result",()=>{Require(review.Raid.Running&&review.Raid.Elapsed<1.5,"fresh retry encounter");Require(!review.RaidResultVisible,"result cleared on retry");});
            Navigate("return to retained hunt after retry","사냥");
            Add("verify new route returns to hunting",()=>Require(review.Raid==null,"hunt after result retry"));
            Add("start observing a real ultimate presentation",()=>waitStarted=Time.realtimeSinceStartup);
            steps.Add(("observe confirmed ultimate cut-in during live hunting",()=>
            {
                var ui=review.GetComponent<UIDocument>().rootVisualElement;var cue=ui.Q<VisualElement>("skill-cut-in");
                if(review.UltimateCueVisible&&cue.style.opacity.value>.3f&&review.Feedback.PaintedImpactQuads>0)return true;
                if(Time.realtimeSinceStartup-waitStarted>50)throw new InvalidOperationException("No live ultimate cut-in with a painted impact in 50 seconds.");return false;
            }));
            Add("verify original ultimate identity and nonblocking cut-in",()=>
            {
                Require(review.Simulation.Catalog.HeroIds.Contains(review.LastUltimateHero),"original ultimate caster");
                var original=review.Simulation.Catalog.Skill(review.LastUltimateHero,"ultimate");Require((string)original["skill"]==review.LastUltimateSkill,"original ultimate name");
                var ui=review.GetComponent<UIDocument>().rootVisualElement;var cue=ui.Q<VisualElement>("skill-cut-in");
                Require(cue.pickingMode==PickingMode.Ignore&&cue.Query<VisualElement>().ToList().All(e=>e.pickingMode==PickingMode.Ignore),"cut-in does not consume ground input");
                Require(cue.worldBound.yMin>=ui.Q<VisualElement>("top").worldBound.yMax,"cut-in below header");
                Require(!review.Feedback.RaidWarningVisible&&Time.timeScale==1,"ultimate does not freeze combat or cover a raid warning");
            });
            Add("capture confirmed native ultimate",()=>ScreenCapture.CaptureScreenshot(Path.Combine(Path.GetDirectoryName(ReportPath),"native-ultimate.png")));
            running=true;
#if UNITY_EDITOR
            EditorApplication.update+=Tick;
#endif
            return "Native Input System UI acceptance started; poll Status().";
        }
        static JObject Item()=>review.ReviewState.Inventory().First(i=>(string)i["id"]==itemId);
        static void Add(string label,Action action)=>steps.Add((label,()=>{action();return true;}));
        static void Navigate(string label,string route)
        {
            Add("close inspection before "+label,()=>
            {
                var modal=review.GetComponent<UIDocument>().rootVisualElement.Q<VisualElement>("inspection");
                if(modal!=null&&modal.resolvedStyle.display!=DisplayStyle.None)ClickName("inspection-close");
            });
            Add(label,()=>ClickName("navigation-"+route));
        }
        static void Require(bool condition,string label){checks++;if(!condition)throw new InvalidOperationException("Native input assertion failed: "+label);}
        static IEnumerable<JObject> Buttons()=>((JArray)JObject.Parse(NativeUiVerification.Inspect())["buttons"]).Cast<JObject>();
        static void ClickText(string text,int ordinal=0)=>Click(Buttons().Where(b=>(string)b["text"]==text).Skip(ordinal).FirstOrDefault(),text);
        static void ClickPrefix(string prefix)=>Click(Buttons().FirstOrDefault(b=>((string)b["text"]).StartsWith(prefix,StringComparison.Ordinal)),prefix);
        static void ClickData(string id)=>Click(Buttons().FirstOrDefault(b=>(string)b["data"]==id),id);
        // Resolve stable UI names to a visible, unobstructed hit location, then
        // dispatch the same actual Input System press/release as text targets.
        static void ClickName(string name)
        {
            var ui=review.GetComponent<UIDocument>().rootVisualElement;
            var button=ui.Q<Button>(name);var bounds=button?.worldBound??default;
            bool visible=button!=null&&button.visible&&button.enabledInHierarchy&&bounds.width>0&&bounds.height>0&&ui.worldBound.Contains(bounds.center);
            for(VisualElement parent=button;parent!=null;parent=parent.parent)
            {
                if(parent.resolvedStyle.display==DisplayStyle.None||parent.resolvedStyle.visibility==Visibility.Hidden)visible=false;
                if(parent is ScrollView scroll&&!scroll.contentViewport.worldBound.Contains(bounds.center))visible=false;
            }
            if(!visible)throw new InvalidOperationException("Visible enabled native button not found: "+name);
            var picked=ui.panel.Pick(bounds.center);
            while(picked!=null&&picked!=button)picked=picked.parent;
            if(picked!=button)throw new InvalidOperationException("Native button is obstructed: "+name);
            Click(new JObject{{"enabled",true},{"x",(bounds.center.x-ui.worldBound.x)/ui.worldBound.width*Screen.width},{"y",(1-(bounds.center.y-ui.worldBound.y)/ui.worldBound.height)*Screen.height}},name);
        }
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
            var report=new JObject{{"passed",passed},{"error",error},{"comparisons",checks},{"steps_completed",index},{"steps_total",steps.Count},{"start_frame",startFrame},{"end_frame",Time.frameCount},{"elapsed_seconds",Time.realtimeSinceStartup-started},{"batch_editor",Application.isBatchMode},{"virtual_qa_mouse",qaMouse!=null},{"trace",trace.DeepClone()},{"raid_inputs",raids.DeepClone()},{"no_direct_ui_callbacks",true},{"real_player_io",false},{"note","QA dispatches actual Input System mouse events across native frames against the explicit memory-only review seed. Meadow counter evidence uses the visible Lv50 authored-cone practice route, which temporarily suspends automatic hero attacks and rearms the window. It does not prove a naturally occurring counter in a full encounter. Ordinary original-balance raid parity is checked separately."}};
            report["development_player"]=!Application.isEditor&&Debug.isDebugBuild;
            report["ultimate_presentations"]=review.UltimatePresentations;report["last_ultimate_hero"]=review.LastUltimateHero;report["last_ultimate_skill"]=review.LastUltimateSkill;
            report["manual_skill_casts"]=review.Simulation.ManualSkillCasts;
            File.WriteAllText(ReportPath,report.ToString());Debug.Log((passed?"ETERNAL_NATIVE_INPUT_PASSED ":"ETERNAL_NATIVE_INPUT_FAILED ")+error);
            if(qaMouse!=null){InputSystem.RemoveDevice(qaMouse);qaMouse=null;}
        }
        public static string Status()
        {if(running)return new JObject{{"running",true},{"step",index},{"total",steps.Count},{"label",index<steps.Count?steps[index].label:"done"},{"frames",Time.frameCount-startFrame}}.ToString();return File.Exists(ReportPath)?File.ReadAllText(ReportPath):"Not started.";}
    }
}
#endif
