using System;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Coordinates use the same projected body clearance as live hunting.
    // Balanced keeps the requested ten-person circle; other formations expose
    // party order as a visible position without changing original row bonuses.
    public static class HuntFormationLayout
    {
        public static Vector2 Position(string formation,int slot,int count)
        {
            if(count<1||count>10||slot<0||slot>=count)throw new ArgumentOutOfRangeException(nameof(slot));
            if(formation=="balanced")
            {double angle=slot*Math.PI*2/count;return new Vector2(-3+(float)Math.Cos(angle)*3.2f,(float)Math.Sin(angle)*4.8f);}
            if(formation=="bulwark"||formation=="volley")
            {
                int column=slot/5,lane=slot%5,lanes=Math.Min(5,count-column*5);
                return new Vector2(formation=="bulwark"?-1-column*3f:-2.5f-column*3f,(lane-(lanes-1)*.5f)*3f);
            }
            int row=slot<3?0:slot<7?1:2,start=row==0?0:row==1?3:7;
            int width=Math.Min(row==1?4:3,count-start);
            return new Vector2(-.2f-row*3f,(slot-start-(width-1)*.5f)*3f);
        }
        public static string Description(string formation)=>formation switch
        {
            "assault"=>"돌격형 · 앞 3명 / 중앙 4명 / 뒤 3명 · 공격력 +20%",
            "bulwark"=>"방벽형 · 5명씩 두 줄 · 체력 +20%",
            "volley"=>"일제사격형 · 5명씩 두 줄 · 공격 속도 +20%",
            _=>"균형형 · 10명 원형 · 공격력·체력 +10%"
        };
        public static Vector2 Entrance(int slot,int encounter)
        {
            double angle=(slot+.5)*Math.PI*2/12+(encounter%6)*.19;
            return new Vector2((float)Math.Cos(angle)*10.6f,(float)Math.Sin(angle)*6.1f);
        }
        public static Vector2 ExpandedEntrance(int slot,int encounter,int count)
        {
            // Two staggered perimeter rings keep 24–32 arrivals spread across
            // the full map instead of reusing the twelve original entrances.
            int ring=slot%2,index=slot/2,slots=(count+1-ring)/2;
            double angle=(index+.5+ring*.5)*Math.PI*2/slots+(encounter%6)*.19;
            return new Vector2((float)Math.Cos(angle)*(ring==0?20.8f:17.8f),(float)Math.Sin(angle)*(ring==0?11.6f:9.1f));
        }
    }
}
