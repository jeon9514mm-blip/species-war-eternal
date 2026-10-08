using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using static Eternal.UnityMigration.CombatTargeting;

namespace Eternal.UnityMigration
{
    // Port of HeroKitRuntime: cached immutable profiles, live authoritative state.
    // Failed casts spend nothing. Status bonus uses the pre-hit snapshot. Multi-hit
    // retargeting and absorption use actual damage; raids settle aggregated raw once.
    public static class HeroKitExecution
    {
        public static bool IsControl(string kind)=>kind=="stun"||kind=="weaken"||kind=="vulnerable";
        static string Kind(JObject p)=>(string)p["kind"]??"damage";
        static bool Moving(CombatEncounter b,Combatant h)=>b.IsRaid?b.Kits[h.Id].BasicCount>=b.Kits[h.Id].LastMoveBasic+3:Vector2.Distance(h.Position,b.Kits[h.Id].LastMovePosition)>=.6f;
        static void ConsumeMove(CombatEncounter b,Combatant h){var r=b.Kits[h.Id];r.LastMoveBasic=r.BasicCount;r.LastMovePosition=h.Position;}
        public static List<Combatant> Allies(CombatEncounter b,Combatant h,JObject p)
        {
            double Priority(Combatant a)
            {
                if(Kind(p)!="barrier")return a.HpRatio;
                int desired=Math.Max(1,LegacyCombatRules.ShieldAmount(a.MaxHp,N(p,"shield",.05)));
                int existing=a.ShieldSeconds>.35?a.Shield:0;
                return a.HpRatio+Math.Min(1,(double)existing/desired)*2-Math.Min(.35,b.IncomingThreat(a)/Math.Max(1,a.MaxHp));
            }
            int count=Math.Max(0,(int)N(p,"ally_targets",N(p,"heal_targets",1)));
            return b.Heroes.Where(a=>a.Alive&&(!B(p,"self_only")||a==h)&&(!B(p,"exclude_self")||a!=h)&&(p["ally_row"]==null||a.Row==(string)p["ally_row"]))
                .OrderBy(Priority).ThenBy(a=>a.Slot).Take(count).ToList();
        }
        public static bool CanUse(CombatEncounter b,Combatant h,string slot)
        {
            if(h==null||!h.Alive||!b.Kits.TryGetValue(h.Id,out var r)||!r.Profiles.TryGetValue(slot,out var p)||slot=="passive")return false;
            if(slot=="ultimate"?h.Ultimate<100:r.Cooldowns.GetValueOrDefault(slot)>0)return false;
            string kind=Kind(p);
            if((b.IsRaid&&b.Boss==null)||(!b.IsRaid&&kind!="heal"&&!b.Enemies.Any(e=>e.Alive&&!e.Returning)))return false;
            if(LegacyCombatRules.NeedsEnemy(p))return (!b.IsRaid||kind!="stun"||b.RaidControlWindow)&&Rank(b,h,p).Count>0;
            if(kind=="heal")return Allies(b,h,p).Any(a=>a.HpRatio<N(p,"threshold",.88));
            if(kind=="barrier")return Allies(b,h,p).Any(a=>a.ShieldSeconds<=.35||a.Shield<a.MaxHp*N(p,"shield",.05)*.5);
            if(kind=="guard")return b.Heroes.Any(a=>a.Alive&&((string)p["guard_scope"]=="party"||a==h)&&a.Guard<.5);
            return true;
        }
        public static int Priority(CombatEncounter b,Combatant h,string slot)
        {
            if(!CanUse(b,h,slot))return 0;
            var p=b.Kits[h.Id].Profiles[slot];string kind=Kind(p);
            var enemies=Targets(b,h,p,null);double lowest=1,threat=0;
            if(kind=="heal"||kind=="barrier"||kind=="guard")foreach(var ally in Allies(b,h,p)){lowest=Math.Min(lowest,ally.HpRatio);threat+=b.IncomingThreat(ally);}
            if(kind=="heal")return lowest<=.35?100:lowest<=.6?94:82;
            if((kind=="guard"||kind=="barrier")&&!b.IsRaid&&threat<=0&&!b.Heroes.Any(a=>a.Alive&&Rank(b,a,null).Count>0))return 0;
            if(kind=="barrier")return lowest<=.4&&threat>0?96:threat>0||lowest<.8?80:60;
            // Defensive decision port remains explicit: telegraph/incoming hits,
            // injury and missing guards are live inputs rather than periodic spam.
            if(kind=="guard")return b.BossTelegraph||threat>0?96:lowest<.6?88:60;
            if(enemies.Count==0 || (IsControl(kind)&&enemies.All(e=>e.Status(kind)>.35)))return 0;
            var only=enemies[0];
            if(enemies.Count==1&&!only.Elite&&only.Hp<=h.Attack&&(slot=="ultimate"||IsControl(kind)||B(p,"aoe")))return 0;
            int score=60+(slot=="ultimate"?5:0)+(IsControl(kind)?15:0);
            if(N(p,"moving_bonus",1)>1&&Moving(b,h))score+=12;
            if(B(p,"aoe"))score+=Math.Min(22,Math.Max(0,enemies.Count-1)*9);
            foreach(var e in enemies)
            {if(e.Elite)score=Math.Max(score,76);if(e.HpRatio<=N(p,"execute_threshold",-1))score=Math.Max(score,88);if(e.Debuffed&&N(p,"status_bonus",1)>1)score=Math.Max(score,82);}
            if(N(p,"lifesteal")>0&&h.HpRatio<=.6)score=Math.Max(score,h.HpRatio<=.35?95:87);
            return Math.Min(100,score);
        }
        public static string PreferredSlot(CombatEncounter b,Combatant h)
        {
            string best="basic";int score=54;
            foreach(string slot in new[]{"ultimate","a1","a2"})
            {if(slot=="ultimate"?!b.UltimateAuto:!b.SkillsAuto)continue;int next=Priority(b,h,slot);if(next>score){score=next;best=slot;}}
            return best;
        }
        public static List<Combatant> Targets(CombatEncounter b,Combatant h,JObject p,Combatant primary)
        {
            var result=Rank(b,h,p,primary);
            if(primary!=null&&result.Remove(primary))result.Insert(0,primary);
            int limit=B(p,"aoe")?Math.Max(1,(int)N(p,"max_targets",result.Count)):1;
            if(result.Count>limit)result.RemoveRange(limit,result.Count-limit);return result;
        }
        static void ApplyStatus(CombatEncounter b,Combatant h,Combatant e,string kind,double duration)
        {if(b.IsRaid&&kind=="stun"){if(b.RaidControlWindow)b.OnRaidControl?.Invoke(h,duration);}else e.ApplyStatus(kind,duration);}

