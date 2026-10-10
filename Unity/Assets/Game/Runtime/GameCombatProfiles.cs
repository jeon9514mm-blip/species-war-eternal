using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        public int PracticeMatchedLevel;
        public bool IsFactionHero(string id)=>ValidHero(data,id);
        public IReadOnlyList<string> DeployedHeroes()
        {
            var result=new List<string>();
            foreach(var token in data["deployed_hero_ids"] as JArray??new JArray())
            {if(token.Type!=JTokenType.String)continue;string id=(string)token;if(ValidHero(data,id)&&!result.Contains(id)&&result.Count<10)result.Add(id);}
            return result;
        }
        public string Formation
        {
            get{string id=data["formation_id"]?.Type==JTokenType.String?(string)data["formation_id"]:"balanced";return FormationProfiles[id]!=null?id:"balanced";}
        }
        static JObject FormationProfiles=>(JObject)HuntingSimulation.Canonical["catalogs"]["formation"]["data"]["PROFILES"];
        static JObject GuardianDefinitions=>(JObject)HuntingSimulation.Canonical["catalogs"]["guardian"]["data"]["DEFINITIONS"];
        public string EquippedGuardian
        {
            get
            {
                string id=data["guardian_equipped"]?.Type==JTokenType.String?(string)data["guardian_equipped"]:"";
                if(GuardianDefinitions[id] is JObject&&(data["guardian_collection"] as JObject)?[id] is JObject)return id;
                return Faction=="aurelia"?"lumi":Faction=="noxfera"?"umbra":"";
            }
        }
        public double GuardianBonus(string key)
        {
            string id=EquippedGuardian;if(GuardianDefinitions[id] is not JObject profile)return 0;
            long copies=Integer(((data["guardian_collection"] as JObject)?[id] as JObject)?["copies"],1,1,CurrencyCap);
            int resonance=(int)Math.Min(3,1+Math.Max(0,copies-1)/3);
            return LegacyCombatRules.Number(profile["bonuses"] as JObject,key)*(1+(resonance-1)*.10);
        }
        public JObject PartySynergy(IReadOnlyList<string> party=null)
        {
            var ids=(party??DeployedHeroes()).Where(id=>ValidHero(data,id)).Distinct().Take(10).ToArray();
            double power=1,hp=1;var labels=new List<string>();int count=ids.Length;
            if(count>=3){power+=.05;labels.Add("3인 결속 +5% 전투력");}
            if(count>=6){power+=.07;hp+=.05;labels.Add("6인 전술대 +7% 전투력/+5% HP");}
            if(count>=10){power+=.08;hp+=.10;labels.Add("10인 대원정대 +8% 전투력/+10% HP");}
            var races=new Dictionary<string,int>(StringComparer.Ordinal);var roles=new Dictionary<string,int>(StringComparer.Ordinal);
            foreach(string id in ids){var h=catalog.Hero(id);string race=(string)h["race"],role=(string)h["role_group"];races[race]=races.GetValueOrDefault(race)+1;roles[role]=roles.GetValueOrDefault(role)+1;}
            if(Faction=="aurelia")
            {
                if(races.GetValueOrDefault("휴먼")>=3){hp+=.08;labels.Add("휴먼 방진 +8% HP");}
                if(races.GetValueOrDefault("엘프")>=3){power+=.07;labels.Add("엘프 별숲 +7% 전투력");}
            }
            else if(Faction=="noxfera")
            {
                if(races.GetValueOrDefault("뱀파이어")>=3){power+=.07;labels.Add("혈월 결속 +7% 전투력");}
                if(races.GetValueOrDefault("늑대인간")>=3){hp+=.08;labels.Add("사냥 무리 +8% HP");}
            }
            if(roles.GetValueOrDefault("탱커")>=2&&roles.GetValueOrDefault("딜러")>=3&&roles.GetValueOrDefault("서포터")+roles.GetValueOrDefault("컨트롤러")>=2)
            {power+=.08;hp+=.05;labels.Add("균형 진형 +8% 전투력/+5% HP");}
            return new JObject{{"power_multiplier",power},{"hp_multiplier",hp},{"summary",labels.Count>0?string.Join(" · ",labels):"없음 (3인부터 결속 발동)"}};
        }
        public int CollectionTier
        {
            get
            {
                var bank=((data["long_term_goals"] as JObject)?["factions"] as JObject)?[Faction] as JObject;if(bank==null)return 0;
                int count=(bank["discovered"] as JObject)?.Count??0,tier=0;var achievements=bank["achievements"] as JObject;
                foreach(int threshold in new[]{5,10,15})if(count>=threshold&&achievements?["collection_"+threshold]?.Type==JTokenType.Boolean&&(bool)achievements["collection_"+threshold])tier++;
                return tier;
            }
        }
        static int RoundStat(double value,int minimum=1)=>Math.Max(minimum,(int)Math.Round(value,MidpointRounding.AwayFromZero));
        public JObject CombatProfile(string id,int slot=0,IReadOnlyList<string> party=null)
        {
            if(!ValidHero(data,id)||slot<0||slot>=10)return new JObject();
            var hero=catalog.Hero(id);var identity=(JObject)hero["identity_profile"];string role=(string)hero["role_group"];
            int level=PracticeActive&&PracticeMatchedLevel>0?Math.Clamp(PracticeMatchedLevel,1,100):HeroProgress(id).level;var tree=HeroTree(id);var equipment=Snapshot();int power=GearPower(equipment,id);var set=GearProfile(equipment,id);
            int baseHp=role=="탱커"?560:role=="서포터"?405:role=="컨트롤러"?390:360,defense=role=="탱커"?18:role=="서포터"?9:role=="컨트롤러"?8:6;
            double grade=Grade(id) switch{"SR"=>1.08,"SSR"=>1.18,"UR"=>1.32,_=>1},partyHp=(double)PartySynergy(party)["hp_multiplier"];
            double N(JObject o,string key,double fallback=0)=>LegacyCombatRules.Number(o,key,fallback);
            int hp=Math.Max(120,(int)((baseHp+level*42+power*.45)*partyHp*(1+tree.survival*.05)*grade*N(set,"hp_mult",1)*N(identity,"hp_mult",1)));
            hp=RoundStat(hp*(1+CollectionTier*.005),120);
            int attack=Math.Max(12,(int)((24+level*5+(int)(power*.18))*(1+tree.offense*.04)*grade*N(set,"attack_mult",1)*N(identity,"attack_mult",1)));
            defense+=tree.survival+(int)N(set,"defense_bonus")+(int)N(identity,"defense_bonus");
            if(role=="딜러")attack=(int)(attack*1.18);else if(role=="탱커")attack=(int)(attack*.84);
            attack=RoundStat(attack*(1+GuardianBonus("attack")));var formation=(JObject)FormationProfiles[Formation];
            hp=RoundStat(hp*N(formation,"hp",1));attack=RoundStat(attack*N(formation,"attack",1));
            return new JObject{{"hp",hp},{"max_hp",hp},{"attack",attack},{"defense",defense},{"role_group",role},{"slot",slot},{"row",LegacyHeroLayout.Row(slot)},{"range",LegacyHeroLayout.Range(hero,slot)},{"ultimate",0.0},{"ai_style",(string)identity["ai_style"]??"balanced"},{"attack_interval_mult",N(identity,"attack_interval_mult",1)/(1+N(set,"haste_pct")/100)/N(formation,"speed",1)},{"ult_gain_mult",N(identity,"ult_gain_mult",1)*(1+N(set,"ultimate_pct")/100)},{"guard",0.0},{"taunt",0.0},{"alive",true}};
        }
        public static void RefreshCombatant(Combatant actor,JObject profile)
        {
            if(profile.Count==0)throw new ArgumentException("A valid original hero profile is required.");
            double ratio=Math.Clamp(actor.HpRatio,0,1);bool alive=actor.Alive;
            actor.MaxHp=(int)profile["max_hp"];actor.Hp=alive?RoundStat(actor.MaxHp*ratio):0;
            actor.Attack=(int)profile["attack"];actor.Defense=(int)profile["defense"];actor.Role=(string)profile["role_group"];actor.Slot=(int)profile["slot"];
            actor.Row=(string)profile["row"];actor.Range=(int)profile["range"];actor.Style=(string)profile["ai_style"];
            actor.AttackIntervalMultiplier=(double)profile["attack_interval_mult"];actor.UltimateGainMultiplier=(double)profile["ult_gain_mult"];
            // Preserve position, status, shields, cooldown timing and energy.
        }
    }
}
