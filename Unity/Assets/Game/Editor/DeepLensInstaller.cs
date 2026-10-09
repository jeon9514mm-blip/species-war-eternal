using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Eternal.UnityMigration.Editor
{
    public static class DeepLensInstaller
    {
        // URP discovers active profile components during build stripping.
        // This resource preserves our three runtime features without globally
        // disabling stripping or changing the existing battle profile.
        public static string Apply()
        {
            if(Application.isPlaying)throw new InvalidOperationException("Stop Play first.");
            string path="Assets/Game/Resources/Eternal/Materials/DeepLensVariants.asset";
            var profile=AssetDatabase.LoadAssetAtPath<VolumeProfile>(path);
            if(profile==null){profile=ScriptableObject.CreateInstance<VolumeProfile>();AssetDatabase.CreateAsset(profile,path);}
            T Effect<T>() where T:VolumeComponent {if(profile.TryGet<T>(out var found))return found;var component=profile.Add<T>();AssetDatabase.AddObjectToAsset(component,profile);return component;}
            var chromatic=Effect<ChromaticAberration>();chromatic.intensity.Override(.05f);
            var distortion=Effect<LensDistortion>();distortion.intensity.Override(-.05f);
            var grain=Effect<FilmGrain>();grain.type.Override(FilmGrainLookup.Thin1);grain.intensity.Override(.15f);
            foreach(var component in profile.components)EditorUtility.SetDirty(component);EditorUtility.SetDirty(profile);AssetDatabase.SaveAssets();
            return "Three active profile components author URP build retention; no DOF, Panini or full stripping override.";
        }
    }
}
