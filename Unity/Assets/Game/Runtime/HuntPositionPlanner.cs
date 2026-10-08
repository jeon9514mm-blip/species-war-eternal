using System.Collections.Generic;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Role standoffs adapted from PartyMovementDirector. A goal is a steering
    // request only: the hunting body solver remains the movement authority.
    public static class HuntPositionPlanner
    {
        public static float PreferredStandoff(Combatant hero,bool melee)
        {
            if(melee)
            {
                if(hero.Role=="탱커"||hero.Style=="protector")return .56f;
                if(hero.Role=="컨트롤러"||hero.Style=="controller"||hero.Style=="control")return .66f;
                if(hero.Style=="aggressive"||hero.Style=="finisher")return .70f;
                return hero.Style=="sustain"?.60f:.62f;
            }
            bool far=hero.Range>=3;
            if(hero.Role=="서포터"||hero.Style=="support")return far?1.60f:1.18f;
            if(hero.Role=="컨트롤러"||hero.Style=="controller"||hero.Style=="control")return far?1.52f:1.16f;
            if(hero.Style=="finisher")return far?1.62f:1.18f;
            if(hero.Style=="aggressive")return far?1.38f:1.10f;
            return far?1.46f:1.14f;
        }
        static Vector2 Rotate(Vector2 v,float angle)
        {float c=Mathf.Cos(angle),s=Mathf.Sin(angle);return new Vector2(v.x*c-v.y*s,v.x*s+v.y*c);}
        static Vector2 Clamp(Vector2 p)=>new(Mathf.Clamp(p.x,-11.5f,11.5f),Mathf.Clamp(p.y,-6.5f,6.5f));
        public static Vector2 Goal(HuntingSimulation sim,Combatant hero,Combatant target,bool melee,Vector2 center,IReadOnlyDictionary<int,Vector2> reservations,Vector2 retained,bool hasRetained)
        {
            float reach=(float)CombatTargeting.Reach(hero),preferred=Mathf.Min(PreferredStandoff(hero,melee),reach-.12f);
            // Holding a clear firing station is more important than cosmetic
            // repositioning. Otherwise a moving target can leave range during
            // every windup while an available attack is needlessly postponed.
            if(Vector2.Distance(hero.Position,target.Position)<=reach*.94f)return hero.Position;
            Vector2 away=center-target.Position;if(away.sqrMagnitude<.01f)away=hero.Position-target.Position;if(away.sqrMagnitude<.01f)away=Vector2.left;away.Normalize();
            float side=hero.Slot%2==0?-1:1;
            bool support=hero.Role=="서포터"||hero.Style=="support",control=hero.Role=="컨트롤러"||hero.Style=="controller"||hero.Style=="control";
            Vector2 roleDirection=melee&&hero.Role=="딜러"&&(hero.Style=="aggressive"||hero.Style=="finisher")?Rotate(away,1.10f*side):melee&&control?Rotate(away,.62f*side):away;
            Vector2 front=-away,lateral=new(-front.y,front.x),best=target.Position+roleDirection*preferred;float bestScore=float.PositiveInfinity;
            var contact=sim.BodyAxes(hero,target);
            // Current and retained positions get a small hysteresis advantage.
            // Eighteen angular candidates leave side lanes around a crowded foe.
            for(int i=-2;i<18;i++)
            {
                Vector2 point;
                if(i==-2)point=hero.Position;
                else if(i==-1){if(!hasRetained)continue;point=target.Position+retained;}
                else
                {
                    var offset=Rotate(roleDirection,i*Mathf.PI*2/18)*preferred;
                    float ellipse=new Vector2(offset.x/contact.x,offset.y/contact.y).magnitude;
                    if(ellipse<1.05f)offset*=1.05f/Mathf.Max(.001f,ellipse);
                    point=Clamp(target.Position+offset);
                }
                float distance=Vector2.Distance(point,target.Position);
                if(distance>reach*.98f)continue;
                float score=Mathf.Abs(distance-preferred)*2.5f+Vector2.Distance(point,hero.Position)*.18f;
                foreach(var ally in sim.Battle.Heroes)
                {
                    if(ally==hero||!ally.Alive)continue;var axes=sim.BodyAxes(hero,ally);
                    Vector2 other=reservations.TryGetValue(ally.Serial,out var reserved)?reserved:ally.PreviousPosition,delta=point-other;
                    score+=Mathf.Max(0,1.18f-new Vector2(delta.x/axes.x,delta.y/axes.y).magnitude)*8;
                }
                foreach(var enemy in sim.Battle.Enemies)
                {if(!enemy.Alive)continue;float danger=Mathf.Max(0,.94f-Vector2.Distance(point,enemy.Position));score+=danger*danger*5;}
                if(support)score+=Mathf.Max(0,Vector2.Dot(point-center,front)+.18f)*3.8f;
                if(control)score+=Mathf.Abs(Vector2.Dot(point-center,lateral)-.72f*side)*.65f;
                if(melee)score+=Vector2.Distance(point,target.Position+roleDirection*preferred)*.25f;
                if(i==-2)score-=.10f;else if(i==-1)score-=.24f;
                if(score<bestScore){best=point;bestScore=score;}
            }
            return best;
        }
    }
}
