using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public readonly struct ChainSkill : IEquatable<ChainSkill>
    {
        public readonly string Hero,Slot;
        public ChainSkill(string hero,string slot){Hero=hero;Slot=slot;}
        public bool Equals(ChainSkill other)=>Hero==other.Hero&&Slot==other.Slot;
        public override bool Equals(object obj)=>obj is ChainSkill s&&Equals(s);
        public override int GetHashCode()=>HashCode.Combine(Hero,Slot);
        public override string ToString()=>Hero+":"+Slot;
    }

    // Ordered cast intent only. A chain never spends cooldowns, adds damage or
    // advances from a visual notification. All usefulness gates still apply.
    public sealed class PartySkillChain
    {
        readonly List<ChainSkill> entries=new();
        readonly CombatEncounter battle;
        public IReadOnlyList<ChainSkill> Entries=>entries;
        public bool Enabled;
        public int Cursor {get;private set;}
        public int CompletedCycles {get;private set;}
        public int ConfirmedCasts {get;private set;}
        public ChainSkill? Current=>entries.Count==0?null:entries[Cursor];
        public PartySkillChain(CombatEncounter context){battle=context;}
        public void ConfigureDefault()
        {
            entries.Clear();Cursor=0;CompletedCycles=0;ConfirmedCasts=0;
            // Prefer control -> weakness -> exposure -> follow-up -> burst.
            // The original profile supplies every effect and numeric modifier.
            foreach(string signature in new[]{"kairen:a1","lunea:a1","kairen:a2","lunea:a2","mira:a2","darius:a1"})
            {var parts=signature.Split(':');var s=new ChainSkill(parts[0],parts[1]);if(Valid(s))entries.Add(s);}
            foreach(var hero in battle.Heroes)
            foreach(string slot in new[]{"a1","a2"})
            {
                if(entries.Count>=6)return;var s=new ChainSkill(hero.Id,slot);
                var p=battle.Kits[hero.Id].Profiles[slot];
                if(LegacyCombatRules.NeedsEnemy(p)&&!entries.Contains(s))entries.Add(s);
            }
        }
        bool Valid(ChainSkill skill)=>battle.Kits.TryGetValue(skill.Hero,out var kit)&&skill.Slot!="passive"&&kit.Profiles.ContainsKey(skill.Slot);
        public bool Restore(IReadOnlyList<ChainSkill> saved,bool enabled)
        {
            if(saved==null||saved.Count<1||saved.Count>6||saved.Distinct().Count()!=saved.Count||saved.Any(s=>s.Hero==null||!Valid(s)))return false;
            entries.Clear();entries.AddRange(saved);Enabled=enabled;Cursor=CompletedCycles=ConfirmedCasts=0;return true;
        }
        public bool Set(int index,ChainSkill skill)
        {
            if(index<0||index>=entries.Count||!Valid(skill))return false;
            int duplicate=entries.IndexOf(skill);if(duplicate>=0&&duplicate!=index)entries[duplicate]=entries[index];
            entries[index]=skill;Cursor=0;return true;
        }
        public bool Move(int index,int offset)
        {
            int destination=index+offset;if(index<0||destination<0||index>=entries.Count||destination>=entries.Count)return false;
            (entries[index],entries[destination])=(entries[destination],entries[index]);Cursor=0;return true;
        }
        public string Choose(Combatant hero,string preferred)
        {
            if(!Enabled||entries.Count==0||!hero.Alive)return preferred;
            var r=battle.Kits[hero.Id];
            // Triage is never blocked behind an offensive chain step.
            if(preferred!="basic")
            {string kind=(string)r.Profiles[preferred]["kind"];if(kind=="heal"||kind=="barrier"||kind=="guard")return preferred;}
            // A defeated chain owner cannot freeze the expedition. This skips
            // the entry, not a spell: no cooldown/energy/event is consumed.
            for(int i=0;i<entries.Count;i++)
            {
                var next=entries[Cursor];if(battle.Heroes.Any(h=>h.Alive&&h.Id==next.Hero))break;
                Cursor=(Cursor+1)%entries.Count;
            }
            var current=entries[Cursor];
            bool auto=current.Slot=="ultimate"?battle.UltimateAuto:battle.SkillsAuto;
            if(current.Hero==hero.Id&&auto&&HeroKitExecution.Priority(battle,hero,current.Slot)>=55)return current.Slot;
            return entries.Contains(new ChainSkill(hero.Id,preferred))?"basic":preferred;
        }
        public void Observe(BattleEvent e)
        {
            if(!Enabled||e.Kind!="cast"||entries.Count==0||!entries[Cursor].Equals(new ChainSkill(e.Source,e.Slot)))return;
            ConfirmedCasts++;Cursor++;if(Cursor==entries.Count){Cursor=0;CompletedCycles++;}
        }
        public double Remaining()
        {
            if(Current is not ChainSkill c||!battle.Kits.TryGetValue(c.Hero,out var kit))return 0;
            if(c.Slot=="ultimate")return Math.Max(0,100-(battle.Heroes.FirstOrDefault(h=>h.Id==c.Hero)?.Ultimate??0));
            return kit.Cooldowns.GetValueOrDefault(c.Slot);
        }
    }
}
