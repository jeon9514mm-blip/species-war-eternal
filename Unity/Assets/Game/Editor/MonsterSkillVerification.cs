using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class MonsterSkillVerification
    {
        public static string Verify()
        {
            int checks=0;void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Monster skills: "+label);}
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);var scenarios=new JArray();
            foreach(string id in FallenMonsterCatalog.Ids)
            foreach(int stage in new[]{99,100,250,500,1000})
            {
                var state=new GameStateCommands(catalog,NativePlayerSession.NewPayload(catalog,"aurelia"),_=>true);var sim=new HuntingSimulation(1,9514,state);sim.Stage=stage;
                var hero=sim.Battle.Heroes[0];sim.Battle.Heroes.RemoveAll(h=>h!=hero);hero.Position=hero.PreviousPosition=Vector2.zero;hero.Hp=hero.MaxHp=100000;hero.AttackRemaining=100000;hero.Shield=0;hero.Guard=0;
                var enemy=sim.Battle.Enemies.First(e=>e.Id==id);sim.Battle.Enemies.RemoveAll(e=>e!=enemy);enemy.Position=enemy.PreviousPosition=new Vector2(.75f,0);enemy.Hp=50000;enemy.MaxHp=100000;enemy.Attack=200;enemy.AttackRemaining=0;
                int skills=0,bleedHits=0;bool sawWarning=false,sawWeaken=false,sawBreak=false,sawBleed=false,sawStun=false;double lastSkill=-100;
                sim.OnEvent=e=>
                {
                    if(e.Kind=="monster_skill")
                    {Check(sim.Elapsed-lastSkill>=7.99,"bounded monster skill cooldown");lastSkill=sim.Elapsed;skills++;sawWeaken|=hero.Weaken>0;sawBreak|=hero.ArmorBreak>0;sawBleed|=hero.Bleed>0;sawStun|=hero.Stun>0;}
                    if(e.Kind=="hero_hit"&&hero.Bleed>0)bleedHits++;
                };
                for(int tick=0;tick<700;tick++)
                {
                    sim.Step(.05);var warning=sim.MonsterWarning;if(!string.IsNullOrEmpty(warning.title)){sawWarning=true;double before=enemy.Windup;int clock=sim.Ticks;var again=sim.MonsterWarning;Check(again.remaining==warning.remaining&&enemy.Windup==before&&sim.Ticks==clock,"warning is a read-only authoritative timer");}
                }
                Check(stage<100?skills==0&&!sawWarning:skills>0&&sawWarning,"stage-gated special attack "+id+" "+stage);
                if(stage>=100&&(id=="fallen_elf"||id=="fallen_vampire"||stage<250))Check(sawWeaken,"actual weakness settlement");
                if(id=="fallen_dwarf"&&stage>=250)Check(sawBreak,"actual armor-break settlement");
                if(id=="fallen_werewolf"&&stage>=250)Check(sawBleed&&bleedHits>=3,"actual bounded bleed damage");
                if(id=="fallen_elf"&&stage>=500||id=="fallen_dwarf"&&stage>=1000)Check(sawStun,"higher-stage stun unlock");
                if(id=="fallen_vampire")Check(enemy.Hp>50000,"vampire heals from actual hits");
                sim.Paused=true;double held=sim.Elapsed,bleed=hero.Bleed;int hp=hero.Hp;sim.Step(.05);Check(sim.Elapsed==held&&hero.Bleed==bleed&&hero.Hp==hp,"pause stops skills and bleed");
                scenarios.Add(new JObject{{"id",id},{"stage",stage},{"confirmed_special_attacks",skills},{"warning_observed",sawWarning},{"weakness",sawWeaken},{"armor_break",sawBreak},{"bleed",sawBleed},{"stun",sawStun}});
            }
            var report=new JObject{{"passed",true},{"comparisons",checks},{"scenarios",scenarios},{"note","Controlled contact scenarios exercise source combat, warning timing, cooldowns, mitigation, vampire healing, stage gates and paused damage clocks. Full encounter difficulty balance remains to tune; not a performance benchmark."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/monster-skills-cp14.json",report.ToString());return report.ToString();
        }
    }
}
