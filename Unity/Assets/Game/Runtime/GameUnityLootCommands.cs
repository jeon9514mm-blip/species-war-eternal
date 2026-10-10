using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        public const int UnityBagCapacity=200,UnityMailCapacity=3000;
        public bool HasDeferredUnityLoot=>(data["unity_pending_loot"] as JArray)?.Count>0;
        public IReadOnlyList<JObject> UnityEquipmentMail()=>
            (data["equipment_overflow"] as JArray??new JArray()).OfType<JObject>().Select(OriginalEquipmentRules.Normalize).Where(i=>i.Count>0).ToArray();
        public static string UnityDropRarity(int difficulty,double roll,double guardianDrop)
        {
            difficulty=Math.Clamp(difficulty,1,3);
            return roll<.03+difficulty*.01?"전설":roll<.15+difficulty*.02?"희귀":roll<Math.Min(.97,(.70+difficulty*.04)*(1+guardianDrop))?"일반":"";
        }
        static JArray LootArray(JObject state,string key)
        {if(state[key] is JArray found)return found;var result=new JArray();state[key]=result;return result;}
        // SHA-256 draws are keyed by an atomically saved profile salt and the
        // clear nonce. Resuming or retrying storage cannot reroll the receipt.
        static double LootDraw(string salt,string nonce,int draw)
        {
            using var sha=SHA256.Create();var b=sha.ComputeHash(Encoding.UTF8.GetBytes(salt+"|"+nonce+"|"+draw));
            uint n=(uint)b[0]<<24|(uint)b[1]<<16|(uint)b[2]<<8|b[3];return n/4294967296d;
        }
        JArray AwardUnityHuntLoot(JObject state,string zone,int pack,int defeats)
        {
            string salt=(string)state["unity_loot_salt"];if(string.IsNullOrEmpty(salt)){salt=Guid.NewGuid().ToString("N");state["unity_loot_salt"]=salt;}
            var region=HuntingSimulation.Canonical["zones"][zone];int difficulty=(int)region["difficulty"];
            string prefix=zone=="gray_meadow"?"초원":zone=="forgotten_mine"?"광맥":"달잠",set=zone=="gray_meadow"?"개척자":zone=="forgotten_mine"?"강철":"월광";
            string[] roles={"dealer","defender","support"},roleNames={"딜러","방어","보조"},stats={"attack_pct","hp_pct","ultimate_pct"};
            string[][] names={new[]{"사냥검","별의 활","성검"},new[]{"가죽갑옷","비늘갑옷","수호갑"},new[]{"부적","반지","심장석"}};
            var awarded=new JArray();
            for(int kill=0;kill<defeats;kill++)
            {
                string nonce=Faction+"/"+pack+"/"+kill;double Draw(int d)=>LootDraw(salt,nonce,d);
                string rarity=UnityDropRarity(difficulty,Draw(0),GuardianBonus("item_drop"));if(rarity.Length==0)continue;
                int slot=(int)(Draw(1)*NativeEquipmentLayout.ItemSlots.Length),role=(int)(Draw(2)*3),rank=OriginalEquipmentRules.RarityRank(rarity)-1;var affixes=new JArray();
                if(rank>0){int low=role==1?3:2,high=role==0?6:role==1?8:5;if(rank==2)low=Math.Max(low,high-2);affixes.Add(new JObject{{"stat",stats[role]},{"value",low+(int)(Draw(3)*(high-low+1))}});}
                string slotId=NativeEquipmentLayout.ItemSlots[slot],label=slotId=="weapon"?names[0][rank]:slotId=="armor"?names[1][rank]:slotId=="accessory"?names[2][rank]:NativeEquipmentLayout.Label(slotId);
                var item=OriginalEquipmentRules.Normalize(new JObject{{"id","unity_hunt_"+salt+"_"+pack+"_"+kill},{"slot",slotId},{"rarity",rarity},{"level",1},{"name",prefix+" "+roleNames[role]+" "+label},{"set",set},{"zone",(string)region["name"]},{"origin","hunt"},{"source_id",zone},{"hunt_role",roles[role]},{"affixes",affixes}});
                StoreUnityLoot(state,item);awarded.Add(item.DeepClone());
            }
            state["unity_last_loot"]=new JObject{{"pack",pack},{"zone",zone},{"items",awarded.DeepClone()}};return awarded;
        }
        void StoreUnityLoot(JObject state,JObject item)
        {
            bool automatic=state["gear_auto_equip"]?.Type==JTokenType.Boolean&&(bool)state["gear_auto_equip"];
            string target=automatic?BestEquipmentTarget(state,item,EquipmentParty(state)):"";
            if(target.Length>0)
            {
                var inventory=Bag(state);int index=inventory.Count;inventory.Add(item);
                if(EquipDraft(state,(string)item["id"],target).Ok){if(index<inventory.Count){var displaced=(JObject)inventory[index].DeepClone();inventory.RemoveAt(index);StoreUnityLootUnassigned(state,displaced);}return;}
                inventory.RemoveAt(index);
            }
            StoreUnityLootUnassigned(state,item);
        }
        static void StoreUnityLootUnassigned(JObject state,JObject item)
        {
            string threshold=(string)state["auto_salvage_min_rarity"]??"일반";
            if(!OriginalEquipmentRules.Protected(item)&&OriginalEquipmentRules.RarityRank((string)item["rarity"])<OriginalEquipmentRules.RarityRank(threshold)){AddCurrency(state,"wallet_gold",OriginalEquipmentRules.SalvageValue(item));return;}
            var bag=Bag(state);if(bag.Count<UnityBagCapacity){bag.Add(item);return;}
            var mail=LootArray(state,"equipment_overflow");
            if(mail.Count<UnityMailCapacity)
            {
                mail.Add(item);Map(state,"equipment_mail_headers")[(string)item["id"]]=new JObject{{"sender","원정대 보급소"},{"title","사냥 장비 배송"},{"sent_at",DateTimeOffset.UtcNow.ToUnixTimeSeconds()},{"attachment_id",(string)item["id"]}};return;
            }
            // A full bag/mail retains the awarded items and holds the next wave.
            // Never discard or silently salvage protected equipment.
            LootArray(state,"unity_pending_loot").Add(item);
        }
        public StateCommandResult ClaimUnityEquipmentMail()=>Commit(state=>
        {
            if(!UnityPlayer)return StateCommandResult.Fail("Unity 원정대 기록을 확인하세요.");
            var bag=Bag(state);var mail=LootArray(state,"equipment_overflow");int received=0;
            while(bag.Count<UnityBagCapacity&&mail.Count>0)
            {
                if(mail[0] is not JObject raw)return StateCommandResult.Fail("보관 장비를 확인하세요.");
                var item=OriginalEquipmentRules.Normalize(raw);if(item.Count==0)return StateCommandResult.Fail("보관 장비를 확인하세요.");
                bag.Add(item);Map(state,"equipment_mail_headers").Remove((string)item["id"]);mail.RemoveAt(0);received++;
            }
            var pending=LootArray(state,"unity_pending_loot");var waiting=pending.OfType<JObject>().Select(i=>(JObject)i.DeepClone()).ToArray();pending.Clear();
            foreach(var item in waiting)StoreUnityLoot(state,item);
            DeliverPendingOriginalLoot(state);
            if(received==0&&waiting.Length==0&&LootArray(state,"equipment_overflow").Count==0&&LacksPendingOriginal(state))return StateCommandResult.Fail("가방의 빈칸을 확보한 뒤 수령하세요.");
            return StateCommandResult.Success("보관 장비 "+received+"개 수령"+(pending.Count>0?" · 장비 보관 대기":""));
        });
        public StateCommandResult SaveUnityPartyPreset(int index,string[] heroes,string formation)=>Commit(state=>
        {
            if(!UnityPlayer||index<0||index>2||heroes==null||heroes.Length<1||heroes.Length>10||heroes.Distinct().Count()!=heroes.Length||heroes.Any(id=>!ValidHero(state,id))||formation==null||FormationProfiles[formation]==null)return StateCommandResult.Fail("편성과 진형을 확인하세요.");
            Map(state,"unity_party_presets")[index.ToString()]=new JObject{{"heroes",new JArray(heroes)},{"formation",formation}};
            var bank=LootArray(state,"party_presets");while(bank.Count<3)bank.Add(new JArray());bank[index]=new JArray(heroes);Map(state,"faction_party_presets")[Faction]=bank.DeepClone();return StateCommandResult.Success("편성 "+(index+1)+"을 저장했습니다.");
        });
        static bool LacksPendingOriginal(JObject state)=>(state["pending_equipment_rolls"] as JObject??new JObject()).Properties().All(p=>Integer(p.Value,0,0,CurrencyCap)==0);
    }
}
