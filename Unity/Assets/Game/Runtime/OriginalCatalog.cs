using System;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Original JSON is imported byte-for-byte. Stable IDs are the migration keys.
    [Serializable] public sealed class HeroCatalog { public int hero_count, skill_count; public HeroDefinition[] heroes; }
    [Serializable] public sealed class HeroDefinition
    {
        public string id, name, faction, role_group, reach, color, identity;
        public int unlock_stage;
        public SkillDefinition[] skills;
    }
    [Serializable] public sealed class SkillDefinition
    {
        public string id, slot, skill, kind, effect;
        public float cooldown, value, duration;
    }
    [Serializable] public sealed class ActorCatalog { public ActorEntry[] entries; }
    [Serializable] public sealed class ActorEntry { public string id; public bool hero; }
    [Serializable] public sealed class AtlasDefinition { public string id; public PoseSet attack, motion; }
    [Serializable] public sealed class PoseSet { public float native_height; public PoseFrame[] frames; }
    [Serializable] public sealed class PoseFrame { public float[] region, anchor, hair_rect; }

    public static class OriginalCatalog
    {
        public static HeroCatalog Heroes => JsonUtility.FromJson<HeroCatalog>(Required("hero-catalog").text);
        public static ActorCatalog Actors => JsonUtility.FromJson<ActorCatalog>(Required("actor-catalog").text);
        public static bool HasStyle(string id)=>Resources.Load<TextAsset>("Eternal/HeroStyles/"+id+"/frames")!=null;
        public static AtlasDefinition Atlas(string id) => JsonUtility.FromJson<AtlasDefinition>((HasStyle(id)?Resources.Load<TextAsset>("Eternal/HeroStyles/"+id+"/frames"):Required("Actors/" + id + "/frames")).text);
        public static Texture2D Texture(string id)=>Resources.Load<Texture2D>(HasStyle(id)?"Eternal/HeroStyles/"+id+"/poses":"Eternal/Actors/"+id+"/poses");
        public static TextAsset Required(string path) => Resources.Load<TextAsset>("Eternal/" + path)
            ?? throw new InvalidOperationException("Missing original data: " + path + ". Run Eternal > Import original assets.");
    }
}