        public static bool Cast(CombatEncounter b,Combatant h,string slot,Combatant primary=null)
        {
            if(!CanUse(b,h,slot))return false;
            var r=b.Kits[h.Id];var p=r.Profiles[slot];string kind=Kind(p);
            if(LegacyCombatRules.NeedsEnemy(p)&&!CombatTargeting.CanAttack(b,h,primary))return false;
            var targets=Targets(b,h,p,primary);var allies=(kind=="heal"||N(p,"shield")>0)?Allies(b,h,p):new List<Combatant>();
            if(slot=="ultimate")h.Ultimate=0;else r.Cooldowns[slot]=N(p,"cooldown",7);
            if(p["hp_cost"]!=null)h.Hp=Math.Max(1,h.Hp-(int)(h.Hp*N(p,"hp_cost")));
            if(kind=="guard")
            {
                double duration=N(p,"duration",2.4);
                foreach(var a in b.Heroes.Where(a=>a.Alive&&((string)p["guard_scope"]=="party"||a==h)))
                {a.Guard=Math.Max(a.Guard,duration);b.Emit("guard",h,slot,a);}
                if((string)p["guard_scope"]!="party")h.Taunt=Math.Max(h.Taunt,duration+.8);
                if(N(p,"self_heal")>0)b.Heal(h,h,(int)(h.MaxHp*N(p,"self_heal")),slot);
            }
            if(kind=="heal")foreach(var a in allies)b.Heal(h,a,LegacyCombatRules.HealAmount(p,a.Hp,a.MaxHp),slot);
            if(p["heal_value"]!=null)
            {
                var heal=new JObject{{"kind","heal"},{"value",p["heal_value"]},{"heal_targets",N(p,"heal_targets",1)}};
                foreach(var a in Allies(b,h,heal).Where(a=>a.Hp<a.MaxHp))b.Heal(h,a,LegacyCombatRules.HealAmount(heal,a.Hp,a.MaxHp),slot);
            }
            if(N(p,"shield")>0)foreach(var a in allies)b.Shield(h,a,N(p,"shield"),N(p,"duration",4),slot);
            int total=0;bool chained=false;
            if(LegacyCombatRules.NeedsEnemy(p))
            {
                int hits=Math.Max(1,(int)N(p,"hits",1));
                for(int hit=0;hit<hits;hit++)for(int ti=0;ti<targets.Count;ti++)
                {
                    var e=targets[ti];if(!CombatTargeting.CanAttack(b,h,e))
                    {if(B(p,"aoe"))continue;e=Rank(b,h,p).FirstOrDefault();if(e==null)continue;targets[ti]=e;}
                    bool debuffed=e.Debuffed;double enemyRatio=e.HpRatio;
                    if(IsControl(kind))ApplyStatus(b,h,e,kind,N(p,"duration",2));
                    if(p["status"]!=null)ApplyStatus(b,h,e,(string)p["status"],N(p,"status_duration",1.5));
                    double scale=1d/hits;
                    if(debuffed){scale*=N(p,"status_bonus",1);chained|=N(p,"status_bonus",1)>1;}
                    if(h.Guard>0)scale*=N(p,"guarded_bonus",1);
                    if(enemyRatio>=N(p,"high_hp_threshold",2))scale*=N(p,"high_hp_bonus",1);
                    if(h.HpRatio<=.5)scale*=N(p,"low_hp_damage_bonus",1);
                    if(Moving(b,h))scale*=N(p,"moving_bonus",1);
                    // Avoid mutating the cached profile when a raid override applies.
                    double value=N(p,"value");
                    int raw=0;
                    if(value>0)
                    {
                        double multiplier=(b.IsRaid&&p["raid_value"]!=null?N(p,"raid_value"):value)*Math.Max(0,scale);
                        if(e.Elite)multiplier*=N(p,"elite_bonus",1);
                        if(enemyRatio<=N(p,"execute_threshold",-1))multiplier*=N(p,"execute_bonus",1);
                        raw=Math.Max(1,(int)(h.Attack*multiplier));
                    }
                    total+=b.IsRaid?raw:b.DamageEnemy(h,e,raw,slot);
                }
            }
            int actual=b.IsRaid&&b.Boss!=null?(int)Math.Min(b.Boss.Hp,total*(b.Boss.Vulnerable>0?1.25:1)):total;
            if(p["lifesteal"]!=null)b.Heal(h,h,LegacyCombatRules.LifeSteal(p,h.Hp,h.MaxHp,actual),slot);
            if(p["self_heal"]!=null&&kind!="guard")b.Heal(h,h,(int)(h.MaxHp*N(p,"self_heal")),slot);
            if(p["self_guard"]!=null){h.Guard=Math.Max(h.Guard,N(p,"self_guard"));b.Emit("guard",h,slot,h);}
            if(p["taunt"]!=null)h.Taunt=Math.Max(h.Taunt,N(p,"taunt"));
            if(p["reduce_secondary"]!=null)r.Cooldowns["a2"]=Math.Max(0,r.Cooldowns.GetValueOrDefault("a2")-N(p,"reduce_secondary"));
            if(slot!="ultimate")b.GainUltimate(h,(slot=="a1"?15:9)+N(p,"energy"));
            if(p["moving_bonus"]!=null)ConsumeMove(b,h);
            r.Casts[slot]=r.Casts.GetValueOrDefault(slot)+1;
            b.Emit("cast",h,slot,primary,total,chained);
            total+=Event(b,h,"cast",primary);
            if(b.IsRaid&&total>0)b.DamageEnemy(h,b.Boss,total,slot);
            return true;
        }

