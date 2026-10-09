using System;
using System.Collections.Generic;
using System.Linq;

namespace Eternal.UnityMigration
{
    // Explicit content selection for the 3D pilot. The default live hunt still
    // uses the canonical stage roster/population and player-state rules.
    public sealed class HuntEncounterOptions
    {
        public IReadOnlyList<string> Monsters {get;}
        public int Population {get;}
        public bool VolumeBodies {get;}
        public HuntEncounterOptions(IEnumerable<string> monsters,int population=18,bool volumeBodies=true)
        {
            var ids=monsters?.Distinct(StringComparer.Ordinal).ToArray()??Array.Empty<string>();
            if(ids.Length==0||ids.Any(id=>!FallenMonsterCatalog.Contains(id)))throw new ArgumentException("A hunting encounter needs known fallen monster IDs.",nameof(monsters));
            if(population<15||population>20)throw new ArgumentOutOfRangeException(nameof(population),"The graphics pilot has 15–20 arrivals.");
            Monsters=Array.AsReadOnly(ids);Population=population;VolumeBodies=volumeBodies;
        }
    }
}
