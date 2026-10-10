using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    // Original local escrow ledger. No fabricated players, offers or online endpoint.
    public sealed class LegacyEquipmentMarket
    {
        public readonly JObject State;
        public long Revision=>L.N(State["revision"],0,GameStateCommands.CurrencyCap);
        public string LoadError {get;private set;}="";
        JObject Accounts=>Map(State,"accounts");
        JObject Listings=>Map(State,"listings");
        JObject Receipts=>Map(State,"processed_commands");
        static JObject Map(JObject root,string key){if(root[key] is JObject map)return map;var value=new JObject();root[key]=value;return value;}
        public static bool Identifier(string id)=>!string.IsNullOrEmpty(id)&&id.Length<=120&&!id.Any(c=>c<32);
        static bool Integer(JToken token,long low,long high)=>token!=null&&(token.Type==JTokenType.Integer||token.Type==JTokenType.Float)&&double.IsFinite((double)token)&&(double)token>=low&&(double)token<=high&&(double)token%1==0;
        static string Hash(string text){using var sha=SHA256.Create();return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(text))).Replace("-","").ToLowerInvariant();}
        static string Fingerprint(JObject command)=>Hash(new JObject(command.Properties().OrderBy(p=>p.Name,StringComparer.Ordinal).Select(p=>new JProperty(p.Name,p.Value.DeepClone()))).ToString(Formatting.None));
        public static string TradeError(JObject item)
        {if(item.Count==0)return "올바른 장비가 아닙니다.";if(L.Flag(item["locked"]))return "잠금을 해제하세요.";if(L.Flag(item["bound"])||L.N(item["trade_count"])>=1)return "귀속되었거나 이미 거래한 장비입니다.";if(L.Array(item["affixes"]).Any(a=>L.N(a["trade_count"])>=1)||L.N(item["stored_option"]?["trade_count"])>=1)return "구매한 옵션은 다시 거래할 수 없습니다.";if(L.Object(item["proposal"]).Count>0)return "공방 옵션 후보를 먼저 선택하거나 포기하세요.";if((string)item["set"]=="초보자"&&(string)item["item_type"]!="option_crystal")return "기본 지급 장비는 거래할 수 없습니다.";return "";}
        public LegacyEquipmentMarket(JObject source)
        {
            State=(JObject)source.DeepClone();try{if(L.N(State["market_version"],1)>1){LoadError="최신 거래소 기록은 변경할 수 없습니다.";return;}State["market_version"]=1;var accounts=Accounts;var listings=Listings;var receipts=Receipts;
            if(accounts.Count>64||listings.Count>2048||receipts.Count>8192){LoadError="거래소 저장 한도를 확인하세요.";return;}
            var owned=new HashSet<string>();
            bool Items(JToken list,int cap)
            {if(list is not JArray items||items.Count>cap)return false;foreach(var raw in items){if(raw is not JObject obj||!Identifier((string)obj["id"])||OriginalEquipmentRules.Normalize(obj).Count==0||!owned.Add((string)obj["id"]))return false;}return true;}
            foreach(var account in accounts.Properties())
            {if(!Identifier(account.Name)||account.Value is not JObject a||!Items(a["inventory"],200)||!Items(a["deliveries"],512)||!Integer(a["gold"],0,GameStateCommands.CurrencyCap)||!Integer(a["pending_gold"],0,GameStateCommands.CurrencyCap)){LoadError="계정·장비 기록이 손상되었습니다. 원본은 보존됩니다.";return;}a["last_request_seq"]=L.N(a["last_request_seq"],0,GameStateCommands.CurrencyCap);}
            foreach(var listing in listings.Properties())
            {if(listing.Value is not JObject item||!Identifier(listing.Name)||accounts[(string)item["seller_id"]??""]==null||!Integer(item["price"],10,1000000000)){LoadError="매물 기록이 손상되었습니다. 원본은 보존됩니다.";return;}if((string)item["status"]=="active"&&(!Items(new JArray(item["item"].DeepClone()),1)||!Integer(item["expires_at"],0,4102444800))){LoadError="중복되거나 손상된 판매 장비입니다.";return;}}
            }catch(Exception e)when(e is InvalidCastException||e is FormatException||e is ArgumentException){LoadError="거래소 기록을 읽을 수 없습니다. 원본을 보존했습니다.";}
        }
        JObject Result(bool ok,string reason)=>new(){{"ok",ok},{"reason",reason},{"revision",Revision}};
        void Bump()=>State["revision"]=Revision+1;
        public JObject Account(string id)=>(JObject)L.Object(Accounts[id]).DeepClone();
        public JObject SyncLocal(string id,long gold,JArray inventory)
        {
            if(LoadError.Length>0)return Result(false,LoadError);if(!Identifier(id)||gold<0||gold>GameStateCommands.CurrencyCap||inventory.Count>200)return Result(false,"계정·가방 한도를 확인하세요.");
            var used=new HashSet<string>();foreach(var a in Accounts.Properties())
            {foreach(var u in L.Array(a.Value["deliveries"]))used.Add((string)u["id"]);if(a.Name!=id)foreach(var u in L.Array(a.Value["inventory"]))used.Add((string)u["id"]);}
            foreach(var item in Listings.Properties().Where(p=>(string)p.Value["status"]=="active"))used.Add((string)item.Value["item"]?["id"]);
            var clean=new JArray();foreach(var raw in inventory){if(raw is not JObject obj||!Identifier((string)obj["id"])||!used.Add((string)obj["id"]))return Result(false,"중복 또는 잘못된 장비 ID");var item=OriginalEquipmentRules.Normalize(obj);if(item.Count==0)return Result(false,"잘못된 장비 정보");clean.Add(item);}
            var account=Accounts[id] as JObject;if(account==null){if(Accounts.Count>=64)return Result(false,"계정 한도 초과");account=new JObject{{"name","내 원정대"},{"kind","player"},{"deliveries",new JArray()},{"pending_gold",0},{"last_request_seq",0}};Accounts[id]=account;}account["gold"]=gold;account["inventory"]=clean;return Result(true,"계정 연결");
        }
        public int Expire(long now)
        {if(now<0||now>4102444800)return 0;int count=0;foreach(var item in Listings.Properties().Select(p=>(JObject)p.Value).Where(i=>(string)i["status"]=="active"&&L.N(i["expires_at"],0,long.MaxValue)<=now)){var account=(JObject)Accounts[(string)item["seller_id"]];if(L.Array(account["deliveries"]).Count>=512)continue;((JArray)account["deliveries"]).Add(item["item"].DeepClone());item["status"]="expired";item["closed_at"]=now;count++;}if(count>0)Bump();return count;}
        public JArray Browse(string owner="")=>new(Listings.Properties().Select(p=>(JObject)p.Value).Where(i=>owner.Length==0?(string)i["status"]=="active":(string)i["seller_id"]==owner).OrderByDescending(i=>L.N(i["serial"],0,GameStateCommands.CurrencyCap)).Select(i=>{var row=(JObject)i.DeepClone();row["seller_name"]=Accounts[(string)i["seller_id"]]?["name"]?.DeepClone()??new JValue((string)i["seller_id"]);return row;}));
        public JObject Submit(string actor,JObject command,long now)
        {
            if(LoadError.Length>0)return Result(false,LoadError);string id=(string)command["request_id"]??"";if(!Identifier(actor)||!Identifier(id)||Accounts[actor] is not JObject account)return Result(false,"요청·계정 ID 오류");long sequence=L.N(command["request_seq"],0,GameStateCommands.CurrencyCap);if(sequence<1||id!="seq_"+sequence)return Result(false,"순차 요청 ID 오류");string key=Hash(new JArray(actor,id).ToString(Formatting.None)),fingerprint=Fingerprint(command);
            if(Receipts[key] is JObject previous){if((string)previous["fingerprint"]!=fingerprint)return Result(false,"요청 ID를 다른 거래에 재사용할 수 없습니다.");var duplicate=(JObject)previous["response"].DeepClone();duplicate["duplicate"]=true;return duplicate;}
            if(sequence<=L.N(account["last_request_seq"],0,GameStateCommands.CurrencyCap))return Result(false,"이미 처리된 이전 거래 요청입니다.");
            JObject response;
            if(now<0||now>4102444800-172800)response=Result(false,"잘못된 거래 시간");
            else
            {
                Expire(now);
                if(command["expected_revision"]!=null&&(!Integer(command["expected_revision"],0,GameStateCommands.CurrencyCap)||L.N(command["expected_revision"],0,GameStateCommands.CurrencyCap)!=Revision))response=Result(false,"거래소 정보가 변경되었습니다. 새로고침하세요.");
                else response=Execute(actor,account,command,now);
            }
            account["last_request_seq"]=sequence;var older=Receipts.Properties().Where(p=>(string)p.Value["actor_id"]==actor&&L.N(p.Value["request_seq"])>0).OrderBy(p=>L.N(p.Value["request_seq"],0,GameStateCommands.CurrencyCap)).ToArray();foreach(var p in older.Take(Math.Max(0,older.Length-63)))p.Remove();while(Receipts.Count>=8192){State["legacy_requests_closed"]=true;Receipts.Properties().First().Remove();}
            response["revision"]=Revision;response["request_id"]=id;response["request_seq"]=sequence;Receipts[key]=new JObject{{"actor_id",actor},{"request_id",id},{"request_seq",sequence},{"fingerprint",fingerprint},{"response",response.DeepClone()}};return response;
        }
        JObject Execute(string actor,JObject account,JObject command,long now)
        {
            string action=(string)command["action"]??"",listingId=(string)command["listing_id"]??"",itemId=(string)command["item_id"]??"";var inventory=L.Array(account["inventory"]);var deliveries=L.Array(account["deliveries"]);
            if(action=="list")
            {
                if(!Integer(command["price"],10,1000000000)||!Identifier(itemId))return Result(false,"판매가는 10~1,000,000,000 골드의 정수여야 합니다.");
                if(Browse(actor).OfType<JObject>().Count(i=>(string)i["status"]=="active")>=5||deliveries.Count>=507)return Result(false,"매물 5개 한도 또는 배송 보관함을 확인하세요.");
                var item=inventory.OfType<JObject>().FirstOrDefault(i=>(string)i["id"]==itemId);if(item==null)return Result(false,"가방에 장비가 없습니다.");string error=TradeError(item);if(error.Length>0)return Result(false,error);
                if(Listings.Count>=2048){var old=Listings.Properties().Where(p=>(string)p.Value["status"]!="active").OrderBy(p=>L.N(p.Value["serial"],0,GameStateCommands.CurrencyCap)).FirstOrDefault();old?.Remove();}if(Listings.Count>=2048)return Result(false,"거래소 등록 한도 초과");
                long serial=L.N(State["next_listing_serial"],1,GameStateCommands.CurrencyCap);listingId="local_listing_"+serial;while(Listings.ContainsKey(listingId)&&serial<GameStateCommands.CurrencyCap)listingId="local_listing_"+(++serial);if(serial>=GameStateCommands.CurrencyCap)return Result(false,"매물 번호 한도 초과");
                Listings[listingId]=new JObject{{"id",listingId},{"serial",serial},{"seller_id",actor},{"item",item.DeepClone()},{"price",command["price"]},{"created_at",now},{"expires_at",now+172800},{"status","active"},{"buyer_id",""},{"closed_at",0}};State["next_listing_serial"]=serial+1;item.Remove();Bump();var result=Result(true,"48시간 판매 등록");result["listing_id"]=listingId;return result;
            }
            if(action=="claim")
            {
                if(command["gold_only"]!=null&&command["gold_only"].Type!=JTokenType.Boolean||itemId.Length>0&&!Identifier(itemId))return Result(false,"잘못된 수령 요청");long gold=L.N(account["pending_gold"],0,GameStateCommands.CurrencyCap);if(L.N(account["gold"],0,GameStateCommands.CurrencyCap)>GameStateCommands.CurrencyCap-gold)return Result(false,"골드 한도 초과");int count=0;
                if(!L.Flag(command["gold_only"]))foreach(var item in deliveries.OfType<JObject>().ToArray()){if(inventory.Count>=200)break;if(itemId.Length>0&&(string)item["id"]!=itemId)continue;inventory.Add(item.DeepClone());item.Remove();count++;if(itemId.Length>0)break;}
                if(count==0&&gold==0)return Result(false,deliveries.Count>0?"가방 공간이 부족합니다. 배송 장비는 보관됩니다.":"받을 정산금이나 장비가 없습니다.");account["gold"]=L.N(account["gold"],0,GameStateCommands.CurrencyCap)+gold;account["pending_gold"]=0;Bump();return Result(true,"정산금 "+gold+" 골드 · 장비 "+count+"개 수령");
            }
            if(!Identifier(listingId)||Listings[listingId] is not JObject listing||(string)listing["status"]!="active")return Result(false,"없거나 거래가 종료된 매물입니다.");
            if(action=="cancel")
            {if((string)listing["seller_id"]!=actor)return Result(false,"자신의 매물만 취소할 수 있습니다.");if(deliveries.Count>=512)return Result(false,"배송 보관함 한도 초과");deliveries.Add(listing["item"].DeepClone());listing["status"]="cancelled";listing["closed_at"]=now;Bump();return Result(true,"등록 취소 · 배송 보관함으로 반환");}
            if(action=="buy")
            {
                if((string)listing["seller_id"]==actor)return Result(false,"자신의 매물은 구매할 수 없습니다.");long price=L.N(listing["price"]),fee=Math.Max(1,(price+19)/20),proceeds=price-fee;var seller=(JObject)Accounts[(string)listing["seller_id"]];if(L.N(account["gold"],0,GameStateCommands.CurrencyCap)<price||deliveries.Count>=507)return Result(false,"골드 또는 배송 보관함을 확인하세요.");if(L.N(seller["gold"],0,GameStateCommands.CurrencyCap)+L.N(seller["pending_gold"],0,GameStateCommands.CurrencyCap)>GameStateCommands.CurrencyCap-proceeds)return Result(false,"판매자 골드 한도 초과");
                var item=(JObject)listing["item"].DeepClone();item["bound"]=true;item["trade_count"]=1;if((string)item["item_type"]=="option_crystal")L.Object(item["stored_option"])["trade_count"]=1;else foreach(var option in L.Array(item["affixes"]).OfType<JObject>())option["trade_count"]=1;
                account["gold"]=L.N(account["gold"],0,GameStateCommands.CurrencyCap)-price;deliveries.Add(item);seller["pending_gold"]=L.N(seller["pending_gold"],0,GameStateCommands.CurrencyCap)+proceeds;listing["status"]="sold";listing["buyer_id"]=actor;listing["closed_at"]=now;Bump();var result=Result(true,"구매 완료 · 배송 보관함에서 수령하세요.");result["fee"]=fee;result["proceeds"]=proceeds;return result;
            }
            return Result(false,"지원하지 않는 거래 요청");
        }
    }

    public sealed partial class GameStateCommands
    {
        public JObject MarketView(long now=0)
        {var market=new LegacyEquipmentMarket(L.Object(data["gear_market_state"]));var ready=market.SyncLocal("player_local",WalletGold,new JArray(Inventory()));if(L.Flag(ready["ok"]))market.Expire(now>0?now:L.Now);return new JObject{{"mode","로컬 거래소 · 온라인 서버 미연결"},{"revision",market.Revision},{"listings",market.Browse()},{"own_listings",market.Browse("player_local")},{"account",market.Account("player_local")},{"error",L.Flag(ready["ok"])?"":(string)ready["reason"]}};}
        public StateCommandResult MarketCommand(string action,JObject parameters=null,long now=0)=>Commit(state=>
        {
            var market=new LegacyEquipmentMarket(L.Object(state["gear_market_state"]));var ready=market.SyncLocal("player_local",Integer(state["wallet_gold"],0,0,CurrencyCap),Bag(state));if(!L.Flag(ready["ok"]))return StateCommandResult.Fail((string)ready["reason"]);
            var command=parameters==null?new JObject():(JObject)parameters.DeepClone();long sequence=L.N(market.Account("player_local")["last_request_seq"],0,CurrencyCap-1)+1;command["action"]=action;command["request_seq"]=sequence;command["request_id"]="seq_"+sequence;
            var response=market.Submit("player_local",command,now>0?now:L.Now);var account=market.Account("player_local");state["gear_market_state"]=market.State;state["wallet_gold"]=account["gold"].DeepClone();state["loot_inventory"]=account["inventory"].DeepClone();
            // Persist rejected request receipts/expirations too; repeated input cannot replay escrow.
            var result=StateCommandResult.Success((string)response["reason"]);result.Details=response;return result;
        });
    }
}
