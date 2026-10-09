using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        readonly List<(Button card,Image art,Label title,Label state,VisualElement fill)> chainTiles=new(6);
        VisualElement chainStrip;
        Button chainToggle;
        void BuildChainStrip()
        {
            chainStrip=Box(root,"chain-strip",new Color(.035f,.055f,.06f,.94f));
            chainStrip.style.position=Position.Absolute;chainStrip.style.left=24;chainStrip.style.right=24;chainStrip.style.bottom=183;
            chainStrip.style.height=58;chainStrip.style.flexDirection=FlexDirection.Row;chainStrip.style.alignItems=Align.Center;
            chainStrip.style.paddingLeft=10;chainStrip.style.paddingRight=10;
            chainToggle=Button(chainStrip,"연계 ON",()=>{Simulation.Chain.Enabled=!Simulation.Chain.Enabled;SavePlayerChain();});chainToggle.style.width=87;chainToggle.style.minWidth=0;chainToggle.style.marginLeft=0;chainToggle.style.marginRight=6;chainToggle.style.fontSize=12;
            chainToggle.tooltip="자동 연계를 켜거나 끕니다. 준비된 스킬 카드를 누르면 해당 스킬을 직접 시전합니다.";
            for(int i=0;i<6;i++)
            {
                int slotIndex=i;var card=new Button(()=>CastChainTile(slotIndex)){name="manual-chain-"+i,userData="manual-chain-"+i};
                card.style.flexGrow=1;card.style.flexBasis=0;card.style.minWidth=0;card.style.height=48;card.style.marginLeft=4;card.style.marginRight=4;card.style.paddingLeft=7;card.style.paddingRight=5;
                card.style.paddingTop=3;card.style.paddingBottom=2;
                card.style.flexDirection=FlexDirection.Column;card.style.backgroundColor=new Color(.09f,.12f,.13f);card.style.color=Parchment;
                card.style.borderTopWidth=card.style.borderBottomWidth=card.style.borderLeftWidth=card.style.borderRightWidth=1;
                card.style.borderTopColor=card.style.borderBottomColor=card.style.borderLeftColor=card.style.borderRightColor=new Color(.25f,.31f,.31f);
                var row=Row(card);row.style.height=36;row.style.flexShrink=0;
                var art=new Image{scaleMode=ScaleMode.ScaleToFit};art.style.width=29;art.style.height=34;art.style.flexShrink=0;art.style.marginRight=5;row.Add(art);
                var copy=new VisualElement();copy.style.flexGrow=1;copy.style.minWidth=0;row.Add(copy);
                var title=Text(copy,"",12);title.style.height=19;title.style.whiteSpace=WhiteSpace.NoWrap;title.style.overflow=Overflow.Hidden;title.style.textOverflow=TextOverflow.Ellipsis;
                var state=Text(copy,"",10);state.style.height=16;state.style.color=Moss;
                title.name="chain-title";state.name="chain-ready";
                foreach(var line in new[]{title,state}){line.style.flexShrink=0;line.style.marginTop=line.style.marginBottom=line.style.paddingTop=line.style.paddingBottom=0;}
                var track=new VisualElement();track.style.height=2;track.style.backgroundColor=new Color(.18f,.23f,.23f);card.Add(track);
                var fill=new VisualElement();fill.style.height=2;fill.style.backgroundColor=Moss;track.Add(fill);chainStrip.Add(card);chainTiles.Add((card,art,title,state,fill));
            }
            var edit=Button(chainStrip,"순서 편집",ShowChain);edit.style.width=91;edit.style.minWidth=0;edit.style.marginLeft=6;edit.style.fontSize=12;
        }
        void CastChainTile(int index)
        {
            if(Raid!=null||index>=Simulation.Chain.Entries.Count)return;
            var entry=Simulation.Chain.Entries[index];
            bool cast=Simulation.ManualCast(entry.Hero,entry.Slot);
            huntNotice=cast?(string)Simulation.Catalog.Hero(entry.Hero)["name"]+" · "+(string)Simulation.Battle.Kits[entry.Hero].Profiles[entry.Slot]["skill"]:"쿨다운·게이지·대상을 확인해 주세요.";
            huntNoticeUntil=Time.unscaledTime+2;RefreshHud();
        }
        void RefreshChainStrip()
        {
            chainStrip.style.display=Raid==null&&modal.style.display.value==DisplayStyle.None?DisplayStyle.Flex:DisplayStyle.None;
            if(Raid!=null)return;var chain=Simulation.Chain;
            chainToggle.text=chain.Enabled?"연계 ON":"연계 OFF";chainToggle.style.color=chain.Enabled?Moss:Bronze;
            for(int i=0;i<chainTiles.Count;i++)
            {
                var tile=chainTiles[i];if(i>=chain.Entries.Count){tile.card.style.display=DisplayStyle.None;continue;}
                tile.card.style.display=DisplayStyle.Flex;var entry=chain.Entries[i];var actor=Simulation.Battle.Heroes.Find(h=>h.Id==entry.Hero);
                var kit=Simulation.Battle.Kits[entry.Hero];var profile=kit.Profiles[entry.Slot];tile.art.sprite=InspectionPortrait(entry.Hero);tile.title.text=(i+1)+" · "+(string)profile["skill"];
                bool ready=Simulation.CanManualCast(entry.Hero,entry.Slot);double remaining=kit.Cooldowns.GetValueOrDefault(entry.Slot);
                float progress=entry.Slot=="ultimate"?(float)(actor.Ultimate/100):1-(float)(remaining/Math.Max(.01,LegacyCombatRules.Number(profile,"cooldown",7)));
                tile.state.text=!actor.Alive?"전투 불능":actor.Stun>0?"행동 제한":ready?"터치하여 시전":entry.Slot=="ultimate"?"게이지 "+(int)actor.Ultimate+"%":remaining>0?remaining.ToString("F1")+"초":"대상 대기";
                tile.card.SetEnabled(ready);tile.fill.style.width=Length.Percent(Mathf.Clamp01(progress)*100);tile.state.style.color=ready?Moss:Bronze;
                bool next=chain.Enabled&&i==chain.Cursor;tile.card.style.borderTopColor=next?Bronze:new Color(.25f,.31f,.31f);tile.card.style.borderTopWidth=next?2:1;
                tile.card.tooltip=(string)Simulation.Catalog.Hero(entry.Hero)["name"]+" · "+(string)profile["skill"]+"\n"+(string)profile["effect"];
            }
        }
    }
}
