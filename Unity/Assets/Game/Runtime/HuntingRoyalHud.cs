using System;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        public RoyalGroveHuntHud RoyalHud {get;private set;}
        string royalSelection;

        void InstallRoyalHud()
        {
            // A UIDocument below another UIDocument must share its panel. The
            // two independent overlays therefore live under the owned world.
            var owner=new GameObject("Live royal hunting UI");owner.transform.SetParent(worldRoot.transform,false);
            RoyalHud=owner.AddComponent<RoyalGroveHuntHud>();
            RoyalHud.Initialize(BattleCamera,Simulation,id=>{royalSelection=id;RefreshRoyalHud();},CastRoyalSkill,
                MoveRoyalParty,StopRoyalMovement,ResumeRoyalMovement,feedback.SetHuntZoom,ToggleRoyalPause,
                ()=>{if(PersistentPlayer)RestartPlayerHunt(false);});
            RoyalHud.UseNativeBindings(new RoyalHudBindings
            {
                Battle=()=>ActiveBattle,Paused=()=>Raid?.Paused??Simulation.Paused,
                Finished=()=>Raid!=null?!Raid.Running:Simulation.Defeated,
                Defeated=()=>Raid!=null?Raid.Outcome=="defeat"||Raid.Outcome=="timeout":Simulation.Defeated,
                ManualMovement=()=>Raid?.ManualMovementActive??Simulation.ManualMovementActive,
                OverlayBlocking=()=>InspectionIsOpen,ZoomVisible=()=>Raid==null,
                InputAllowed=()=>MovementInputEnabled()&&!ReviewState.SavePending,
                CanCast=(id,slot)=>!InspectionIsOpen&&!ReviewState.SavePending&&
                    (Raid!=null?Raid.CanManualCastSlot(id,slot):Simulation.CanManualCast(id,slot)),
                Stage=()=>Raid!=null?(string)HuntingSimulation.Canonical["zones"][Raid.Zone]["boss"]:
                    ChallengeActive?activeChallenge.Title:"왕립 수림   ·   "+Simulation.Stage+" 스테이지",
                Progress=()=>Raid!=null?Raid.EventText:
                    ChallengeActive?Math.Max(0,activeChallenge.Limit-activeChallenge.Elapsed).ToString("F1")+"초 · "+activeChallenge.Waves+"무리":
                    "무리 "+(Simulation.PacksCleared+1)+" · 남은 적 "+ActiveBattle.Enemies.Count(e=>e.Alive)+
                    (Simulation.Paused?" · 일시정지":" · 교전 중"),
                Navigate=OpenPanel,Manage=ShowStateMenu
            });
            panel.sortingOrder=1;root.pickingMode=PickingMode.Ignore;huntBattleSpace.pickingMode=PickingMode.Ignore;
            ApplyRoyalHudLayout();RefreshRoyalHud();
        }
        void ShowAccountFaction()
        {
            PanelHeader("같은 계정 · 진영 전환");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            Text(scroll,"재화와 성장 기록을 공유하며 영토·행군·편성은 진영별로 유지합니다. 별도의 기존 계정 파일은 합치지 않습니다.",14).style.whiteSpace=WhiteSpace.Normal;
            foreach(string faction in new[]{"aurelia","noxfera"}){string choice=faction;GrowthButton(scroll,choice=="aurelia"?"아우렐리아":"녹스페라",()=>ReviewState.SwitchAccountFaction(choice),()=>{playerPartyRefresh=true;CloseInspection();PauseForSaveFailure();},GrowthAllowed&&ReviewState.Faction!=choice);}
        }
        void CastRoyalSkill(string slot)
        {if(InspectionIsOpen||ReviewState.SavePending)return;if(Raid!=null)Raid.ManualCastSlot(royalSelection,slot);else Simulation.ManualCast(royalSelection,slot);RefreshRoyalHud();}
        void MoveRoyalParty(Vector2 direction)
        {
            if(!MovementInputEnabled())return;var right=BattleCamera.transform.right;var up=BattleCamera.transform.up;
            var world=new Vector2(right.x,right.z).normalized*direction.x+new Vector2(up.x,up.z).normalized*direction.y;
            if(Raid!=null)Raid.SetManualMovement(world);else Simulation.SetManualMovement(world);
        }
        void StopRoyalMovement(){Raid?.StopManualMovement();Simulation?.StopManualMovement();}
        void ResumeRoyalMovement(){if(!MovementInputEnabled())return;if(Raid!=null)Raid.ResumeFormation();else Simulation.ResumeMovement();}
        void ToggleRoyalPause()
        {if(ReviewState.SavePending){PauseForSaveFailure();return;}StopRoyalMovement();if(Raid!=null)Raid.Paused=!Raid.Paused;else Simulation.Paused=!Simulation.Paused;RefreshHud();}
        void RefreshRoyalHud()
        {
            if(RoyalHud==null)return;RoyalHud.BindSimulation(Simulation);
            if(!ActiveBattle.Heroes.Any(h=>h.Id==royalSelection))royalSelection=ActiveBattle.Heroes.FirstOrDefault()?.Id;
            RoyalHud.Refresh(royalSelection,huntNoticeUntil>Time.unscaledTime?huntNotice:"");ApplyRoyalHudLayout();
        }
        void ApplyRoyalHudLayout()
        {
            if(RoyalHud==null)return;
            // The old landscape strip stays available to controller code, but
            // the live display is the user's photographed Unity overlay.
            foreach(var element in new[]{huntHeader,huntDock,movementStick,huntFollowButton,huntMapTools,chainStrip,castCue,skillFeed})
                if(element!=null)element.style.display=DisplayStyle.None;
            BattleCamera.rect=new Rect(0,0,1,1);
            foreach(var element in new[]{raidPhaseRow})if(element!=null)element.style.top=100;
            foreach(var element in new[]{raidPhaseToast,raidMechanicTag,raidResolution})if(element!=null)element.style.top=135;
            if(responseCue!=null)responseCue.style.top=100;
            if(raidCommands!=null){raidCommands.style.left=260;raidCommands.style.right=390;raidCommands.style.bottom=195;}
        }
    }
}
