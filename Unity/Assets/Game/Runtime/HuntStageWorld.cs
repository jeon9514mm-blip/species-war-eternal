using System;
using UnityEngine;

namespace Eternal.UnityMigration
{
    public static class HuntStageWorld
    {
        public const float HalfWidth=23f,HalfDepth=13f;
        public static int Band(int stage)=>Math.Max(1,stage)<500?0:Math.Max(1,stage)/500;
        public static int Start(int stage)=>Band(stage)==0?1:Band(stage)*500;
        public static int End(int stage)=>Band(stage)==0?499:(Band(stage)+1)*500-1;
        public static string Zone(int stage)=>(Band(stage)%3) switch{1=>"forgotten_mine",2=>"moonrest_forest",_=>"gray_meadow"};
        public static string Atmosphere(int stage)=>(Band(stage)%3) switch{1=>"호박빛 광맥",2=>"달빛 숲",_=>"이끼 초원"};
        public static Vector2 Clamp(Vector2 p)=>new(Mathf.Clamp(p.x,-HalfWidth,HalfWidth),Mathf.Clamp(p.y,-HalfDepth,HalfDepth));
    }
}
