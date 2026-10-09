using System;
using System.Collections.Generic;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Settled hits only: this queue owns presentation, never combat state.
    public sealed class CombatHitFeedbackTimeline
    {
        public const int Capacity=128;
        struct Pending {public BattleEvent Event;public float Remaining;public bool Active;}
        readonly Pending[] pending=new Pending[Capacity];
        readonly IReadOnlyDictionary<string,SkillVfxProfile> profiles;
        public int Count {get;private set;}
        public int Dropped {get;private set;}
        public CombatHitFeedbackTimeline(IReadOnlyDictionary<string,SkillVfxProfile> profiles){this.profiles=profiles;}
        public void Enqueue(BattleEvent e,CombatEncounter battle,Action<BattleEvent> present)
        {
            float delay=0;
            if(e.Kind!="hero_hit"&&profiles.TryGetValue(e.Source+":"+e.Slot,out var profile))
            {
                foreach(var hero in battle.Heroes)if(hero.Serial==e.SourceSerial)
                {delay=SkillVfxBatch.FlightDuration(profile,Vector2.Distance(hero.Position,e.Position));break;}
            }
            if(delay<=0){present(e);return;}
            for(int i=0;i<Capacity;i++)if(!pending[i].Active)
            {pending[i]=new Pending{Event=e,Remaining=delay,Active=true};Count++;return;}
            Dropped++; // Drop saturated visual feedback; the hit is already settled.
        }
        public void Advance(float delta,Action<BattleEvent> present)
        {
            for(int i=0;i<Capacity;i++)if(pending[i].Active)
            {
                var hit=pending[i];hit.Remaining-=Mathf.Max(0,delta);
                if(hit.Remaining<=0){pending[i]=default;Count--;present(hit.Event);}
                else pending[i]=hit;
            }
        }
        public void Clear(){Array.Clear(pending,0,Capacity);Count=0;}
    }
}
