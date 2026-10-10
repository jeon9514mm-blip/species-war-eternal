using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    // Observation only: actual HP loss, healing and consumed shielding. No RNG,
    // currency, progression, battle decisions or saved hero stats are changed.
    public sealed class NativeChallengeCombatLedger
    {
        readonly JObject actors=new(),opening=new();
        long support,unknown;
        CombatEncounter battle;
        public void Begin(CombatEncounter encounter,OriginalCombatCatalog catalog,bool skills,bool ultimates)
        {
            battle=encounter;opening["size"]=encounter.Heroes.Count;opening["skill_auto"]=skills;opening["ultimate_auto"]=ultimates;
            foreach(string role in new[]{"tank","damage","support","control","heal"})opening[role]=0;
            foreach(var h in encounter.Heroes.Take(10))
            {
                string group=(string)catalog.Hero(h.Id)["role_group"],role=group=="탱커"?"tank":group=="서포터"?"support":group=="컨트롤러"?"control":"damage";
                opening[role]=L.N(opening[role])+1;
                if(encounter.Kits[h.Id].Profiles.Values.Any(p=>(string)p["kind"]=="heal"&&!L.Flag(p["self_only"])))opening["heal"]=L.N(opening["heal"])+1;
                actors[h.Id]=new JObject{{"id",h.Id},{"name",catalog.Hero(h.Id)["name"]},{"slot",h.Slot},{"role",group},{"max_hp",h.MaxHp},{"hp",h.Hp},{"damage",0},{"damage_taken",0},{"healing_received",0},{"shield_absorbed",0},{"hits",0},{"criticals",0},{"kills",0},{"first_down_at",-1.0}};
            }
        }
        public void Observe(BattleEvent e,long credited,double elapsed)
        {
            if(battle==null)return;
            if(credited>0)
            {
                if(e.Source!=null&&actors[e.Source] is JObject source){Add(source,"damage",credited);Add(source,"hits",1);if(e.Kind=="critical")Add(source,"criticals",1);if(battle.Enemies.Find(t=>t.Serial==e.TargetSerial)?.Hp==0)Add(source,"kills",1);}
                else if(string.IsNullOrEmpty(e.Source))support=Math.Min(GameStateCommands.CurrencyCap,support+credited);else unknown=Math.Min(GameStateCommands.CurrencyCap,unknown+credited);
            }
            var target=battle.Heroes.Find(h=>h.Serial==e.TargetSerial);if(target==null||actors[target.Id] is not JObject row)return;
            if(e.Kind=="hero_hit")Add(row,"damage_taken",e.Amount);else if(e.Kind=="heal")Add(row,"healing_received",e.Amount);else if(e.Kind=="absorb")Add(row,"shield_absorbed",e.Amount);
            row["hp"]=target.Hp;if(target.Hp==0&&L.F(row["first_down_at"],-1)<0)row["first_down_at"]=elapsed;
        }
        static void Add(JObject row,string key,long amount)=>row[key]=Math.Min(GameStateCommands.CurrencyCap,L.N(row[key])+Math.Max(0,amount));
        public JObject Snapshot(double seconds,long total)
        {
            var rows=new JArray();foreach(var h in battle?.Heroes??new())if(actors[h.Id] is JObject row){var copy=(JObject)row.DeepClone();copy["hp"]=h.Hp;copy["dps"]=seconds>0?L.N(copy["damage"])/seconds:0;copy["share"]=total>0?L.N(copy["damage"])/(double)total:0;rows.Add(copy);}
            rows=new JArray(rows.OfType<JObject>().OrderByDescending(r=>L.N(r["damage"])).ThenBy(r=>L.N(r["slot"])));
            var advice=new JArray();var first=rows.OfType<JObject>().Where(r=>L.F(r["first_down_at"],-1)>=0).OrderBy(r=>L.F(r["first_down_at"])).FirstOrDefault();
            if(first!=null)advice.Add(first["name"]+" · "+first["first_down_at"]+"초 첫 전투 불능 · 생존 성장과 전열을 점검하세요.");
            if(L.N(opening["tank"])==0)advice.Add("탱커를 편성하면 전열의 피격을 분산할 수 있습니다.");
            if(L.N(opening["heal"])==0)advice.Add("회복 영웅을 편성해 장기 전투를 대비하세요.");
            if(!L.Flag(opening["skill_auto"])||!L.Flag(opening["ultimate_auto"]))advice.Add("자동 스킬 설정을 확인하세요.");
            return new JObject{{"actors",rows},{"opening",opening.DeepClone()},{"total_damage",total},{"support_damage",support},{"unknown_damage",unknown},{"dps",seconds>0?total/seconds:0},{"alive",rows.Count(r=>L.N(r["hp"])>0)},{"advice",advice}};
        }
    }
}
