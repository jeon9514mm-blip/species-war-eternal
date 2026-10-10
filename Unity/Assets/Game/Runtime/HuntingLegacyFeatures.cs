using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        HuntingSimulation retainedHunt;
        LegacyChallengeSession activeChallenge;
        VisualElement challengeControls;
        Label challengeCaption;
        float idleStampAt;
        double productivitySeconds;
        int productivityPacks;
        int practiceLevel=1;
        bool practiceMatched;
        JObject lastPracticeReport;
        readonly System.Collections.Generic.List<JObject> practiceReports=new();
        bool ChallengeActive=>activeChallenge!=null;
        void StampActivity()
        {if(!PersistentPlayer||Time.unscaledTime<idleStampAt||ReviewState.MutationError.Length>0)return;idleStampAt=Time.unscaledTime+60;ReviewState.StampIdleTime();PauseForSaveFailure();}
        void ShowGoals(string scope="guide")
        {
            PanelHeader("목표 · 업적");var tabs=Row(modal);
            foreach(var entry in new[]{("guide","여정"),("daily","일일"),("weekly","주간"),("achievement","업적")}){string s=entry.Item1;Button(tabs,entry.Item2,()=>ShowGoals(s));}
            GrowthNotice(modal);var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            var context=ReviewState.GoalContext(scope);var snapshot=ReviewState.Snapshot();
            if(scope=="guide")foreach(string id in new[]{"stage5","raid1","tower5"})
            {var q=ReviewState.LegacyQuest(id);LegacySection(scroll,(string)q["title"],q["current"]+" / "+q["target"]);GrowthButton(scroll,"핵심 퀘스트 보상 수령",()=>ReviewState.ClaimLegacyQuest(id),()=>ShowGoals(scope),!L.Flag(snapshot["quest_claimed"]?[id])&&L.N(q["current"])>=L.N(q["target"]));}
            foreach(var row in ReviewState.GoalRows(scope).OfType<JObject>().Where(r=>scope!="guide"||L.Flag(r["unlocked"])&&!L.Flag(r["claimed"])).Take(scope=="guide"?1:100))
            {
                string id=(string)row["id"];LegacySection(scroll,(string)row["title"],row["current"]+" / "+row["target"]+" · 골드 "+row["gold"]+" · 젬 "+row["gems"]);
                GrowthButton(scroll,L.Flag(row["claimed"])?"수령 완료":"보상 수령",()=>ReviewState.ClaimGoal(scope,id,context),()=>ShowGoals(scope),L.Flag(row["ready"]));
                string title=(string)L.Data["definitions"]["goals"]["TITLES"]?[id];if(scope=="achievement"&&title!=null&&L.Flag(row["claimed"]))GrowthButton(scroll,"칭호 장착 · "+title,()=>ReviewState.EquipGoalTitle(id,ReviewState.Faction),()=>ShowGoals(scope));
            }
        }
        void ShowDungeons()
        {
            PanelHeader("던전");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);GrowthNotice(scroll);var status=ReviewState.ChallengeStatus();
            LegacySection(scroll,"일일 던전",status["daily_day"]+" · 완료 "+status["daily_runs"]+" / 3 · 실패·취소는 횟수 차감 없음");
            foreach(string variant in new[]{"gold_rush","survival","boss_hunt"})
            {string v=variant;LegacySection(scroll,(string)L.Data["daily_plans"][v]["title"],(string)L.Data["daily_plans"][v]["description"]);Button(scroll,"직접 도전",()=>StartChallenge("daily",v)).SetEnabled(GrowthAllowed&&!ChallengeActive&&L.N(status["daily_runs"])<3);GrowthButton(scroll,"직접 승리한 단계 소탕",()=>ReviewState.SweepDaily(v),ShowDungeons,L.N(status["daily_runs"])<3);}
            LegacySection(scroll,"무한탑",status["floor"]+"층 · 최고 "+status["best_floor"]+"층 · 90초 제한 · 5층마다 수문장");Button(scroll,"무한탑 도전",()=>StartChallenge("tower")).SetEnabled(GrowthAllowed&&!ChallengeActive&&L.N(status["floor"])<=9999);
            LegacySection(scroll,"주간 심연",status["week"]+"주 · 완료 "+status["weekly_runs"]+" / 5 · 최고 피해 "+L.N(status["weekly_best"],0,GameStateCommands.CurrencyCap).ToString("N0")+" · 90초 생존");Button(scroll,"심연 원정",()=>StartChallenge("weekly")).SetEnabled(GrowthAllowed&&!ChallengeActive&&L.N(status["weekly_runs"])<5);
            if(ReviewState.Snapshot()["unity_last_challenge"] is JObject last)LegacySection(scroll,"최근 결과",last["mode"]+" · "+last["reason"]+" · 피해 "+last["damage_score"]+" · "+last["elapsed"]+"초");
            Button(scroll,"전투 연습실 · 보상/횟수 미반영",ShowPractice);
            Button(scroll,"통합 전투 프리셋 · P1~P3",ShowCombatPresets);
        }
        void StartChallenge(string mode,string variant="gold_rush")
        {
            if(!GrowthAllowed||ChallengeActive)return;var result=ReviewState.ReserveChallenge(mode,variant);growthMessage=result.Message;
            if(!result.Ok||result.SavePending){ShowDungeons();return;}
            retainedHunt=Simulation;retainedHuntWasPaused=retainedHunt.Paused;retainedHunt.Paused=true;activeChallenge=new LegacyChallengeSession((long)result.Details["serial"],(JObject)result.Details["entry"]);
            Simulation=new HuntingSimulation(1,9514,ReviewState);Simulation.Zone=ReviewState.UnityZone;Simulation.AttachChallenge(activeChallenge);Simulation.OnEvent=Receive;
            CloseInspection();accumulator=0;visualQueue.Clear();BuildParty();RebuildActors();SelectNavigation("던전");
            challengeControls=new VisualElement{name="challenge-controls"};challengeControls.style.position=Position.Absolute;challengeControls.style.top=100;challengeControls.style.left=20;challengeControls.style.right=20;challengeControls.style.backgroundColor=Ink;challengeControls.style.flexDirection=FlexDirection.Row;challengeControls.style.alignItems=Align.Center;root.Add(challengeControls);
            challengeCaption=Text(challengeControls,activeChallenge.Title,16);challengeCaption.style.flexGrow=1;Button(challengeControls,"도전 취소",()=>FinishActiveChallenge(true));
        }
        void UpdateChallenge()
        {
            if(activeChallenge==null)return;challengeCaption.text=activeChallenge.Title+" · "+Math.Max(0,activeChallenge.Limit-activeChallenge.Elapsed).ToString("F1")+"초 · "+activeChallenge.Waves+"무리 · 피해 "+activeChallenge.Damage.ToString("N0")+(activeChallenge.PatternActive?" · "+activeChallenge.Pattern:"");
            if(!activeChallenge.Running)FinishActiveChallenge(false);
        }
        void FinishActiveChallenge(bool cancelled)
        {
            if(activeChallenge==null)return;if(cancelled)activeChallenge.Cancel();var state=ReviewState;bool practice=L.Flag(activeChallenge.Entry["practice"]);var result=practice?StateCommandResult.Success("연습 종료 · 보상·횟수·성장 기록 변경 없음"):state.FinishChallenge(activeChallenge);growthMessage=result.Message;
            if(practice){lastPracticeReport=activeChallenge.Report();practiceReports.Insert(0,lastPracticeReport);while(practiceReports.Count>6)practiceReports.RemoveAt(practiceReports.Count-1);retainedHunt.PlayerState.PracticeActive=false;}
            activeChallenge=null;challengeControls?.RemoveFromHierarchy();challengeControls=null;challengeCaption=null;
            Simulation=retainedHunt;retainedHunt=null;Simulation.Paused=retainedHuntWasPaused||ReviewState.SavePending;Simulation.RefreshHeroGrowth();accumulator=0;visualQueue.Clear();BuildParty();RebuildActors();if(practice)ShowPractice();else ShowDungeons();RefreshHud();
        }
        void ShowPractice()
        {
            PanelHeader("전투 연습실");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);GrowthNotice(scroll);Text(scroll,"보상·목표·입장 횟수·성장 기록에 반영하지 않습니다. 장비·연구·돌파는 현재 상태를 사용합니다.",14).style.whiteSpace=WhiteSpace.Normal;
            var matched=new Toggle("레벨만 맞춤"){value=practiceMatched};matched.RegisterValueChangedCallback(e=>practiceMatched=e.newValue);scroll.Add(matched);int ceiling=Simulation.Catalog.HeroIds.Where(ReviewState.IsFactionHero).Select(id=>ReviewState.HeroProgress(id).level).DefaultIfEmpty(1).Max();var level=new IntegerField("맞춤 레벨 (최대 "+ceiling+")"){value=Math.Clamp(practiceLevel,1,ceiling)};level.RegisterValueChangedCallback(e=>practiceLevel=Math.Clamp(e.newValue,1,ceiling));scroll.Add(level);
            foreach(string variant in new[]{"gold_rush","survival","boss_hunt"})for(int tier=0;tier<3;tier++){string v=variant;int t=tier;Button(scroll,L.Data["daily_plans"][v]["title"]+" "+(t+1)+"단계 연습",()=>StartPractice("daily",v,t+1));}
            int floor=(int)L.N(ReviewState.ChallengeStatus()["floor"],1,9999);Button(scroll,"무한탑 "+floor+"층 연습",()=>StartPractice("tower","floor",floor));Button(scroll,"주간 심연 연습",()=>StartPractice("weekly","score",1));
            if(lastPracticeReport!=null)
            {
                LegacySection(scroll,"최근 연습 기록",lastPracticeReport["reason"]+" · "+lastPracticeReport["elapsed"]+"초 · 실제 피해 "+lastPracticeReport["damage_score"]);
                foreach(var actor in L.Array(lastPracticeReport["actors"]).OfType<JObject>())LegacySection(scroll,(string)actor["name"],"피해 "+actor["damage"]+" · DPS "+L.F(actor["dps"]).ToString("F1")+" · 피격 "+actor["damage_taken"]+" · 회복 "+actor["healing_received"]+" · 보호막 흡수 "+actor["shield_absorbed"]);
                foreach(var advice in L.Array(lastPracticeReport["advice"]))Text(scroll,(string)advice,12).style.whiteSpace=WhiteSpace.Normal;
                var previous=practiceReports.Skip(1).FirstOrDefault(r=>(string)r["comparison_key"]==(string)lastPracticeReport["comparison_key"]);
                if(previous!=null&&new[]{"score_complete","survived","waves_cleared"}.Contains((string)previous["reason"])&&new[]{"score_complete","survived","waves_cleared"}.Contains((string)lastPracticeReport["reason"]))LegacySection(scroll,"같은 조건 비교","실제 피해 차이 "+(L.N(lastPracticeReport["damage_score"])-L.N(previous["damage_score"]))+" · DPS 차이 "+(L.F(lastPracticeReport["dps"])-L.F(previous["dps"])).ToString("F1"));
            }
        }
        void StartPractice(string mode,string variant,int difficulty)
        {
            if(!GrowthAllowed)return;var baseline=ReviewState;var options=baseline.Snapshot();options["native_review_fixture"]=true;var temporary=new GameStateCommands(Simulation.Catalog,options,_=>false){PracticeActive=true,PracticeMatchedLevel=practiceMatched?practiceLevel:0};
            var entry=new JObject{{"mode",mode},{"variant",variant},{"floor",difficulty},{"run_index",difficulty-1},{"week",L.Week(L.Now)},{"faction",baseline.Faction},{"zone",baseline.UnityZone},{"hero_ids",new JArray(baseline.DeployedHeroes())},{"practice",true},{"level_mode",practiceMatched?"matched":"actual"},{"match_level",practiceMatched?practiceLevel:0}};
            retainedHunt=Simulation;retainedHuntWasPaused=retainedHunt.Paused;retainedHunt.Paused=true;baseline.PracticeActive=true;activeChallenge=new LegacyChallengeSession(1,entry);Simulation=new HuntingSimulation(1,830300+difficulty,temporary);Simulation.Zone=temporary.UnityZone;Simulation.AttachChallenge(activeChallenge);Simulation.OnEvent=Receive;CloseInspection();accumulator=0;visualQueue.Clear();BuildParty();RebuildActors();
            challengeControls=new VisualElement{name="practice-controls"};challengeControls.style.position=Position.Absolute;challengeControls.style.top=100;challengeControls.style.left=20;challengeControls.style.right=20;challengeControls.style.backgroundColor=Ink;challengeControls.style.flexDirection=FlexDirection.Row;root.Add(challengeControls);challengeCaption=Text(challengeControls,"연습 · 보상 없음",16);challengeCaption.style.flexGrow=1;Button(challengeControls,"연습 종료",()=>FinishActiveChallenge(true));
        }
        bool retainedHuntWasPaused;
        void ShowCombatPresets()
        {
            PanelHeader("통합 전투 프리셋");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);GrowthNotice(scroll);Text(scroll,"진영별 P1~P3 · 편성·장비 ID·수호신·자동 스킬 · 재화 소비 없음",13).style.whiteSpace=WhiteSpace.Normal;
            for(int i=0;i<3;i++){int index=i;var preset=ReviewState.CombatPreset(i);LegacySection(scroll,"P"+(i+1),preset.Count>0?string.Join(", ",L.Array(preset["heroes"]).Values<string>())+" · "+preset["formation_id"]:"비어 있음");GrowthButton(scroll,"현재 전투 설정 저장",()=>ReviewState.SaveCombatPreset(index),ShowCombatPresets);GrowthButton(scroll,"프리셋 전체 적용",()=>ReviewState.ApplyCombatPreset(index,preset),ShowCombatPresets,preset.Count>0);}
        }
    }
}
