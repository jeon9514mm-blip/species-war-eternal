using System;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // A projection of existing encounter counters, never an additional target,
    // health pool, damage source, reward or simulated countdown.
    public readonly struct RaidMechanicView
    {
        public readonly string Kind,Title;
        public readonly int Count,Remaining,Maximum;
        public readonly float Progress,Seconds;
        public readonly Vector2 Center;
        public readonly bool Visible,Muted;
        RaidMechanicView(string kind,string title,int count,int remaining,int maximum,float seconds,Vector2 center,bool muted)
        {Kind=kind;Title=title;Count=Math.Clamp(count,1,6);Remaining=Math.Max(0,remaining);Maximum=Math.Max(1,maximum);Progress=Mathf.Clamp01(1-(float)Remaining/Maximum);Seconds=Mathf.Max(0,seconds);Center=center;Visible=true;Muted=muted;}
        public static RaidMechanicView Read(RaidSimulation raid)
        {
            if(raid==null||!raid.Running)return default;
            bool muted=raid.Warning!=null||raid.SecondWarning!=null;
            if(raid.GuardHp>0)return new RaidMechanicView("armor","대지 갑주",6,raid.GuardHp,raid.GuardMax,0,raid.Boss.Position,muted);
            if(raid.AddHp>0)return new RaidMechanicView("crystal","수정핵 연결",raid.AddCount,raid.AddHp,raid.AddMax,0,raid.Boss.Position,muted);
            if(raid.DpsRemaining>0&&raid.DpsTarget>0)return new RaidMechanicView("ritual","월식 의식",3,raid.DpsTarget-raid.DpsDamage,raid.DpsTarget,(float)raid.DpsRemaining,raid.Boss.Position,muted);
            return default;
        }
        public Vector2 Anchor(int index)
        {
            if(!Visible||index<0||index>=Count)return Center;
            if(Kind=="armor")
            {float angle=index*Mathf.PI*2/Count;return Center+new Vector2(Mathf.Cos(angle)*2.3f,Mathf.Sin(angle)*2.5f);}
            // Separate north/south/entrance pedestals remain within the arena.
            // Count is an aggregate encounter count; individual visuals have no HP.
            if(Count<=3)return new Vector2(Mathf.Clamp(Center.x+(index==2?-4.8f:1.2f),-10.8f,10.8f),index==0?-3.35f:index==1?3.35f:0);
            return new Vector2(-8+index*3.2f,index%2==0?-3.35f:3.35f);
        }
    }
}
