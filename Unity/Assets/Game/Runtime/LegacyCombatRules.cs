using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    // Preserve every original skill field, including fields omitted from display DTOs.
    // Presentation and hit-stop never change these authoritative combat calculations.
    public sealed class OriginalCombatCatalog
    {
        readonly Dictionary<string, JObject> heroes;
        public IReadOnlyCollection<string> HeroIds => heroes.Keys;
        public OriginalCombatCatalog(string originalJson)
        {
            var root = JObject.Parse(originalJson);
            heroes = ((JArray)root["heroes"]).Cast<JObject>().ToDictionary(h => (string)h["id"], StringComparer.Ordinal);
            if (heroes.Count != 30 || heroes.Values.Sum(h => ((JArray)h["skills"]).Count) != 120)
                throw new ArgumentException("Expected the canonical 30 heroes / 120 skills.");
            foreach (var hero in heroes.Values)
                foreach (string slot in new[] { "passive", "a1", "a2", "ultimate" })
                    if (((JArray)hero["skills"]).Count(s => (string)s["slot"] == slot) != 1)
                        throw new ArgumentException("Invalid skill slots: " + hero["id"]);
        }
        public JObject Hero(string id) => (JObject)heroes[id].DeepClone();
        public JObject Skill(string id, string slot) => (JObject)((JArray)heroes[id]["skills"]).Single(s => (string)s["slot"] == slot).DeepClone();
        public JObject AdjustedSkill(string id, string slot, int utilityPoints)
        {
            var result = Skill(id, slot);
            var identity = (JObject)heroes[id]["identity_profile"];
            if (slot != "ultimate") result["cooldown"] = Math.Max(1.2, LegacyCombatRules.Number(result,"cooldown",7) * LegacyCombatRules.Number(identity,"skill_cooldown_mult",1) * (1-utilityPoints*.03));
            result["value"] = LegacyCombatRules.Number(result,"value",0) * LegacyCombatRules.Number(identity,"skill_value_mult",1);
            return result;
        }
    }

    public static class LegacyCombatRules
    {
        public static double Number(JObject source, string key, double fallback = 0)
        {
            var value=source?[key];
            if(value==null || value.Type==JTokenType.Null) return fallback;
            double number=value.Value<double>();
            return double.IsNaN(number)||double.IsInfinity(number) ? fallback : number;
        }
        public static int HitDamage(JObject skill,int attack,int enemyHp,int enemyMaxHp,bool elite,double scale=1)
        {
            if(enemyHp<=0 || attack<=0)return 0;
            double multiplier=Number(skill,"value",1)*Math.Max(0,scale);
            if(elite)multiplier*=Number(skill,"elite_bonus",1);
            double ratio=(double)enemyHp/Math.Max(1,enemyMaxHp);
            if(ratio<=Number(skill,"execute_threshold",-1))multiplier*=Number(skill,"execute_bonus",1);
            return Math.Max(1,(int)(attack*multiplier));
        }
        public static int HealAmount(JObject skill,int hp,int maxHp)
        {
            double amount=Math.Max(1,maxHp)*Number(skill,"value",.18)*Number(skill,"heal_scale",1);
            if((double)hp/Math.Max(1,maxHp)<=Number(skill,"emergency_threshold",-1))amount*=Number(skill,"emergency_bonus",1);
            return Math.Max(1,(int)amount);
        }
        public static int LifeSteal(JObject skill,int hp,int maxHp,int actualDamage)
        {
            if(actualDamage<=0)return 0;
            double amount=actualDamage*Number(skill,"lifesteal",.1);
            if((double)hp/Math.Max(1,maxHp)<=Number(skill,"low_hp_threshold",-1))amount*=Number(skill,"low_hp_sustain_bonus",1);
            return Math.Max(0,(int)amount);
        }
        public static bool NeedsEnemy(JObject skill) => !new[]{"guard","heal","barrier"}.Contains((string)skill["kind"]);
        public static double StatusDuration(double existing,double duration,bool alive)
            => !alive || double.IsNaN(duration) || double.IsInfinity(duration) || duration<=0 ? Math.Max(0,existing) : Math.Max(Math.Max(0,existing),Math.Min(duration,30));
        public static int ShieldAmount(int maxHp,double ratio) => (int)(Math.Max(1,maxHp)*Math.Max(0,Math.Min(.2,ratio)));
        public static int IncomingDamage(int raw,int defense,bool weakened,bool guarded,bool partyGuard)
        {
            double multiplier=(weakened?.65:1)*(guarded?.48:1)*(partyGuard?.70:1);
            return Math.Max(1,(int)(Math.Min(Math.Max(0,raw),1000000000)*multiplier)-(int)(defense*.35));
        }
    }

    public static class LegacyGrowthEconomy
    {
        public static int XpCost(int level,int maximumLevel)
        {
            level=Math.Max(1,Math.Min(maximumLevel,level));
            int late=Math.Max(0,level-20);
            return 100+(level-1)*75+late*late*8;
        }
        public static int EquipmentCost(string slot,int level)
        {
            level=Math.Max(1,Math.Min(10,level));int late=Math.Max(0,level-4);
            int multiplier=NativeEquipmentLayout.CostSlot(slot)=="armor"?2:NativeEquipmentLayout.CostSlot(slot)=="accessory"?3:1;
            return (int)((100+level*75)*(1+late*late*1.5))*multiplier;
        }
        public static (int gold,int xp,int rations) StageChest(int stage)
        {
            stage=Math.Max(1,Math.Min(10000,stage));
            double tier=stage<=25?stage:25+Math.Sqrt(stage-25);
            return (250+(int)Math.Floor(tier*50),100+(int)Math.Floor(tier*25),40+(int)Math.Floor(tier*3));
        }
    }
}
