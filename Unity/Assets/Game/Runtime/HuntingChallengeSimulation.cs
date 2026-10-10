using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingSimulation
    {
        public LegacyChallengeSession Challenge {get;private set;}
        readonly Dictionary<int,(double cooldown,double cast,int heals,Combatant target)> challengePatterns=new();
        public void AttachChallenge(LegacyChallengeSession session)
        {if(Ticks!=0||session==null)throw new InvalidOperationException("Attach to a new simulation.");Challenge=session;Challenge.AttachLedger(Battle,Catalog);Battle.Enemies.Clear();SpawnChallengeWave();}
        static readonly Dictionary<string,string> monsterIds=new(){{"가시 멧돼지","bristle_boar"},{"초원 고블린","goblin"},{"들개 무리","wild_dog"},{"바람 까마귀","wind_crow"},{"광산 오크","mine_orc"},{"철갑 두더지","iron_mole"},{"수정 거미","crystal_spider"},{"용암 박쥐","lava_bat"},{"달빛 늑대","moon_wolf"},{"밤까마귀","night_raven"},{"숲의 망령","forest_wraith"},{"독버섯 정령","mushroom"}};
        void SpawnChallengeWave()
        {
            Battle.Enemies.Clear();behaviorRemaining.Clear();personalities.Clear();intents.Clear();enemyHits.Clear();enemySkillNext.Clear();challengePatterns.Clear();Battle.EncounterSerial++;
            int wave=Challenge.Waves,run=(int)L.N(Challenge.Entry["run_index"],0,4),floor=(int)L.N(Challenge.Entry["floor"],1,9999);
            JArray names=null;
            if(Challenge.Mode=="tower")names=L.Array(floor%5==0&&wave==2?L.Data["definitions"]["tower"]["BOSS_WAVE"]:L.Data["definitions"]["tower"]["FORMATIONS"][(floor-1)%3]["waves"][wave]);
            string[] zoneIds=Zone=="gray_meadow"?new[]{"goblin","wild_dog","bristle_boar","wind_crow"}:Zone=="forgotten_mine"?new[]{"mine_orc","iron_mole","crystal_spider","lava_bat"}:new[]{"moon_wolf","forest_wraith","mushroom","night_raven","frost_deer"};
            int count=Challenge.Mode=="tower"?names.Count:Challenge.Mode=="weekly"?1:Challenge.Variant=="survival"?4:Challenge.Variant=="boss_hunt"?1:6;
            for(int i=0;i<count;i++)
            {
                string id=names==null?Challenge.Mode=="weekly"?"iron_mole":zoneIds[i%zoneIds.Length]:monsterIds.GetValueOrDefault((string)names[i],"goblin");int hp,attack;bool elite=false;double rate=1;
                if(Challenge.Mode=="tower")
                {elite=floor%5==0&&wave==2&&i==0;hp=elite?850+floor*110:100+floor*28+wave*20+(i%2)*12;attack=elite?20+floor*5:8+floor*3+wave*2;}
                else if(Challenge.Mode=="weekly")
                {int mutator=(int)(long.Parse((string)Challenge.Entry["week"])%3);hp=mutator==0?11250:9000;attack=mutator==1?31:26;rate=mutator==2?1.2:1;elite=true;}
                else if(Challenge.Variant=="survival")
                {int p=Math.Min(wave,4);hp=90+run*24+p*18;attack=11+run*3+p*2;elite=p>=2&&i==0;}
                else if(Challenge.Variant=="boss_hunt"){hp=625+run*250;attack=24+run*6;elite=true;}
                else {int p=Math.Min(wave,2);hp=105+run*42+p*25+(i%2)*18;attack=7+run*3+p*2;elite=p==2&&i==0;}
                if(elite)hp*=2;
                string role=id=="mushroom"?"support":new[]{"wind_crow","crystal_spider","lava_bat","night_raven"}.Contains(id)?"ranged":"brute";
                var position=HuntFormationLayout.Entrance(i,Battle.EncounterSerial);
                Battle.Enemies.Add(new Combatant{Id=id,Serial=++serial,Slot=i,Hp=hp,MaxHp=hp,Attack=attack,Archetype=role,Elite=elite,EnemyRow=role=="brute"?0:2,Position=position,PreviousPosition=position,AttackRemaining=.7+i*.12,AttackIntervalMultiplier=1/rate});
                behaviorRemaining[serial]=1+Battle.Random.NextDouble()*7;personalities[serial]=Battle.Random.Next(4);
            }
            if(Challenge.PatternActive)
            {
                var leader=Battle.Enemies[0];
                if(Challenge.Mode=="weekly"&&(Challenge.Pattern=="healing_guard"||Challenge.Pattern=="split_pack"))
                {
                    int hp=Math.Max(1,(int)(leader.MaxHp*(Challenge.Pattern=="healing_guard"?.08:.20))),atk=Math.Max(1,(int)(leader.Attack*.20));leader.Hp-=hp*2;leader.MaxHp=leader.Hp;leader.Attack=Math.Max(1,leader.Attack-atk*2);
                    for(int i=0;i<2;i++){var position=leader.Position+new Vector2(1.3f,i==0?-1.6f:1.6f);Battle.Enemies.Add(new Combatant{Id=Challenge.Pattern=="healing_guard"?"mushroom":i==0?"crystal_spider":"moon_wolf",Serial=++serial,Slot=i+1,Hp=hp,MaxHp=hp,Attack=atk,Archetype=Challenge.Pattern=="healing_guard"?"support":"ranged",EnemyRow=2,Position=position,PreviousPosition=position,AttackRemaining=.8,AttackIntervalMultiplier=leader.AttackIntervalMultiplier});behaviorRemaining[serial]=1;personalities[serial]=2;}
                }
                if(Challenge.Pattern=="healing_guard"&&Battle.Enemies.Count>1)
                    foreach(var enemy in Battle.Enemies.Skip(Challenge.Mode=="weekly"?1:Battle.Enemies.Count-1)){enemy.Id="mushroom";enemy.Archetype="support";challengePatterns[enemy.Serial]=(4,0,3,null);}
                else if(Challenge.Pattern=="charged_strike")challengePatterns[leader.Serial]=(5,0,0,null);
                else if(Challenge.Pattern=="split_pack")for(int i=0;i<Battle.Enemies.Count;i++){var enemy=Battle.Enemies[i];enemy.Position+=new Vector2(i%2==0?-1.4f:1.3f,(i/2)*1.8f);enemy.PreviousPosition=enemy.Position;}
            }
            Challenge.Register(Battle.Enemies);OnEvent?.Invoke(new BattleEvent("pack",null,"challenge",null));
        }
        void ObserveChallengeEvent(BattleEvent e)
        {
            if(Challenge==null||!Challenge.Running)return;long previous=Challenge.Damage;
            if(e.Kind=="damage"||e.Kind=="critical"){var enemy=Battle.Enemies.FirstOrDefault(a=>a.Serial==e.TargetSerial);if(enemy!=null)Challenge.ObserveHp(enemy,enemy.Hp+e.Amount,enemy.Hp);}
            Challenge.Ledger.Observe(e,Challenge.Damage-previous,Challenge.Elapsed);
        }
        bool AdvanceChallengePattern(Combatant enemy,double dt)
        {
            if(!challengePatterns.TryGetValue(enemy.Serial,out var p))return false;
            if(enemy.Stun>0||enemy.Returning){p.cast=0;p.target=null;p.cooldown=7;challengePatterns[enemy.Serial]=p;return true;}
            if(Challenge.Pattern=="healing_guard")
            {if(p.heals<=0)return true;p.cooldown-=dt;if(p.cooldown<=0){p.cooldown=4;var leader=Battle.Enemies[0];if(leader.Alive&&!leader.Returning&&Vector2.Distance(enemy.Position,leader.Position)<=4.5){int heal=Battle.Heal(enemy,leader,Math.Max(1,(int)(leader.MaxHp*.04)),"support");if(heal>0)p.heals--;}}challengePatterns[enemy.Serial]=p;return true;}
            if(p.cast>0)
            {p.cast-=dt;if(p.cast<=0){p.cooldown=7;if(p.target?.Alive==true&&Vector2.Distance(enemy.Position,p.target.Position)<=EnemyReach(enemy))Battle.DamageHero(enemy,p.target,enemy.Attack*2);p.target=null;}challengePatterns[enemy.Serial]=p;return true;}
            p.cooldown-=dt;if(p.cooldown<=0){var target=EnemyTarget(enemy,true);if(target!=null){p.target=target;p.cast=2;Battle.Emit("windup",enemy,"charged_strike",target);}}
            challengePatterns[enemy.Serial]=p;return p.cast>0;
        }
    }
}
