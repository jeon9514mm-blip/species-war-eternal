using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        VisualElement movementStick,stickKnob;
        Label stickLabel;
        Button huntFollowButton;
        RaidSimulation stickRaid;
        HuntingSimulation stickHunt;
        int stickPointer=-1;
        void BuildMovementJoystick()
        {
            movementStick=Box(root,"movement-stick",new Color(.03f,.05f,.055f,.68f));movementStick.style.position=Position.Absolute;movementStick.style.left=40;movementStick.style.bottom=330;movementStick.style.width=110;movementStick.style.height=110;
            movementStick.style.borderTopLeftRadius=movementStick.style.borderTopRightRadius=movementStick.style.borderBottomLeftRadius=movementStick.style.borderBottomRightRadius=55;movementStick.style.borderTopColor=movementStick.style.borderBottomColor=movementStick.style.borderLeftColor=movementStick.style.borderRightColor=Bronze;movementStick.style.display=DisplayStyle.None;
            movementStick.tooltip="누른 채 드래그해서 원정대를 이동합니다. 손을 떼면 멈춥니다. 추적 복귀로 자동 이동을 다시 켭니다.";
            stickKnob=Box(movementStick,"movement-stick-knob",new Color(.77f,.65f,.46f,.85f));stickKnob.style.position=Position.Absolute;stickKnob.style.width=44;stickKnob.style.height=44;stickKnob.style.left=33;stickKnob.style.top=33;stickKnob.pickingMode=PickingMode.Ignore;
            stickKnob.style.borderTopLeftRadius=stickKnob.style.borderTopRightRadius=stickKnob.style.borderBottomLeftRadius=stickKnob.style.borderBottomRightRadius=22;
            stickLabel=Text(movementStick,"드래그 이동",10);stickLabel.style.position=Position.Absolute;stickLabel.style.top=112;stickLabel.style.left=-17;stickLabel.style.width=144;stickLabel.style.unityTextAlign=TextAnchor.MiddleCenter;stickLabel.style.color=Bronze;stickLabel.pickingMode=PickingMode.Ignore;
            huntFollowButton=Button(root,"자동 추적",()=>Simulation?.ResumeMovement());huntFollowButton.name="hunt-resume-movement";huntFollowButton.style.position=Position.Absolute;huntFollowButton.style.left=160;huntFollowButton.style.bottom=345;huntFollowButton.style.width=100;huntFollowButton.style.display=DisplayStyle.None;
            movementStick.RegisterCallback<PointerDownEvent>(e=>
            {
                if(stickPointer>=0||e.button!=0||!MovementInputEnabled())return;
                stickPointer=e.pointerId;stickRaid=Raid;stickHunt=Simulation;movementStick.CapturePointer(stickPointer);ReadMovementStick(e.localPosition);e.StopPropagation();
            });
            movementStick.RegisterCallback<PointerMoveEvent>(e=>{if(e.pointerId!=stickPointer)return;ReadMovementStick(e.localPosition);e.StopPropagation();});
            movementStick.RegisterCallback<PointerUpEvent>(e=>{if(e.pointerId!=stickPointer)return;ReleaseMovementStick();e.StopPropagation();});
            movementStick.RegisterCallback<PointerCancelEvent>(e=>{if(e.pointerId==stickPointer)ReleaseMovementStick();});
            movementStick.RegisterCallback<PointerCaptureOutEvent>(e=>{if(e.pointerId==stickPointer)ReleaseMovementStick();});
        }
        bool MovementInputEnabled()=>Simulation!=null&&modal.style.display.value==DisplayStyle.None&&(Raid!=null?Raid.Running&&!Raid.Paused:!Simulation.Paused&&!Simulation.Defeated&&(ChallengeActive||!(ReviewState?.HasDeferredUnityLoot??false)));
        void ReadMovementStick(Vector2 local)
        {
            if(stickRaid!=Raid||stickHunt!=Simulation||!MovementInputEnabled()){ReleaseMovementStick();return;}
            var offset=Vector2.ClampMagnitude((local-new Vector2(55,55))/36,1);float length=offset.magnitude;
            offset=length<.12f?Vector2.zero:offset.normalized*((length-.12f)/.88f);
            stickKnob.style.left=33+offset.x*36;stickKnob.style.top=33+offset.y*36;
            var right=BattleCamera.transform.right;var up=BattleCamera.transform.up;
            var world=new Vector2(right.x,right.z).normalized*offset.x-new Vector2(up.x,up.z).normalized*offset.y;
            if(Raid!=null)Raid.SetManualMovement(world);else Simulation.SetManualMovement(world);
        }
        void ReleaseMovementStick()
        {
            stickRaid?.StopManualMovement();stickHunt?.StopManualMovement();int captured=stickPointer;stickPointer=-1;
            if(movementStick!=null&&captured>=0&&movementStick.HasPointerCapture(captured))movementStick.ReleasePointer(captured);
            if(stickKnob!=null){stickKnob.style.left=33;stickKnob.style.top=33;}
        }
        void RefreshMovementJoystick()
        {
            if(movementStick==null)return;
            bool visible=Simulation!=null&&modal.style.display.value==DisplayStyle.None&&(Raid!=null?Raid.Running:!Simulation.Defeated);
            if(!MovementInputEnabled()||stickRaid!=Raid||stickHunt!=Simulation){ReleaseMovementStick();stickRaid=Raid;stickHunt=Simulation;}
            movementStick.style.display=visible?DisplayStyle.Flex:DisplayStyle.None;movementStick.SetEnabled(MovementInputEnabled());movementStick.style.opacity=MovementInputEnabled()?1:.45f;
            bool manual=Raid!=null?Raid.ManualMovementActive:Simulation?.ManualMovementActive==true;stickLabel.text=manual?"직접 이동 · 손 떼면 정지":"드래그 이동";
            huntFollowButton.style.display=visible&&Raid==null&&manual?DisplayStyle.Flex:DisplayStyle.None;huntFollowButton.SetEnabled(MovementInputEnabled());
        }
        void OnApplicationFocus(bool focused){if(!focused){ReleaseMovementStick();if(PersistentPlayer&&ReviewState!=null&&ReviewState.MutationError.Length==0)ReviewState.StampIdleTime();}}
        void OnApplicationPause(bool paused){if(paused){ReleaseMovementStick();if(PersistentPlayer&&ReviewState!=null&&ReviewState.MutationError.Length==0)ReviewState.StampIdleTime();}}
        void OnDisable(){ReleaseMovementStick();}
    }
}
