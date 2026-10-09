using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        readonly Queue<(string hero,string skill,bool chain,Color accent,float expires)> ultimateNotices=new(2);
        readonly Dictionary<string,Color> castAccents=new(StringComparer.Ordinal);
        readonly Dictionary<string,float> castHighlights=new(StringComparer.Ordinal);
        readonly List<string> endedHighlights=new(10);
        VisualElement castCue,raidResult;
        Image castPortrait;
        Label castHero,castSkill,castType,resultTitle,resultDetails,resultScope;
        float castCueUntil;
        string shownRaidOutcome="";
        public int UltimatePresentations {get;private set;}
        public string LastUltimateHero {get;private set;}="";
        public string LastUltimateSkill {get;private set;}="";
        public bool UltimateCueVisible=>castCue!=null&&castCue.style.display.value==DisplayStyle.Flex;
        public bool RaidResultVisible=>raidResult!=null&&raidResult.style.display.value==DisplayStyle.Flex;

        void BuildSkillPresentation()
        {
            foreach(JObject p in HuntingSimulation.Canonical["skill_vfx"])
                if(ColorUtility.TryParseHtmlString((string)p["color"],out var accent))castAccents[(string)p["signature"]]=accent;
            castCue=Box(root,"skill-cut-in",new Color(.035f,.06f,.065f,.94f));
            castCue.pickingMode=PickingMode.Ignore;castCue.style.position=Position.Absolute;castCue.style.left=24;castCue.style.top=107;
            castCue.style.width=318;castCue.style.height=84;castCue.style.flexDirection=FlexDirection.Row;
            castCue.style.paddingLeft=10;castCue.style.paddingRight=12;castCue.style.paddingTop=4;castCue.style.paddingBottom=4;
            castCue.style.borderLeftWidth=3;castCue.style.borderLeftColor=Bronze;castCue.style.display=DisplayStyle.None;
            castPortrait=new Image{scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};castPortrait.style.width=65;castPortrait.style.height=74;castPortrait.style.flexShrink=0;castPortrait.style.marginRight=12;castCue.Add(castPortrait);
            var copy=new VisualElement{pickingMode=PickingMode.Ignore};copy.style.flexGrow=1;copy.style.minWidth=0;copy.style.justifyContent=Justify.Center;castCue.Add(copy);
            castHero=Text(copy,"",12);castHero.style.color=Moss;
            castSkill=Text(copy,"",18);castSkill.style.color=Bronze;castSkill.style.whiteSpace=WhiteSpace.NoWrap;castSkill.style.overflow=Overflow.Hidden;castSkill.style.textOverflow=TextOverflow.Ellipsis;
            castType=Text(copy,"궁극기",10);castType.style.color=Moss;
            foreach(var line in new[]{castHero,castSkill,castType}){line.style.flexShrink=0;line.style.marginTop=line.style.marginBottom=line.style.paddingTop=line.style.paddingBottom=0;}
            castHero.style.height=20;castSkill.style.height=27;castType.style.height=16;
            castHero.pickingMode=castSkill.pickingMode=castType.pickingMode=PickingMode.Ignore;

            raidResult=Box(root,"raid-result",Ink);raidResult.style.position=Position.Absolute;raidResult.style.left=Length.Percent(50);raidResult.style.marginLeft=-235;
            raidResult.style.top=Length.Percent(27);raidResult.style.width=470;raidResult.style.paddingLeft=24;raidResult.style.paddingRight=24;raidResult.style.paddingTop=22;raidResult.style.paddingBottom=22;raidResult.style.display=DisplayStyle.None;
            resultTitle=Text(raidResult,"",27);resultTitle.style.color=Bronze;resultTitle.style.unityTextAlign=TextAnchor.MiddleCenter;
            resultDetails=Text(raidResult,"",15);resultDetails.style.whiteSpace=WhiteSpace.Normal;resultDetails.style.marginTop=18;resultDetails.style.marginBottom=14;resultDetails.style.unityTextAlign=TextAnchor.MiddleCenter;
            resultScope=Text(raidResult,"플레이테스트 전투 기록 · 실제 저장과 보상은 변경되지 않습니다",12);resultScope.style.color=Moss;resultScope.style.whiteSpace=WhiteSpace.Normal;resultScope.style.unityTextAlign=TextAnchor.MiddleCenter;
            var actions=Row(raidResult);actions.style.marginTop=18;
            Button(actions,"다시 도전",()=>{if(Raid!=null)StartRaid(Raid.Zone,Raid.ReviewLevel,playerRaidTraining);}).style.flexGrow=1;
            Button(actions,"사냥 복귀",()=>{EndRaid();modal.style.display=DisplayStyle.None;}).style.flexGrow=1;
        }
        void ObserveCastPresentation(BattleEvent e)
        {
            if(e.Kind!="cast"||e.Source==null||!ActiveBattle.Kits.TryGetValue(e.Source,out var kit)||!kit.Profiles.TryGetValue(e.Slot,out var profile))return;
            castHighlights[e.Source]=Time.unscaledTime+.30f;
            ObserveSkillFeed(e,(string)profile["skill"],(string)profile["kind"]);
            if(e.Slot!="ultimate")return;
            var accent=castAccents.GetValueOrDefault(e.Source+":"+e.Slot,Bronze);
            // No generated hero replacement: the notice uses the actual caster's
            // existing original portrait and confirmed skill name.
            if(ultimateNotices.Count==2)ultimateNotices.Dequeue();
            ultimateNotices.Enqueue((e.Source,(string)profile["skill"],e.Chain,accent,Time.unscaledTime+1.2f));
        }
        void RefreshSkillPresentation()
        {
            RefreshCombatReadability();
            float now=Time.unscaledTime;
            foreach(var c in cards)
            {
                var card=chainRow.Q<Button>("party-card-"+c.actor.Id);if(card==null)continue;
                bool casting=castHighlights.TryGetValue(c.actor.Id,out float until)&&until>now;
                card.style.borderTopColor=casting?Bronze:new Color(.25f,.31f,.31f);
            }
            endedHighlights.Clear();foreach(var pair in castHighlights)if(pair.Value<=now)endedHighlights.Add(pair.Key);
            foreach(string id in endedHighlights)castHighlights.Remove(id);
            bool protectedArea=feedback.RaidWarningVisible||RaidResolutionPending||modal.style.display.value!=DisplayStyle.None||Raid!=null&&!Raid.Running;
            while(ultimateNotices.Count>0&&ultimateNotices.Peek().expires<now)ultimateNotices.Dequeue();
            if(now>=castCueUntil)
            {
                castCue.style.display=DisplayStyle.None;
                if(ultimateNotices.Count>0&&!protectedArea)
                {
                    var notice=ultimateNotices.Dequeue();castPortrait.sprite=InspectionPortrait(notice.hero);
                    LastUltimateHero=notice.hero;LastUltimateSkill=notice.skill;
                    castHero.text=(string)Simulation.Catalog.Hero(notice.hero)["name"];castSkill.text=notice.skill;
                    castType.text=notice.chain?"궁극기 · 원정대 연계":"궁극기";
                    castCue.style.borderLeftColor=Color.Lerp(Bronze,notice.accent,.35f);castCueUntil=now+.90f;UltimatePresentations++;
                }
            }
            if(now<castCueUntil&&!protectedArea)
            {
                castCue.style.display=DisplayStyle.Flex;float remaining=castCueUntil-now;
                float ease=Mathf.Clamp01((.9f-remaining)/.12f);castCue.style.left=24-(1-ease)*12;
                castCue.style.opacity=Mathf.Min(ease,remaining/.16f);
            }
            else castCue.style.display=DisplayStyle.None;
            if(Raid!=null&&!Raid.Running&&shownRaidOutcome!=Raid.Outcome)
            {
                RefreshHud();
                shownRaidOutcome=Raid.Outcome;resultTitle.text=Raid.Outcome=="victory"?"레이드 성공":Raid.Outcome=="timeout"?"제한 시간 종료":"원정대 전멸";
                resultScope.text=playerSession==null?"플레이테스트 전투 기록 · 실제 저장과 보상은 변경되지 않습니다":playerRaidTraining?"패턴 훈련 · 실제 원정대 보상 없음":playerRaidReward?.Message??"전투 종료 · 사냥 성장으로 다시 준비하세요.";
                resultDetails.text=(string)Raid.ZoneData["boss"]+" · Lv"+Raid.ReviewLevel+"\n"+TimeSpan.FromSeconds(Raid.Elapsed).ToString(@"mm\:ss")+" · 총 피해 "+Raid.DamageDealt.ToString("N0")+"\n생존 "+ActiveBattle.Heroes.FindAll(h=>h.Alive).Count+"/10 · 카운터 "+Raid.CounterSuccesses+" · 무력화 "+Raid.Interrupts;
                raidResult.style.display=DisplayStyle.Flex;
            }
        }
        void ResetSkillPresentation()
        {
            ResetCombatReadability();
            resolutionRaid=null;resolutionUntil=0;if(raidResolution!=null)raidResolution.style.display=DisplayStyle.None;
            ultimateNotices.Clear();castHighlights.Clear();castCueUntil=0;shownRaidOutcome="";
            if(castCue!=null)castCue.style.display=DisplayStyle.None;if(raidResult!=null)raidResult.style.display=DisplayStyle.None;
        }
    }
}
