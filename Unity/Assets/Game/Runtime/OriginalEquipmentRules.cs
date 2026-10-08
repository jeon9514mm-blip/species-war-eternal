using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public static class OriginalEquipmentRules
    {
        public static readonly string[] Slots={"weapon","armor","accessory"},Rarities={"일반","희귀","전설"};
        static readonly string[] Sets={"초보자","개척자","강철","월광","새벽의 맹약","철벽의 맹세","월식의 추격"};
        static readonly Dictionary<string,(int low,int high,int cap,string name)> Stats=new(StringComparer.Ordinal)
        {["attack_pct"]=(2,6,24,"공격력"),["hp_pct"]=(3,8,30,"체력"),["defense"]=(1,4,18,"방어력"),["haste_pct"]=(1,3,12,"공격 속도"),["ultimate_pct"]=(2,5,18,"궁극기 충전")};
        static readonly Dictionary<string,string[]> Families=new(StringComparer.Ordinal)
        {["assault"]=new[]{"attack_pct","ultimate_pct"},["guard"]=new[]{"hp_pct","defense"},["flow"]=new[]{"haste_pct","ultimate_pct"}};
        static string Text(JToken token,string fallback,int limit=96)
        {
            if(token?.Type!=JTokenType.String)return fallback;
            string s=token.Value<string>().Trim();var result=new StringBuilder();int count=0;
            for(int i=0;i<s.Length&&count<limit;i++,count++){result.Append(s[i]);if(char.IsHighSurrogate(s[i])&&i+1<s.Length&&char.IsLowSurrogate(s[i+1]))result.Append(s[++i]);}return result.ToString();
        }
        static int Int(JToken token,int fallback,int low,int high)=>(int)GameStateCommands.Integer(token,fallback,low,high);
        static bool Bool(JToken token)=>token?.Type==JTokenType.Boolean&&token.Value<bool>();
        public static int RarityRank(string rarity)=>rarity=="전설"?3:rarity=="희귀"?2:1;
        public static double RarityMultiplier(string rarity)=>rarity=="전설"?2.2:rarity=="희귀"?1.45:1;
        public static int SlotBase(string slot)=>slot=="weapon"?22:slot=="armor"?16:slot=="accessory"?12:0;
        public static int OptionCapacity(JObject item)=>(string)item?["item_type"]=="option_crystal"?0:RarityRank((string)item?["rarity"]);
        public static JObject Affix(JToken raw)
        {
            if(raw is not JObject obj)return new JObject();string stat=Text(obj["stat"],"");
            if(!Stats.TryGetValue(stat,out var range)||obj["value"]?.Type!=JTokenType.Integer&&obj["value"]?.Type!=JTokenType.Float)return new JObject();
            double number=obj["value"].Value<double>();if(!double.IsFinite(number)||number<=0)return new JObject();
            var result=new JObject{{"stat",stat},{"value",Int(obj["value"],range.low,range.low,range.high)}};
            if(Int(obj["trade_count"],0,0,1)==1)result["trade_count"]=1;return result;
        }
        public static JObject Normalize(JObject raw)
        {
            if(raw==null)return new JObject();
            string type=Text(raw["item_type"]??new JValue("equipment"),"");
            if(type!="equipment"&&type!="option_crystal")return new JObject();
            string slot=Text(raw["slot"]??new JValue("weapon"),"");if(!Slots.Contains(slot))return new JObject();
            string rarity=Text(raw["rarity"],"일반");if(!Rarities.Contains(rarity))rarity="일반";
            string set=Text(raw["set"],"초보자");if(!Sets.Contains(set))set="초보자";
            string origin=Text(raw["origin"],"legacy");if(origin!="legacy"&&origin!="hunt"&&origin!="raid")origin="legacy";
            string role=Text(raw["hunt_role"],"",16);if(origin!="hunt"||role!="dealer"&&role!="defender"&&role!="support")role="";
            string id=Text(raw["id"],"",160);if(id.Length==0)id="gear_"+Guid.NewGuid().ToString("N");
            int level=Int(raw["level"],1,1,10);
            var item=new JObject{{"id",id},{"item_type",type},{"slot",slot},{"level",level},{"rarity",rarity},{"name",Text(raw["name"],"미확인 장비")},{"set",set},{"zone",Text(raw["zone"],"알 수 없는 지역")},{"origin",origin},{"source_id",Text(raw["source_id"],"",64)},{"hunt_role",role},{"bound",Bool(raw["bound"])},{"locked",Bool(raw["locked"])},{"trade_count",Int(raw["trade_count"],0,0,1)},{"affixes",new JArray()},{"focus",Int(raw["focus"],0,0,3)},{"proposal",new JObject()},{"power",(int)(level*SlotBase(slot)*RarityMultiplier(rarity))}};
            if(type=="option_crystal")
            {
                var stored=Affix(raw["stored_option"]);if(stored.Count==0)return new JObject();
                var range=Stats[(string)stored["stat"]];
                item["slot"]="accessory";item["level"]=1;item["power"]=0;item["set"]="초보자";item["rarity"]=(int)stored["value"]==range.high?"전설":"희귀";
                item["name"]=range.name+" 옵션 결정";item["stored_option"]=stored;item["focus"]=0;
                if((int)item["trade_count"]==1||(int?)stored["trade_count"]==1){item["trade_count"]=1;item["bound"]=true;}return item;
            }
            var used=new HashSet<string>(StringComparer.Ordinal);var affixes=(JArray)item["affixes"];
            if(raw["affixes"] is JArray entries)foreach(var entry in entries)
            {var affix=Affix(entry);if(affix.Count==0||!used.Add((string)affix["stat"]))continue;affixes.Add(affix);if(affixes.Count>=OptionCapacity(item))break;}
            if(raw["proposal"] is JObject proposal&&affixes.Count<OptionCapacity(item))
            {
                string family=Text(proposal["family"],"");var options=new JArray();
                if(Families.TryGetValue(family,out var allowed)&&proposal["options"] is JArray choices)
                foreach(var entry in choices)
                {var option=Affix(entry);string stat=(string)option["stat"];if(option.Count==0||used.Contains(stat)||!allowed.Contains(stat))continue;used.Add(stat);options.Add(option);if(options.Count==2)break;}
                if(options.Count>0)item["proposal"]=new JObject{{"family",family},{"options",options},{"cost",12+8*affixes.Count}};
            }
            return item;
        }
        public static JObject SetProfile(JObject sets)
        {
            var counts=new Dictionary<string,int>(StringComparer.Ordinal);
            foreach(string slot in Slots){string set=Text(sets?[slot],"초보자");counts[set]=counts.GetValueOrDefault(set)+1;}
            double attack=1,hp=1;int defense=0,haste=0,ultimate=0;var labels=new List<string>();
            bool Count(string set,int number)=>counts.GetValueOrDefault(set)>=number;
            if(Count("개척자",2)){attack+=.05;labels.Add("개척자 2세트 ATK+5%");}
            if(Count("개척자",3)){hp+=.08;labels.Add("개척자 3세트 HP+8%");}
            if(Count("강철",2)){hp+=.08;labels.Add("강철 2세트 HP+8%");}
            if(Count("강철",3)){defense+=5;labels.Add("강철 3세트 DEF+5");}
            if(Count("월광",2)){attack+=.08;labels.Add("월광 2세트 ATK+8%");}
            if(Count("월광",3)){attack+=.04;hp+=.06;labels.Add("월광 3세트 ATK+4%/HP+6%");}
            if(Count("새벽의 맹약",2)){hp+=.10;labels.Add("새벽의 맹약 2세트 HP+10%");}
            if(Count("새벽의 맹약",3)){ultimate+=8;labels.Add("새벽의 맹약 3세트 궁극기 충전+8%");}
            if(Count("철벽의 맹세",2)){hp+=.12;labels.Add("철벽의 맹세 2세트 HP+12%");}
            if(Count("철벽의 맹세",3)){defense+=8;labels.Add("철벽의 맹세 3세트 DEF+8");}
            if(Count("월식의 추격",2)){attack+=.10;labels.Add("월식의 추격 2세트 ATK+10%");}
            if(Count("월식의 추격",3)){haste+=6;labels.Add("월식의 추격 3세트 공격 속도+6%");}
            return new JObject{{"attack_mult",attack},{"hp_mult",hp},{"defense_bonus",defense},{"haste_pct",haste},{"ultimate_pct",ultimate},{"summary",labels.Count==0?"세트 효과 없음":string.Join(" · ",labels)}};
        }
        public static JObject AffixProfile(IEnumerable<JObject> items)
        {
            var result=new JObject();foreach(string stat in Stats.Keys)result[stat]=0;
            foreach(var raw in items)
            {var item=Normalize(raw);if(item.Count==0||(string)item["item_type"]=="option_crystal")continue;
             foreach(JObject affix in item["affixes"]){string stat=(string)affix["stat"];result[stat]=Math.Min(Stats[stat].cap,(int)result[stat]+(int)affix["value"]);}}
            return result;
        }
        public static bool Protected(JObject raw)
        {
            var item=Normalize(raw);return item.Count==0||(string)item["item_type"]=="option_crystal"||(bool)item["locked"]||(string)item["origin"]=="raid"||((JArray)item["affixes"]).Count>0||((JObject)item["proposal"]).Count>0;
        }
        public static int SalvageValue(JObject raw){var item=Normalize(raw);return item.Count==0?0:25+(int)item["level"]*20+RarityRank((string)item["rarity"])*35;}
    }
}
