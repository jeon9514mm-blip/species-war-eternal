using System;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        VisualElement responseCue,responseFill,skillFeed;
        Label responseTitle,responseAction,responseTimer;
        readonly (Label owner,Label skill,VisualElement row)[] feedRows=new (Label,Label,VisualElement)[2];
        readonly (string hero,string skill,string kind,float until)[] feedNotices=new (string,string,string,float)[2];
        public string VisibleRaidResponseKind {get;private set;}="";
        void BuildCombatReadability()
        {
            responseCue=Box(root,"raid-response",new Color(.025f,.045f,.055f,.94f));responseCue.style.position=Position.Absolute;responseCue.style.left=Length.Percent(50);responseCue.style.marginLeft=-195;
            responseCue.style.top=105;responseCue.style.width=390;responseCue.style.paddingLeft=responseCue.style.paddingRight=13;responseCue.style.paddingTop=9;responseCue.style.paddingBottom=10;
            responseCue.style.borderTopWidth=2;responseCue.style.display=DisplayStyle.None;responseCue.pickingMode=PickingMode.Ignore;
            var heading=Row(responseCue);responseTitle=Text(heading,"",18);responseTitle.style.flexGrow=1;responseTitle.style.minWidth=0;responseTitle.style.whiteSpace=WhiteSpace.NoWrap;responseTitle.style.textOverflow=TextOverflow.Ellipsis;responseTitle.style.overflow=Overflow.Hidden;
            responseTimer=Text(heading,"",16);responseTimer.style.minWidth=65;responseTimer.style.unityTextAlign=TextAnchor.MiddleRight;
            responseAction=Text(responseCue,"",12);responseAction.style.whiteSpace=WhiteSpace.Normal;responseAction.style.marginTop=4;
            var track=new VisualElement();track.style.height=3;track.style.marginTop=7;track.style.backgroundColor=new Color(.16f,.20f,.23f);responseCue.Add(track);responseFill=new VisualElement();responseFill.style.height=3;track.Add(responseFill);
            foreach(var element in responseCue.Query<VisualElement>().ToList())element.pickingMode=PickingMode.Ignore;
            skillFeed=new VisualElement{name="confirmed-skill-feed",pickingMode=PickingMode.Ignore};skillFeed.style.position=Position.Absolute;skillFeed.style.left=24;skillFeed.style.top=205;skillFeed.style.width=260;root.Add(skillFeed);
            for(int i=0;i<2;i++)
            {
                var row=Box(skillFeed,"confirmed-skill-"+i,new Color(.035f,.055f,.06f,.80f));row.style.marginBottom=5;row.style.paddingLeft=9;row.style.paddingRight=9;row.style.paddingTop=5;row.style.paddingBottom=6;row.style.borderLeftWidth=2;row.style.borderLeftColor=Bronze;row.style.display=DisplayStyle.None;row.pickingMode=PickingMode.Ignore;
                var owner=Text(row,"",10);owner.style.color=Moss;var skill=Text(row,"",13);skill.style.color=Parchment;skill.style.whiteSpace=WhiteSpace.NoWrap;skill.style.overflow=Overflow.Hidden;skill.style.textOverflow=TextOverflow.Ellipsis;owner.pickingMode=skill.pickingMode=PickingMode.Ignore;feedRows[i]=(owner,skill,row);
            }
        }
        void ObserveSkillFeed(BattleEvent e,string skill,string kind)
        {
            int selected=feedNotices[0].hero==e.Source?0:feedNotices[1].hero==e.Source?1:feedNotices[0].until<=feedNotices[1].until?0:1;
            feedNotices[selected]=(e.Source,skill,kind,Time.unscaledTime+1.35f);
        }
        void RefreshCombatReadability()
        {
            var response=RaidResponseView.Read(Raid);bool modalOpen=modal.style.display.value!=DisplayStyle.None;
            VisibleRaidResponseKind=response.Visible&&!modalOpen?response.Kind:"";responseCue.style.display=VisibleRaidResponseKind.Length>0?DisplayStyle.Flex:DisplayStyle.None;
            if(response.Visible)
            {
                responseTitle.text=response.Title;responseAction.text=response.Action;responseTimer.text=response.Timed?response.Remaining.ToString("F1")+"초":"";
                responseCue.style.borderTopColor=responseTitle.style.color=responseTimer.style.color=response.Accent;responseFill.style.backgroundColor=response.Accent;
                responseFill.style.width=Length.Percent(response.Progress*100);
            }
            bool hide=modalOpen||feedback.RaidWarningVisible||Raid!=null&&!Raid.Running;
            for(int i=0;i<feedRows.Length;i++)
            {
                var notice=feedNotices[i];var row=feedRows[i];bool visible=!hide&&notice.until>Time.unscaledTime;
                row.row.style.display=visible?DisplayStyle.Flex:DisplayStyle.None;if(!visible)continue;
                string type=notice.kind=="heal"?"회복":notice.kind=="barrier"||notice.kind=="guard"?"보호":notice.kind=="control"?"제어":"시전";
                row.owner.text=(string)Simulation.Catalog.Hero(notice.hero)["name"]+" · "+type;row.skill.text=notice.skill;
                row.row.style.opacity=Mathf.Min(1,(notice.until-Time.unscaledTime)/.22f);
            }
        }
        void ResetCombatReadability(){Array.Clear(feedNotices,0,feedNotices.Length);VisibleRaidResponseKind="";if(responseCue!=null)responseCue.style.display=DisplayStyle.None;}
    }
}
