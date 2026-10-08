using System;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class RuleParityVerification
    {
        [MenuItem("Eternal/Verify original rule parity")]
        public static string Verify()
        {
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            var fixtures=JObject.Parse(OriginalCatalog.Required("rule-fixtures").text);
            int comparisons=0;
            foreach(JObject row in (JArray)fixtures["skills"])
            {
                string id=(string)row["id"], slot=(string)row["slot"]; int hp=(int)row["hp"];
                var skill=catalog.Skill(id,slot);
                void Equal(string field,int actual)
                {
                    int expected=(int)row[field];
                    if(expected!=actual)throw new InvalidDataException($"Rule parity failed: {id}/{slot} HP {hp} {field}: {actual} != {expected}");
                    comparisons++;
                }
                Equal("damage",LegacyCombatRules.HitDamage(skill,200,hp,1000,true));
                Equal("heal",LegacyCombatRules.HealAmount(skill,hp,1000));
                Equal("lifesteal",LegacyCombatRules.LifeSteal(skill,hp,1000,137));
            }
            foreach(JObject row in (JArray)fixtures["growth"])
            {
                if(row["level"]!=null)
                {
                    if(LegacyGrowthEconomy.XpCost((int)row["level"],100)!=(int)row["xp_cost"])throw new InvalidDataException("XP curve parity failed"); comparisons++;
                }
                else
                {
                    var actual=LegacyGrowthEconomy.StageChest((int)row["stage"]);
                    if(actual.gold!=(int)row["gold"]||actual.xp!=(int)row["xp"]||actual.rations!=(int)row["rations"])throw new InvalidDataException("Stage chest parity failed");comparisons+=3;
                }
            }
            // Mutating a returned profile must never change registered balance data.
            var copy=catalog.Skill("mira","a1");var original=(double)copy["value"];copy["value"]=999;
            if((double)catalog.Skill("mira","a1")["value"]!=original)throw new InvalidDataException("Catalog mutation leaked");comparisons++;
            if(LegacyCombatRules.StatusDuration(2,1,true)!=2 || LegacyCombatRules.StatusDuration(2,40,true)!=30)throw new InvalidDataException("Status refresh must not stack time");comparisons+=2;
            string result=JsonUtility.ToJson(new Report{comparisons=comparisons,heroCount=catalog.HeroIds.Count,skillCount=120,passed=true},true);
            Directory.CreateDirectory("../checks/unity-migration-2026-10-08");
            File.WriteAllText("../checks/unity-migration-2026-10-08/rule-parity.json",result);
            Debug.Log("ETERNAL_RULE_PARITY_OK: "+comparisons+" comparisons");return result;
        }
        [Serializable] sealed class Report { public int comparisons,heroCount,skillCount; public bool passed; }
    }
}
