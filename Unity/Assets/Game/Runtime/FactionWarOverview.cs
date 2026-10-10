using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    // Read the original campaign fields from the intact imported snapshot.
    // Combat, marching and server settlement are separate native port work.
    internal static class FactionWarOverview
    {
        internal static void Populate(VisualElement parent,JObject snapshot)
        {
            Label Copy(string text,int size=14)
            {
                var label=new Label(text);label.style.fontSize=size;label.style.whiteSpace=WhiteSpace.Normal;
                label.style.marginBottom=12;parent.Add(label);return label;
            }
            string StringValue(JToken token)=>token?.Type==JTokenType.String?(string)token:"";
            string faction=StringValue(snapshot?["selected_faction"]);
            string Name(string id)=>id=="aurelia"?"아우렐리아":id=="noxfera"?"녹스페라":"미선택";
            Copy("진영 · "+Name(faction),20).style.color=new Color(.94f,.80f,.56f);
            Copy("전투·행군·점령 기능을 준비하고 있습니다.");
            var war=snapshot?["faction_war"] as JObject;
            var cells=war?["cells"] as JObject;
            if(cells==null||cells.Count==0)
            {
                Copy("저장된 진영전 기록이 없습니다.");
                Copy("시작 화면에서 기존 기록을 가져오면 보유 영토·군량·명예를 확인할 수 있습니다.",13);
                return;
            }
            string owner=StringValue(war["faction"]);if(owner.Length==0)owner=faction;
            int owned=cells.Properties().Count(p=>p.Value is JObject tile&&StringValue(tile["owner"])==owner);
            long Read(string key)=>GameStateCommands.Integer(war[key],0,0,1000000000);
            Copy("보유 영토 "+owned.ToString("N0")+" / "+cells.Count.ToString("N0"));
            Copy("군량 "+Read("rations").ToString("N0")+" · 전공 명예 "+Read("campaign_honor").ToString("N0"));
            Copy("부대 피로 "+Read("army_fatigue")+" / 100 · 누적 점령 "+Read("captured_count").ToString("N0"));
            var reports=war["battle_reports"] as JArray;
            Copy("보존된 전투 기록 "+(reports?.Count??0)+"건");
            if(owner!=faction)Copy("이 전쟁 기록의 진영은 "+Name(owner)+"입니다. 현재 진영의 기록과 구분해 표시합니다.",13);
        }
    }
}
