using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Frozen cast geometry. Both rendering and settlement consume this object;
    // moon marks never follow their targets after the warning appears.
    public sealed class RaidFootprint
    {
        public const float PixelsPerUnit=25;
        public static readonly Rect Floor=new(-12.2f,-4.12f,24.4f,8.24f);
        public readonly string Shape;
        public readonly Vector2 Center,Direction;
        public readonly float Radius,Inner,HalfAngle;
        public readonly Rect[] Rectangles;
        public readonly Vector2[] Marks;
        RaidFootprint(string shape,Vector2 center,float radius=0,float inner=0,float halfAngle=0,Vector2 direction=default,Rect[] rects=null,Vector2[] marks=null)
        {Shape=shape;Center=center;Radius=radius;Inner=inner;HalfAngle=halfAngle;Direction=direction;Rectangles=rects??Array.Empty<Rect>();Marks=marks??Array.Empty<Vector2>();}
        public static Vector2 Clamp(Vector2 p)=>new(Mathf.Clamp(p.x,Floor.xMin+.48f,Floor.xMax-.48f),Mathf.Clamp(p.y,Floor.yMin+.4f,Floor.yMax-.4f));
        public static RaidFootprint Create(string kind,Vector2 boss,IReadOnlyList<Vector2> marks,JObject profile)
        {
            float N(string key,float fallback)=>(float)LegacyCombatRules.Number(profile,key,fallback)/PixelsPerUnit;
            var center=marks.Count>0?marks[0]:boss-Vector2.right*6;
            switch(kind)
            {
                case "front_blast":case "rear_blast":
                    float width=N("width",142);return new RaidFootprint("rects",center,rects:new[]{new Rect(center.x-width/2,Floor.yMin,width,Floor.height)});
                case "double_lane":
                    width=N("width",76);float gap=N("gap",108);return new RaidFootprint("rects",center,rects:new[]{new Rect(center.x-gap-width/2,Floor.yMin,width,Floor.height),new Rect(center.x+gap-width/2,Floor.yMin,width,Floor.height)});
                case "cross":
                    width=N("width",80);return new RaidFootprint("rects",center,rects:new[]{new Rect(center.x-width/2,Floor.yMin,width,Floor.height),new Rect(Floor.xMin,center.y-width/2,Floor.width,width)});
                case "cone":
                    var direction=(center-boss).normalized;if(direction.sqrMagnitude<.01f)direction=Vector2.left;
                    return new RaidFootprint("cone",boss,N("radius",290),halfAngle:(float)LegacyCombatRules.Number(profile,"half_angle",.58),direction:direction);
                case "moon_mark":
                    var copy=new Vector2[marks.Count];for(int i=0;i<copy.Length;i++)copy[i]=marks[i];return new RaidFootprint("marks",boss,N("radius",54),marks:copy);
                case "earthquake":return new RaidFootprint("ring",boss,N("outer",230),N("inner",102));
                case "curse":return new RaidFootprint("circle",boss,N("radius",310));
                default:return new RaidFootprint("circle",boss,N("radius",260));
            }
        }
        public bool Contains(Vector2 point)
        {
            switch(Shape)
            {
                case "rects":foreach(var r in Rectangles)if(r.Contains(point))return true;return false;
                case "marks":foreach(var mark in Marks)if(Vector2.Distance(point,mark)<=Radius)return true;return false;
                case "ring":float d=Vector2.Distance(point,Center);return d>=Inner&&d<=Radius;
                case "cone":var offset=point-Center;return offset.magnitude<=Radius&&(offset.sqrMagnitude<1/(PixelsPerUnit*PixelsPerUnit)||Mathf.Abs(Vector2.SignedAngle(Direction,offset))*Mathf.Deg2Rad<=HalfAngle);
                case "circle":return Vector2.Distance(point,Center)<=Radius;
                default:return false;
            }
        }
        public Vector2 Escape(Vector2 point)
        {
            if(!Contains(point))return point;
            var best=point;float shortest=float.MaxValue;
            void Consider(Vector2 candidate)
            {candidate=Clamp(candidate);float d=(candidate-point).sqrMagnitude;if(!Contains(candidate)&&d<shortest){best=candidate;shortest=d;}}
            foreach(float radius in new[]{66f,116f,174f,236f,300f})for(int i=0;i<16;i++)
            {float a=i*Mathf.PI*2/16;Consider(point+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*radius/PixelsPerUnit);}
            foreach(float x in new[]{Floor.xMin+.48f,Floor.xMax-.48f})foreach(float y in new[]{Floor.yMin+.4f,Floor.center.y,Floor.yMax-.4f})Consider(new Vector2(x,y));
            return best;
        }
        public IEnumerable<Vector2[]> Outlines(int segments=80)
        {
            Vector2[] Circle(Vector2 center,float radius)
            {var p=new Vector2[segments];for(int i=0;i<segments;i++){float a=i*Mathf.PI*2/segments;p[i]=center+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*radius;}return p;}
            if(Shape=="rects")foreach(var r in Rectangles)yield return new[]{new Vector2(r.xMin,r.yMin),new Vector2(r.xMin,r.yMax),new Vector2(r.xMax,r.yMax),new Vector2(r.xMax,r.yMin)};
            else if(Shape=="marks")foreach(var p in Marks)yield return Circle(p,Radius);
            else if(Shape=="cone")
            {
                var p=new Vector2[segments+2];p[0]=Center;float angle=Mathf.Atan2(Direction.y,Direction.x);
                for(int i=0;i<=segments;i++){float a=angle-HalfAngle+2*HalfAngle*i/segments;p[i+1]=Center+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*Radius;}yield return p;
            }
            else {yield return Circle(Center,Radius);if(Shape=="ring")yield return Circle(Center,Inner);}
        }
    }
}
