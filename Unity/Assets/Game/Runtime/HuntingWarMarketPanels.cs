using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        int warMapX=-1,warMapY=-1,warSelectedX=-1,warSelectedY=-1;
        float warRefreshAt;
        void TickLegacyWorld()
        {if(Time.unscaledTime<warRefreshAt||!GrowthAllowed||!L.Flag(ReviewState.WorldConnectionStatus()["connected"])||!ReviewState.WarTickDue(L.Now))return;warRefreshAt=Time.unscaledTime+1;var result=ReviewState.AdvanceWar();PauseForSaveFailure();if(modal?.Q("native-war-map")!=null){growthMessage=result.Message;ShowFactionWar();}}
        void ShowFactionWar()
        {
            PanelHeader("진영전");ConfigureInspection(InspectionLayout.Wide);GrowthNotice(modal);if(!ReviewState.WarInitialized){Text(modal,"기존 영토·부대 기록으로 진영전에 참여합니다. 첫 출전은 40×40 세계에서 시작합니다.",14).style.whiteSpace=WhiteSpace.Normal;GrowthButton(modal,"진영전 시작",ReviewState.InitializeWar,ShowFactionWar);return;}
            var connection=ReviewState.WorldConnectionStatus();var view=ReviewState.WarView();var world=(JObject)view["world"];var army=LegacyWorldWar.Cell(world["army_position"]);var season=(JObject)view["season"];
            Text(modal,(ReviewState.Faction=="aurelia"?"아우렐리아":"녹스페라")+" · 군량 "+world["rations"]+" · 피로 "+world["army_fatigue"]+" · 명예 "+world["campaign_honor"]+" · "+season["season_id"]+" "+season["phase"],14).style.whiteSpace=WhiteSpace.Normal;
            Text(modal,"로컬 진영전 · 부대 위치 "+army.x+", "+army.y+" · 파란 영토 아군 / 붉은 영토 적군 / 회색 중립",12).style.whiteSpace=WhiteSpace.Normal;
            var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            LegacySection(scroll,(string)connection["mode"]=="remote_server"?"원격 연결 준비 필요":"로컬 진영전",L.Flag(connection["connected"])?"권한 연결 정상":(string)connection["error"]);
            GrowthButton(scroll,L.Flag(connection["connected"])?"연결 중지 테스트":"다시 연결",()=>ReviewState.SetWorldConnection(!L.Flag(connection["connected"])),ShowFactionWar);
            var tools=Row(scroll);foreach(var stance in new[]{("balanced","균형"),("assault","강습"),("guard","신중")}){string id=stance.Item1;GrowthButton(tools,stance.Item2,()=>ReviewState.WarCommand("set_stance",context:id),ShowFactionWar,!L.Flag(view["march"]?["active"]));}
            if(warMapX<0){warMapX=Math.Clamp(army.x-4,0,31);warMapY=Math.Clamp(army.y-4,0,31);}
            var pan=Row(scroll);foreach(var p in new[]{(-4,0,"←"),(4,0,"→"),(0,-4,"↑"),(0,4,"↓")}){var step=p;Button(pan,step.Item3,()=>{warMapX=Math.Clamp(warMapX+step.Item1,0,31);warMapY=Math.Clamp(warMapY+step.Item2,0,31);ShowFactionWar();});}Button(pan,"내 부대로",()=>{warMapX=Math.Clamp(army.x-4,0,31);warMapY=Math.Clamp(army.y-4,0,31);ShowFactionWar();});
            var map=new VisualElement{name="native-war-map"};scroll.Add(map);
            for(int y=warMapY;y<warMapY+9;y++)
            {var row=Row(map);for(int x=warMapX;x<warMapX+9;x++){int tx=x,ty=y;var tile=world["cells"][x+":"+y];string kind=(string)tile["type"],owner=(string)tile["owner"];var button=Button(row,(army.x==x&&army.y==y?"⚑ ":"")+x+","+y+"\n"+(kind=="plain"?"평원":kind=="forest"?"숲":kind=="hills"?"언덕":kind=="mine"?"광산":kind=="forest_resource"?"벌목":kind=="ruins"?"유적":kind=="fort"?"요새":kind=="citadel"?"대성":"수도"),()=>{warSelectedX=tx;warSelectedY=ty;ShowFactionWar();});button.style.width=Length.Percent(11.11f);button.style.height=52;button.style.marginLeft=button.style.marginRight=1;button.style.fontSize=11;button.style.whiteSpace=WhiteSpace.Normal;button.style.backgroundColor=owner==ReviewState.Faction?new Color(.13f,.29f,.36f):owner=="neutral"?new Color(.16f,.18f,.19f):new Color(.38f,.17f,.19f);}}
            if(L.Flag(view["march"]?["active"]))
            {
                var march=view["march"];double remaining=Math.Max(0,L.F(march["authority_started_unix"])+L.F(march["duration_seconds"])-L.Now);LegacySection(scroll,"행군 중",march["action"]+" · "+remaining.ToString("F0")+"초 · 도착지는 군량·보급·소유권 재검사");GrowthButton(scroll,"행군 취소 · 50% 환급",()=>ReviewState.WarCommand("cancel_march"),ShowFactionWar);
            }
            else if(warSelectedX>=0)
            {
                var quote=ReviewState.WarQuote(warSelectedX,warSelectedY);LegacySection(scroll,"선택 영토 "+warSelectedX+", "+warSelectedY,quote["kind"]+" · "+quote["owner"]+" · 수비 Lv."+quote["guard_level"]+" · 거리 "+quote["distance"]+" · 군량 "+quote["ration_cost"]+" · "+L.F(quote["duration_seconds"]).ToString("F1")+"초");
                string error=(string)quote["error"]??"";if(error.Length>0)Text(scroll,error,13).style.color=Bronze;
                int queued=L.Array(view["conflict"]?["attack_queues"]?[warSelectedX+":"+warSelectedY]).Count;
                if(queued>0)GrowthButton(scroll,"대기 공격대 "+queued+"부대 처리",()=>ReviewState.WarCommand("process_attack_queue",warSelectedX,warSelectedY),ShowFactionWar);
                long revision=(long)view["revision"];GrowthButton(scroll,"행군 · 이동 / 점령 / 공략",()=>ReviewState.WarCommand("march",warSelectedX,warSelectedY,expectedRevision:revision),ShowFactionWar,error.Length==0);
                GrowthButton(scroll,"지원 행군",()=>ReviewState.WarCommand("support",warSelectedX,warSelectedY,expectedRevision:revision),ShowFactionWar,(string)quote["owner"]==ReviewState.Faction);
                GrowthButton(scroll,"집결 공격 준비",()=>ReviewState.WarCommand("prepare_rally",warSelectedX,warSelectedY,expectedRevision:revision),ShowFactionWar,(string)quote["owner"]!="neutral"&&(string)quote["owner"]!=ReviewState.Faction);
            }
            foreach(var rally in L.Object(view["conflict"]?["rallies"]).Properties().Take(5))
            {string id=rally.Name;var target=LegacyWorldWar.Cell(rally.Value["target"]);GrowthButton(scroll,"집결 행군 · "+target.x+","+target.y+" · "+L.Array(rally.Value["participants"]).Count+"부대",()=>ReviewState.WarCommand("rally_march",target.x,target.y,id),ShowFactionWar,!L.Flag(view["march"]?["active"]));}
            var actions=Row(scroll);GrowthButton(actions,"현재 위치 주둔",()=>ReviewState.WarCommand("register_garrison",army.x,army.y),ShowFactionWar);GrowthButton(actions,"요새 부상·피로 정비",()=>ReviewState.WarCommand("rest_army"),ShowFactionWar);GrowthButton(actions,"수도로 후퇴",()=>ReviewState.WarCommand("forced_retreat"),ShowFactionWar);
            GrowthButton(scroll,"명예 50 → 군량 200",()=>ReviewState.WarCommand("exchange_honor"),ShowFactionWar);GrowthButton(scroll,"시즌 보상 수령",()=>ReviewState.WarCommand("claim_season_reward"),ShowFactionWar,L.Flag(view["reward"]?["claimable"]));GrowthButton(scroll,"다음 시즌 시작",()=>ReviewState.WarCommand("next_season"),ShowFactionWar,(string)season["phase"]=="ended");
            foreach(var report in L.Array(world["battle_reports"]).OfType<JObject>().Take(5))
            {var p=LegacyWorldWar.Cell(report["target"]);LegacySection(scroll,(L.Flag(report["captured"])?"점령 성공":"공략 실패")+" · "+p.x+","+p.y,"수비대 격파 "+report["defeated_forces"]+" · 피로 "+report["fatigue_after"]);foreach(var battle in L.Array(report["battle_summaries"]).OfType<JObject>().Take(2))foreach(var line in L.Array(battle["logs"]).Take(4))Text(scroll,(string)line,11).style.whiteSpace=WhiteSpace.Normal;}
        }
        void ShowMarket()
        {
            PanelHeader("거래소");var view=ReviewState.MarketView();var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);LegacySection(scroll,(string)view["mode"],"판매 등록 5개 · 48시간 · 수수료 5% · 구매한 장비/옵션은 재판매 불가");GrowthNotice(scroll);
            if(((string)view["error"]??"").Length>0){Text(scroll,(string)view["error"],14).style.whiteSpace=WhiteSpace.Normal;return;}
            GrowthButton(scroll,"정산금·배송 장비 수령",()=>ReviewState.MarketCommand("claim"),ShowMarket);Button(scroll,"판매할 장비 선택",ShowMarketSell);
            foreach(var item in L.Array(view["listings"]).OfType<JObject>().Take(40))
            {string id=(string)item["id"];long revision=(long)view["revision"];LegacySection(scroll,(string)item["item"]?["name"],item["price"]+" 골드 · "+item["seller_name"]);GrowthButton(scroll,(string)item["seller_id"]=="player_local"?"판매 취소":"구매",()=>ReviewState.MarketCommand((string)item["seller_id"]=="player_local"?"cancel":"buy",new JObject{{"listing_id",id},{"expected_revision",revision}}),ShowMarket);}
            if(L.Array(view["listings"]).Count==0)Text(scroll,"등록된 매물이 없습니다. 가방의 거래 가능한 장비를 판매 등록할 수 있습니다.",14).style.whiteSpace=WhiteSpace.Normal;
            LegacySection(scroll,"배송 보관함",L.Array(view["account"]?["deliveries"]).Count+"개 · 정산금 "+view["account"]?["pending_gold"]+" 골드");
        }
        void ShowMarketSell()
        {
            PanelHeader("판매할 장비");GrowthNotice(modal);var price=new TextField("판매가 (골드)"){value="100"};modal.Add(price);var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            foreach(var item in ReviewState.Inventory().Where(i=>i.Count>0))
            {string id=(string)item["id"],error=LegacyEquipmentMarket.TradeError(item);GrowthButton(list,item["name"]+" · "+(error.Length==0?"판매 가능":error),()=>long.TryParse(price.value,out long amount)?ReviewState.MarketCommand("list",new JObject{{"item_id",id},{"price",amount}}):StateCommandResult.Fail("판매가를 정수로 입력하세요."),ShowMarket,error.Length==0);}
            Button(modal,"거래소로",ShowMarket);
        }
    }
}
