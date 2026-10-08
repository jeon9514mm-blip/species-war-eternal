using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class ManualSkillVerification
    {
        public static JObject Verify()
        {
            int checks=0;void Check(bool value,string label){checks++;if(!value)throw new InvalidOperationException("Manual skill: "+label);}
            var sim=new HuntingSimulation(20);sim.SetParty(new[]{"mira"});var hero=sim.Battle.Heroes[0];var kit=sim.Battle.Kits[hero.Id];
            var enemy=sim.Battle.Enemies[0];sim.Battle.Enemies.RemoveRange(1,sim.Battle.Enemies.Count-1);enemy.Hp=enemy.MaxHp=100000;
            hero.Position=hero.PreviousPosition=Vector2.zero;enemy.Position=enemy.PreviousPosition=new Vector2(10,0);hero.Range=2;kit.Cooldowns["a1"]=0;
            Check(!sim.CanManualCast(hero.Id,"a1")&&!sim.ManualCast(hero.Id,"a1"),"out of range rejects without spending");
            Check(kit.Cooldowns["a1"]==0&&sim.ManualSkillCasts==0,"rejected range keeps resources");
            enemy.Position=enemy.PreviousPosition=new Vector2(.8f,0);hero.Stun=1;
            Check(!sim.CanManualCast(hero.Id,"a1")&&!sim.ManualCast(hero.Id,"a1"),"stunned actor rejects");hero.Stun=0;
            sim.Paused=true;Check(!sim.ManualCast(hero.Id,"a1"),"paused hunt rejects");sim.Paused=false;
            sim.Defeated=true;Check(!sim.ManualCast(hero.Id,"a1"),"defeated hunt rejects");sim.Defeated=false;
            Check(!sim.ManualCast("unknown","a1")&&!sim.ManualCast(hero.Id,"passive")&&!sim.ManualCast(hero.Id,"unknown"),"foreign actor and passive/unknown slots reject");
            hero.Ultimate=99;Check(!sim.ManualCast(hero.Id,"ultimate")&&hero.Ultimate==99,"unready ultimate rejects without spending");
            sim.Battle.SkillsAuto=false;sim.Battle.UltimateAuto=false;hero.AttackRemaining=0;sim.Step(.05);
            Check(hero.Windup>0,"automatic intent exists before manual replacement");
            double time=sim.Elapsed;int before=enemy.Hp;var position=hero.Position;
            Check(sim.CanManualCast(hero.Id,"a1")&&sim.ManualCast(hero.Id,"a1"),"eligible manual skill confirms");
            Check(sim.ManualSkillCasts==1&&kit.Casts.GetValueOrDefault("a1")==1,"one manual and one actual cast");
            Check(kit.Cooldowns["a1"]==LegacyCombatRules.Number(kit.Profiles["a1"],"cooldown",7),"same original cooldown");
            Check(enemy.Hp<before&&hero.Windup<0&&hero.AttackRemaining>=.24,"actual hit replaces outstanding automatic intent");
            Check(sim.Elapsed==time&&hero.Position==position&&Time.timeScale==1,"manual input does not advance time or teleport");
            before=enemy.Hp;double cooldown=kit.Cooldowns["a1"];
            Check(!sim.ManualCast(hero.Id,"a1")&&kit.Cooldowns["a1"]==cooldown&&enemy.Hp==before,"immediate duplicate spends and hits nothing");
            sim.Step(.1);Check(enemy.Hp==before&&kit.Casts["a1"]==1,"cancelled automatic attack does not replay");
            var result=new JObject{{"passed",true},{"comparisons",checks},{"actual_original_skill_execution",true},{"failed_input_spends_nothing",true},{"pending_automatic_intent_replaced_once",true},{"real_player_io",false}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/native-manual-skills.json",result.ToString());return result;
        }
    }
}
