using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Shared engagement preference, not an extra controller or combat clock.
    public static class HuntExpeditionPlan
    {
        public const float CohesionRadius=8f;
        public static void Select(CombatEncounter battle,Vector2 center,HashSet<int> selected)
        {
            selected.Clear();var nearby=battle.Enemies.Where(e=>e.Alive&&!e.Returning).OrderBy(e=>Vector2.SqrMagnitude(e.Position-center)).ThenBy(e=>e.Serial).ToArray();
            if(nearby.Length==0)return;float nearest=Vector2.Distance(nearby[0].Position,center);
            foreach(var enemy in nearby.Take(6))if(Vector2.Distance(enemy.Position,center)<=nearest+4)selected.Add(enemy.Serial);
        }
        public static Vector2 CohesiveGoal(Vector2 requested,Vector2 center)=>center+Vector2.ClampMagnitude(requested-center,CohesionRadius);
        public static Vector2 Direction(CombatEncounter battle,Vector2 center,HashSet<int> selected)
        {
            Vector2 front=Vector2.zero;float weight=0;
            foreach(var enemy in battle.Enemies)if(enemy.Alive&&selected.Contains(enemy.Serial)){float w=1/Mathf.Max(1,Vector2.Distance(enemy.Position,center));front+=(enemy.Position-center)*w;weight+=w;}
            return weight>0&&front.sqrMagnitude>.01f?front.normalized:Vector2.right;
        }
        public static string RoleLane(Combatant hero)=>hero.Role=="탱커"||hero.Style=="protector"?"front":hero.Role=="서포터"||hero.Style=="support"?"rear":hero.Role=="컨트롤러"||hero.Style=="controller"||hero.Style=="control"?"flank":hero.Range>=3?"ranged":"front";
        public static Vector2 ApproachAnchor(Combatant hero,Vector2 center,Vector2 front)
        {
            if(front.sqrMagnitude<.01f)front=Vector2.right;front.Normalize();var side=new Vector2(-front.y,front.x);float sign=hero.Slot%2==0?-1:1;
            return RoleLane(hero) switch{"rear"=>center-front*1.8f+side*sign*1.1f,"flank"=>center-front*.6f+side*sign*2.2f,"ranged"=>center-front*1.0f+side*sign*1.4f,_=>center+front*1.1f+side*sign*.9f};
        }
    }
}