        // Return raw raid damage; callers settle once. Field passive damage is
        // settled here. No synthetic proc is emitted when a condition fails.
        public static int Event(CombatEncounter b,Combatant h,string eventName,Combatant target=null,Combatant snapshot=null)
        {
            if(h==null||!h.Alive||!b.Kits.TryGetValue(h.Id,out var r))return 0;
            if(eventName=="basic")r.BasicCount++;
            var p=r.Profiles["passive"];if((string)p["event"]!=eventName)return 0;
            var e=snapshot??target;string condition=(string)p["condition"]??"";
            int injured=b.Heroes.Count(a=>a.Alive&&a.Hp<a.MaxHp);bool allowed=true;
            switch(condition)
            {
                case "guarded":allowed=h.Guard>0;break;
                case "injured_ally":allowed=injured>0;break;
                case "two_injured":allowed=injured>=2;break;
                case "shielded_ally":allowed=b.Heroes.Any(a=>a.Alive&&a.Shield>0);break;
                case "self_low":allowed=h.HpRatio<=.5;break;
                case "target_low":allowed=e!=null&&e.HpRatio<=.35;break;
                case "elite":allowed=e?.Elite??false;break;
                case "many_enemies":allowed=!b.IsRaid&&b.Enemies.Count(a=>a.Alive&&!a.Returning)>=2;break;
                case "moved":allowed=Moving(b,h);break;
                case "controlled":case "weakened":case "vulnerable":case "debuffed":
                    string status=condition=="controlled"?"stun":condition=="weakened"?"weaken":"vulnerable";
                    allowed=b.Enemies.Any(a=>a.Alive&&!a.Returning&&(condition=="debuffed"?a.Debuffed:a.Status(status)>0));break;
                case "same_target":int serial=target?.Serial??-1;if(r.PassiveTargetSerial!=serial)r.PassiveCount=0;r.PassiveTargetSerial=serial;break;
            }
            if(!allowed||r.PassiveRemaining>0)return 0;
            r.PassiveCount++;if(r.PassiveCount<(int)N(p,"every",1))return 0;
            r.PassiveCount=0;r.PassiveRemaining=N(p,"cooldown");r.PassiveProcs++;
            if(condition=="moved")ConsumeMove(b,h);
            double value=N(p,"value");var lowest=b.Heroes.Where(a=>a.Alive).OrderBy(a=>a.HpRatio).ThenBy(a=>a.Slot).FirstOrDefault();
            b.Emit("passive",h,"passive",target);
            switch((string)p["action"])
            {
                case "energy":b.GainUltimate(h,value);break;
                case "cooldown":r.Cooldowns["a2"]=Math.Max(0,r.Cooldowns.GetValueOrDefault("a2")-value);break;
                case "heal":b.Heal(h,h,(int)(h.MaxHp*value),"passive");break;
                case "ally_heal":if(lowest!=null)b.Heal(h,lowest,(int)(lowest.MaxHp*value),"passive");break;
                case "shield":b.Shield(h,h,value,4,"passive");break;
                case "ally_shield":b.Shield(h,lowest,value,4,"passive");break;
                case "guard":h.Guard=Math.Max(h.Guard,value);break;
                case "ally_guard":if(lowest!=null)lowest.Guard=Math.Max(lowest.Guard,value);break;
                case "damage":int damage=(int)(h.Attack*value);return b.IsRaid?damage:CombatTargeting.CanAttack(b,h,target)?b.DamageEnemy(h,target,damage,"passive"):0;
            }
            return 0;
        }
    }
}
