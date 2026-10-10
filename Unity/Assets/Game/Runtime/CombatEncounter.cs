using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration
{
    public sealed class Combatant
    {
        public string Id, Role="", Style="balanced", Row="front", Archetype="brute", TargetId="";
        public int Serial, Slot, EnemyRow, Hp, MaxHp, Attack, Defense, Shield, Range=2;
        public bool Elite, Returning;
        public Vector2 Position, PreviousPosition, Velocity;
        public double Guard, Taunt, ShieldSeconds, Stun, Weaken, Vulnerable, Ultimate,ArmorBreak,Bleed;
        public double AttackIntervalMultiplier=1, UltimateGainMultiplier=1, AttackRemaining, Windup=-1;
        public bool Alive => Hp>0;
        public double HpRatio => (double)Hp/Math.Max(1,MaxHp);
        public bool Debuffed => Stun>0 || Weaken>0 || Vulnerable>0||ArmorBreak>0||Bleed>0;
        public double Status(string name) => name=="stun"?Stun:name=="weaken"?Weaken:name=="vulnerable"?Vulnerable:0;
        public void ApplyStatus(string name,double duration)
        {
            duration=LegacyCombatRules.StatusDuration(Status(name),duration,Alive);
            if(name=="stun")Stun=duration; else if(name=="weaken")Weaken=duration; else if(name=="vulnerable")Vulnerable=duration;
        }
        public void Tick(double dt)
        {
            Guard=Math.Max(0,Guard-dt);Taunt=Math.Max(0,Taunt-dt);
            ShieldSeconds=Math.Max(0,ShieldSeconds-dt);if(ShieldSeconds<=0 || !Alive)Shield=0;
            Stun=Math.Max(0,Stun-dt);Weaken=Math.Max(0,Weaken-dt);Vulnerable=Math.Max(0,Vulnerable-dt);
            ArmorBreak=Math.Max(0,ArmorBreak-dt);Bleed=Math.Max(0,Bleed-dt);
            AttackRemaining=Math.Max(0,AttackRemaining-dt);
        }
    }

    public sealed class HeroKitState
    {
        public readonly Dictionary<string,JObject> Profiles=new(StringComparer.Ordinal);
        public readonly Dictionary<string,double> Cooldowns=new(StringComparer.Ordinal);
        public int Utility, BasicCount, LastMoveBasic, PassiveCount, PassiveProcs;
        public int PassiveTargetSerial=-1;
        public double PassiveRemaining;
        public Vector2 LastMovePosition;
        public readonly Dictionary<string,int> Casts=new(StringComparer.Ordinal);
        public HeroKitState(OriginalCombatCatalog catalog,string id,int utility,Vector2 origin)
        {
            Utility=utility;LastMovePosition=origin;
            foreach(string slot in new[]{"passive","a1","a2","ultimate"})Profiles[slot]=slot=="passive"?catalog.Skill(id,slot):catalog.AdjustedSkill(id,slot,utility);
        }
    }

    // Presentation observes confirmed settlements only; it cannot advance combat,
    // credit rewards or change time scale. Stable target serials survive pack reuse.
    public readonly struct BattleEvent
    {
        public readonly string Kind,Source,Slot,Target;
        public readonly int Amount,TargetSerial,SourceSerial;
        public readonly Vector2 Position;
        public readonly bool Chain;
        public BattleEvent(string kind,Combatant source,string slot,Combatant target,int amount=0,bool chain=false)
        {Kind=kind;Source=source?.Id;SourceSerial=source?.Serial??-1;Slot=slot;Target=target?.Id;TargetSerial=target?.Serial??-1;Amount=amount;Position=target?.Position??source?.Position??Vector2.zero;Chain=chain;}
    }

    public sealed class CombatEncounter
    {
        public readonly List<Combatant> Heroes=new(),Enemies=new();
        public readonly Dictionary<string,HeroKitState> Kits=new(StringComparer.Ordinal);
        public bool IsRaid, RaidControlWindow, BossTelegraph, SkillsAuto=true, UltimateAuto=true;
        public int EncounterSerial;
        public double PartyGuard, CriticalChance;
        public readonly System.Random Random;
        public Action<BattleEvent> OnEvent;
        public Action<Combatant,double> OnRaidControl;
        public Func<Combatant,int,int> RaidDamageSettlement;
        public CombatEncounter(int seed=9514) {Random=new System.Random(seed);}
        public Combatant Boss => Enemies.FirstOrDefault(e=>e.Alive && e.Elite);
        public double IncomingThreat(Combatant ally)
            => IsRaid ? (BossTelegraph?Boss?.Attack??0:0) : Enemies.Where(e=>e.Alive&&!e.Returning&&e.TargetId==ally.Id&&e.Stun<=.35).Sum(e=>Math.Max(0,e.Attack));
        public void Emit(string kind,Combatant source,string slot,Combatant target,int amount=0,bool chain=false)
            => OnEvent?.Invoke(new BattleEvent(kind,source,slot,target,amount,chain));
        public void GainUltimate(Combatant hero,double value)
        {if(hero.Alive)hero.Ultimate=Math.Clamp(hero.Ultimate+value*(1+Kits[hero.Id].Utility*.05)*hero.UltimateGainMultiplier,0,100);}
        public int Heal(Combatant source,Combatant target,int amount,string slot)
        {
            if(target==null || !target.Alive || amount<=0)return 0;
            int actual=Math.Min(target.MaxHp-target.Hp,amount);target.Hp+=actual;
            if(actual>0)Emit("heal",source,slot,target,actual);return actual;
        }
        public void Shield(Combatant source,Combatant target,double ratio,double duration,string slot)
        {
            if(target==null || !target.Alive)return;
            int old=target.Shield;target.Shield=Math.Max(old,LegacyCombatRules.ShieldAmount(target.MaxHp,ratio));
            target.ShieldSeconds=Math.Max(target.ShieldSeconds,Math.Min(duration,8));
            Emit("shield",source,slot,target,target.Shield-old);
        }
        public int DamageEnemy(Combatant source,Combatant enemy,int raw,string slot)
        {
            if(enemy==null || !enemy.Alive || enemy.Returning || raw<=0)return 0;
            bool crit=CriticalChance>0 && Random.NextDouble()<CriticalChance;
            if(IsRaid && enemy.Elite && RaidDamageSettlement!=null)
            {
                int settled=RaidDamageSettlement(enemy,(int)(Math.Min(raw,1000000000d)*(crit?1.5:1)));
                if(settled>0)Emit(crit?"critical":"damage",source,slot,enemy,settled);
                if(!enemy.Alive)Emit("death",source,slot,enemy);return settled;
            }
            double multiplier=(enemy.Vulnerable>0?1.25:1)*(crit?1.5:1);
            int actual=(int)Math.Min(enemy.Hp,Math.Min(raw,1000000000d)*multiplier);
            enemy.Hp-=actual;Emit(crit?"critical":"damage",source,slot,enemy,actual);
            if(!enemy.Alive)Emit("death",source,slot,enemy);return actual;
        }
        public int DamageHero(Combatant enemy,Combatant hero,int raw)
        {
            if(hero==null || !hero.Alive || raw<=0)return 0;
            int damage=LegacyCombatRules.IncomingDamage(raw,Math.Max(0,hero.Defense-(hero.ArmorBreak>0?4:0)),enemy.Weaken>0,hero.Guard>0,PartyGuard>0);
            int absorbed=Math.Min(hero.Shield,damage);hero.Shield-=absorbed;damage-=absorbed;
            if(absorbed>0)Emit("absorb",enemy,"basic",hero,absorbed);
            int actual=Math.Min(hero.Hp,damage);hero.Hp-=actual;Emit("hero_hit",enemy,"basic",hero,actual);
            if(hero.Alive){int passive=HeroKitExecution.Event(this,hero,"hit",enemy);if(IsRaid&&passive>0)DamageEnemy(hero,Boss,passive,"passive");}
            if(!hero.Alive)Emit("death",enemy,"basic",hero);return actual;
        }
        public void TickStatuses(double dt)
        {
            if(dt<=0 || !double.IsFinite(dt))return;
            PartyGuard=Math.Max(0,PartyGuard-dt);
            foreach(var actor in Heroes)actor.Tick(dt);foreach(var enemy in Enemies)enemy.Tick(dt);
            foreach(var kit in Kits.Values)
            {
                kit.PassiveRemaining=Math.Max(0,kit.PassiveRemaining-dt);
                foreach(string slot in new[]{"a1","a2"})kit.Cooldowns[slot]=Math.Max(0,kit.Cooldowns.GetValueOrDefault(slot)-dt);
            }
        }
    }

    public static class CombatTargeting
    {
        public static double Reach(Combatant hero) => hero.Range<=1?.95:hero.Range==2?1.32:1.75;
        public static bool CanAttack(CombatEncounter battle,Combatant hero,Combatant enemy)
            => hero!=null&&hero.Alive&&enemy!=null&&enemy.Alive&&!enemy.Returning&&(battle.IsRaid || Vector2.Distance(hero.Position,enemy.Position)<=Reach(hero));
        public static double BaseScore(Combatant hero,Combatant enemy,int index)
        {
            double ratio=enemy.HpRatio,score=ratio+index*.03;
            if(enemy.Elite)score-=.24;
            if(enemy.Archetype=="support")score-=.20;else if(enemy.Archetype=="assassin")score-=.10;
            if(hero.Role=="탱커")score=enemy.EnemyRow+index*.02-(enemy.Elite?.12:0);
            else if(hero.Role=="컨트롤러" || hero.Style=="controller" || hero.Style=="control")
            {score=-enemy.Attack*.01+ratio*.25+index*.01;if(enemy.Archetype=="support"||enemy.Archetype=="assassin")score-=.25;if(enemy.Elite)score-=.20;}
            switch(hero.Style)
            {
                case "finisher":score+=ratio*.55;if(enemy.Archetype=="support"||enemy.Archetype=="assassin")score-=.08;if(enemy.EnemyRow>0)score-=.05;break;
                case "protector":score-=Math.Min(.22,enemy.Attack*.003);if(enemy.Archetype=="assassin")score-=.1;break;
                case "controller":case "control":if(enemy.Elite)score-=.08;if(enemy.Archetype=="support")score-=.1;break;
                case "aggressive":score-=enemy.Archetype=="support"?.24:enemy.Archetype=="ranged"?.16:enemy.Archetype=="assassin"?.06:0;break;
                case "support":score+=enemy.EnemyRow*.06+Math.Min(.1,enemy.Attack*.001);break;
                case "sustain":if(hero.HpRatio<.6){score+=Math.Min(.16,enemy.Attack*.002);if(enemy.Hp<Math.Max(1,hero.Attack)*.5)score+=.85;}break;
            }
            return score;
        }
        public static List<Combatant> Rank(CombatEncounter battle,Combatant hero,JObject p,Combatant previous=null,bool reachable=true)
        {
            string kind=(string)p?["kind"]??"damage",status=HeroKitExecution.IsControl(kind)?kind:(string)p?["status"]??"";
            double Score(Combatant enemy)
            {
                double score=BaseScore(hero,enemy,enemy.Slot),ratio=enemy.HpRatio;
                if(ratio<=N(p,"execute_threshold",-1))score-=.85*Math.Max(0,N(p,"execute_bonus",1)-1);
                if(ratio>=N(p,"high_hp_threshold",2)&&N(p,"high_hp_bonus",1)>1)score-=.65+Math.Max(0,N(p,"high_hp_bonus",1)-1);
                if(enemy.Elite)score-=.75*Math.Max(0,N(p,"elite_bonus",1)-1);
                if(enemy.Debuffed)score-=1.2*Math.Max(0,N(p,"status_bonus",1)-1);
                if(enemy.Status(status)>.35)score+=1.5;
                if(N(p,"lifesteal")>0&&hero.HpRatio<.6)score+=1.65*(1-Math.Min(1,enemy.Hp/Math.Max(1,hero.Attack*N(p,"value",1))));
                if(enemy==previous)score-=N(p,"target_retention_bonus",.07);
                return score;
            }
            return battle.Enemies.Where(e=>e.Alive&&!e.Returning&&(!reachable||CanAttack(battle,hero,e))&&!(B(p,"avoid_active_status")&&HeroKitExecution.IsControl(kind)&&e.Status(kind)>0))
                .OrderBy(e=>HeroKitExecution.IsControl(kind)&&e.Status(kind)>.35?1:0).ThenBy(Score).ThenBy(e=>e.Slot).ToList();
        }
        internal static double N(JObject p,string key,double fallback=0)=>LegacyCombatRules.Number(p,key,fallback);
        internal static bool B(JObject p,string key)=>p?[key]?.Value<bool>()??false;
    }
}
