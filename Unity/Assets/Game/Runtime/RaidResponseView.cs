using System;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Read-only response priority. The encounter remains the sole timer,
    // counter eligibility, damage geometry and mechanic settlement authority.
    public readonly struct RaidResponseView
    {
        public readonly string Kind,Title,Action;
        public readonly float Remaining,Progress;
        public readonly Color Accent;
        public readonly bool Visible,Timed;
        RaidResponseView(string kind,string title,string action,Color accent,float remaining=0,float progress=0,bool timed=false)
        {Kind=kind;Title=title;Action=action;Accent=accent;Remaining=remaining;Progress=Mathf.Clamp01(progress);Visible=true;Timed=timed;}
        public static RaidResponseView Read(RaidSimulation raid)
        {
            if(raid==null||!raid.Running)return default;
            var red=new Color(.90f,.45f,.40f);var blue=new Color(.48f,.82f,.95f);var bronze=new Color(.91f,.77f,.55f);
            bool primary=raid.Warning!=null&&(raid.SecondWarning==null||raid.TelegraphRemaining<=raid.SecondWaveRemaining);
            if(primary||raid.SecondWarning!=null)
            {
                double seconds=primary?raid.TelegraphRemaining:raid.SecondWaveRemaining;var profile=primary?raid.CastProfile:raid.SecondProfile;
                float total=(float)Math.Max(.01,LegacyCombatRules.Number(profile,"telegraph",1.2));
                if(primary&&raid.CounterWindowOpen)return new RaidResponseView("counter","정면 카운터",raid.CounterReady?"지금 카운터 · 보스 공격 차단":"정면으로 집결 · 행동 가능한 영웅 필요",blue,(float)seconds,(float)(seconds/.55),true);
                string title=(string)profile?["name"]??"후속 공격";
                string action=(string)profile?["counter"]??"위험 구역 밖으로 이동하세요.";
                if(!primary)action="후속 충격 먼저 회피 · "+action;
                return new RaidResponseView(primary?"warning":"secondary",title,action,red,(float)seconds,(float)(seconds/total),true);
            }
            if(raid.DpsRemaining>0)return new RaidResponseView("ritual","월식 의식 저지","남은 시간 안에 피해 목표 달성 · "+raid.DpsDamage.ToString("N0")+" / "+raid.DpsTarget.ToString("N0"),bronze,(float)raid.DpsRemaining,(float)raid.DpsDamage/Math.Max(1,raid.DpsTarget),true);
            if(raid.GuardHp>0)return new RaidResponseView("armor","갑주 파괴","공격을 집중해 갑주를 제거하세요.",bronze,progress:1-(float)raid.GuardHp/Math.Max(1,raid.GuardMax));
            if(raid.AddHp>0)return new RaidResponseView("crystal","수정핵 제거",raid.AddCount+"개 수정핵을 제거해 보스 보호를 해제하세요.",blue,progress:1-(float)raid.AddHp/Math.Max(1,raid.AddMax));
            if(raid.Boss.Vulnerable>0)return new RaidResponseView("opening","약점 노출 · 공격 기회","준비된 스킬과 각성으로 피해를 집중하세요.",bronze,(float)raid.Boss.Vulnerable,timed:true);
            return default;
        }
    }
}
