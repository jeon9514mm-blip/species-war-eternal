using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class CombatPolishVerification
    {
        public static string Verify()
        {
            int checks=0;void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Combat polish: "+label);}
            var support=new Combatant{Role="서포터",Slot=0,Range=3};var tank=new Combatant{Role="탱커",Slot=1,Range=1};var control=new Combatant{Role="컨트롤러",Slot=2,Range=3};
            foreach(var heading in new[]{Vector2.right,Vector2.left,Vector2.up,Vector2.down})
            {
                var center=new Vector2(3,-2);var rear=HuntExpeditionPlan.ApproachAnchor(support,center,heading);var front=HuntExpeditionPlan.ApproachAnchor(tank,center,heading);var flank=HuntExpeditionPlan.ApproachAnchor(control,center,heading);
                Check(Vector2.Dot(rear-center,heading)<-1.5f&&Vector2.Dot(front-center,heading)>1,"role lanes follow every heading");
                var lateral=new Vector2(-heading.y,heading.x);Check(Mathf.Abs(Vector2.Dot(flank-center,lateral))>2,"controller approach has a side lane");
            }
            var hunt=new HuntingSimulation(50);var actor=hunt.Battle.Heroes[0];var target=hunt.Battle.Enemies[0];actor.Position=Vector2.zero;target.Position=Vector2.right*.2f;
            Check(HuntPositionPlanner.Goal(hunt,actor,target,true,Vector2.zero,new System.Collections.Generic.Dictionary<int,Vector2>(),Vector2.zero,false)==actor.Position,"clear attack station does not reposition for appearance");
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                var raid=new RaidSimulation(zone,50);foreach(var hero in raid.Battle.Heroes){hero.Ultimate=100;foreach(string slot in new[]{"a1","a2"})raid.Battle.Kits[hero.Id].Cooldowns[slot]=0;}
                raid.ControlImmunity=0;raid.StartWarning((JObject)raid.Design["phases"][0]);var hp=raid.Battle.Heroes.Select(h=>h.Hp).ToArray();double time=raid.Elapsed,remaining=raid.TelegraphRemaining;int version=raid.WarningVersion;
                var view=RaidResponseView.Read(raid);Check(view.Prompt=="무력화 지원 가능"&&view.Action.Contains(raid.BreakSkillHint),"available original skill is named "+zone);
                Check(view.InDanger==raid.Battle.Heroes.Count(h=>h.Alive&&raid.Warning.Contains(h.Position)),"range count reads frozen authoritative geometry "+zone);
                raid.ControlImmunity=6;view=RaidResponseView.Read(raid);Check(view.Prompt=="제어 면역 · 직접 이동"&&view.Action.Contains("조이스틱")&&!view.Action.Contains("무력화 지원"),"immune boss directs physical movement "+zone);
                raid.SecondWarning=RaidFootprint.Create("moon_mark",raid.Boss.Position,new[]{raid.Battle.Heroes[0].Position},new JObject());raid.SecondProfile=new JObject{{"name","Explicit earlier secondary"},{"telegraph",1}};raid.SecondWaveRemaining=.1;
                view=RaidResponseView.Read(raid);Check(view.Kind=="secondary"&&view.Remaining==.1f&&view.Action.Contains("표식"),"earliest mark supplies its own movement guidance "+zone);
                Check(raid.Elapsed==time&&raid.TelegraphRemaining==remaining&&raid.WarningVersion==version&&raid.Battle.Heroes.Select(h=>h.Hp).SequenceEqual(hp),"response reads do not mutate combat "+zone);
            }
            var movement=MovementPlannerVerification.Verify();var readability=JObject.Parse(CombatReadabilityVerification.Verify());var vfx=SkillVfxVerification.Verify();
            var report=new JObject{{"passed",true},{"comparisons",checks},{"movement",movement},{"readability",readability},{"vfx",vfx},{"note","Role approach lanes, original attack-station hold, authoritative warning guidance and sequential visual timelines. Existing all-thirty-hero movement scenarios retained. No FPS benchmark or 120 individually accepted assets."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/combat-polish-cp17.json",report.ToString());return report.ToString();
        }
    }
}
