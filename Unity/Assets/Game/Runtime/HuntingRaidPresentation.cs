using System;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        Button spreadButton,followButton;
        VisualElement raidPhaseRow,raidPhaseToast,raidMechanicTag;
        readonly Label[] raidPhases=new Label[3];
        Label raidPhaseTitle,raidPhaseDetail,raidMechanicName,raidMechanicValue;
        RaidSimulation presentedRaid;
        int presentedPhase;
        double phaseUntil;
        VisualElement raidResolution;
        Label raidResolutionTitle,raidResolutionDetail;
        float resolutionUntil;
        RaidSimulation resolutionRaid;
        public bool RaidResolutionVisible=>raidResolution!=null&&raidResolution.style.display.value!=DisplayStyle.None;
        bool RaidResolutionPending=>Raid!=null&&resolutionRaid==Raid&&Raid.Running&&Time.unscaledTime<resolutionUntil;
        void ObserveRaidResolution(BattleEvent e)
        {
            if(Raid==null||!Raid.Running||raidResolution==null)return;
            string title=e.Kind switch{"interrupt"=>"무력화 성공","counter"=>"정면 카운터 성공","shield_break"=>"방어 기믹 파괴","mechanic_success"=>"의식 파훼 성공",_=>null};
            if(title==null)return;
            resolutionRaid=Raid;resolutionUntil=Time.unscaledTime+.95f;
            raidResolutionTitle.text=title;
            string hero=string.IsNullOrEmpty(e.Source)?"":(string)Simulation.Catalog.Hero(e.Source)?["name"];
            raidResolutionDetail.text=(string.IsNullOrEmpty(hero)?"":hero+" · ")+(Raid.Boss.Vulnerable>0?"보스 취약 "+Raid.Boss.Vulnerable.ToString("F1")+"초":"다음 전조에 대비하세요");
        }
        public bool RaidPhaseBannerVisible=>raidPhaseToast!=null&&raidPhaseToast.style.display.value!=DisplayStyle.None;
        public string VisibleRaidMechanic {get;private set;}="";
        void BuildRaidPresentation()
        {
            raidPhaseRow=Row(root);raidPhaseRow.name="raid-phase-timeline";raidPhaseRow.style.position=Position.Absolute;raidPhaseRow.style.left=24;raidPhaseRow.style.top=106;raidPhaseRow.style.width=290;raidPhaseRow.style.height=27;raidPhaseRow.pickingMode=PickingMode.Ignore;raidPhaseRow.style.display=DisplayStyle.None;
            for(int i=0;i<3;i++){var phase=Text(raidPhaseRow,"",11);phase.style.flexGrow=1;phase.style.unityTextAlign=TextAnchor.MiddleCenter;phase.style.paddingTop=5;phase.style.paddingBottom=5;phase.style.marginRight=3;phase.style.backgroundColor=Ink;phase.pickingMode=PickingMode.Ignore;raidPhases[i]=phase;}
            raidPhaseToast=Box(root,"raid-phase-transition",new Color(.04f,.055f,.065f,.94f));raidPhaseToast.style.position=Position.Absolute;raidPhaseToast.style.left=24;raidPhaseToast.style.top=135;raidPhaseToast.style.width=290;raidPhaseToast.style.height=62;raidPhaseToast.style.overflow=Overflow.Hidden;raidPhaseToast.style.paddingLeft=raidPhaseToast.style.paddingRight=8;raidPhaseToast.style.paddingTop=raidPhaseToast.style.paddingBottom=5;raidPhaseToast.style.display=DisplayStyle.None;raidPhaseToast.pickingMode=PickingMode.Ignore;
            raidPhaseTitle=Text(raidPhaseToast,"",14);raidPhaseTitle.style.color=Bronze;raidPhaseTitle.style.unityTextAlign=TextAnchor.MiddleLeft;raidPhaseTitle.pickingMode=PickingMode.Ignore;
            raidPhaseDetail=Text(raidPhaseToast,"",10);raidPhaseDetail.style.color=Parchment;raidPhaseDetail.style.whiteSpace=WhiteSpace.Normal;raidPhaseDetail.style.unityTextAlign=TextAnchor.MiddleLeft;raidPhaseDetail.pickingMode=PickingMode.Ignore;
            foreach(var line in new[]{raidPhaseTitle,raidPhaseDetail}){line.style.marginTop=line.style.marginBottom=line.style.paddingTop=line.style.paddingBottom=0;line.style.flexShrink=0;}
            raidPhaseTitle.style.height=20;raidPhaseDetail.style.height=29;
            raidMechanicTag=Box(root,"raid-world-mechanic",new Color(.03f,.05f,.06f,.85f));raidMechanicTag.style.position=Position.Absolute;raidMechanicTag.style.left=24;raidMechanicTag.style.top=135;raidMechanicTag.style.width=290;raidMechanicTag.style.height=54;raidMechanicTag.style.paddingLeft=raidMechanicTag.style.paddingRight=8;raidMechanicTag.style.paddingTop=raidMechanicTag.style.paddingBottom=4;raidMechanicTag.style.display=DisplayStyle.None;raidMechanicTag.pickingMode=PickingMode.Ignore;
            raidMechanicName=Text(raidMechanicTag,"",12);raidMechanicName.style.color=Bronze;raidMechanicName.style.unityTextAlign=TextAnchor.MiddleCenter;raidMechanicName.pickingMode=PickingMode.Ignore;
            raidResolution=Box(root,"raid-resolution",new Color(.04f,.08f,.075f,.94f));raidResolution.style.position=Position.Absolute;raidResolution.style.left=24;raidResolution.style.top=135;raidResolution.style.width=290;raidResolution.style.height=62;raidResolution.style.paddingLeft=raidResolution.style.paddingRight=8;raidResolution.style.paddingTop=5;raidResolution.style.display=DisplayStyle.None;raidResolution.pickingMode=PickingMode.Ignore;
            raidResolutionTitle=Text(raidResolution,"",14);raidResolutionTitle.style.color=Moss;
            raidResolutionDetail=Text(raidResolution,"",11);raidResolutionDetail.style.color=Parchment;
            raidMechanicValue=Text(raidMechanicTag,"",10);raidMechanicValue.style.color=Moss;raidMechanicValue.style.unityTextAlign=TextAnchor.MiddleCenter;raidMechanicValue.pickingMode=PickingMode.Ignore;
        }
        void RefreshRaidPresentation()
        {
            if(raidPhaseRow==null)return;
            bool visible=Raid!=null&&Raid.Running&&modal.style.display.value==DisplayStyle.None;
            raidPhaseRow.style.display=visible?DisplayStyle.Flex:DisplayStyle.None;
            if(!visible){raidResolution.style.display=DisplayStyle.None;raidPhaseToast.style.display=raidMechanicTag.style.display=DisplayStyle.None;VisibleRaidMechanic="";if(Raid==null)presentedRaid=null;return;}
            if(presentedRaid!=Raid||presentedPhase!=Raid.Phase)
            {presentedRaid=Raid;presentedPhase=Raid.Phase;phaseUntil=Raid.Elapsed+1.8;string name=(string)Raid.Mechanic["name"];raidPhaseTitle.text="PHASE "+Raid.Phase+" · "+(string.IsNullOrEmpty(name)?"전투 시작":name);raidPhaseDetail.text=(string)Raid.Mechanic["description"]??"조이스틱으로 전조를 피하고 대응 안내를 확인하세요.";}
            for(int i=0;i<3;i++)
            {raidPhases[i].text="P"+(i+1)+" · "+(i==0?"100%":i==1?"60%":"30%");raidPhases[i].style.color=i+1==Raid.Phase?Ink:i+1<Raid.Phase?Moss:Parchment;raidPhases[i].style.backgroundColor=i+1==Raid.Phase?Bronze:Ink;raidPhases[i].tooltip=(string)Raid.Design["mechanics"][i]["name"];}
            bool warning=Raid.Warning!=null||Raid.SecondWarning!=null;
            bool resolved=resolutionRaid==Raid&&Time.unscaledTime<resolutionUntil&&!warning&&!UltimateCueVisible;
            raidResolution.style.display=resolved?DisplayStyle.Flex:DisplayStyle.None;
            raidPhaseToast.style.display=!resolved&&!warning&&!UltimateCueVisible&&Raid.Elapsed<phaseUntil?DisplayStyle.Flex:DisplayStyle.None;
            var view=RaidMechanicView.Read(Raid);VisibleRaidMechanic=view.Visible?view.Kind:"";raidMechanicTag.style.display=view.Visible&&!resolved&&!warning&&!RaidPhaseBannerVisible&&!UltimateCueVisible?DisplayStyle.Flex:DisplayStyle.None;
            if(!view.Visible)return;
            raidMechanicName.text=view.Title+(view.Kind=="crystal"?" ×"+view.Count:"");
            raidMechanicValue.text=view.Kind=="ritual"?view.Seconds.ToString("F1")+"초 · "+(view.Maximum-view.Remaining).ToString("N0")+" / "+view.Maximum.ToString("N0"):"공용 체력 "+view.Remaining.ToString("N0");
        }
    }
}
