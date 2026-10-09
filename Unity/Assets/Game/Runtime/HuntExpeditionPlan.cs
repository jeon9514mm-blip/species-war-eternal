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
    }
}
