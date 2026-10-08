using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Eternal.UnityMigration.Editor
{
    public static class HuntingReviewInstaller
    {
        [MenuItem("Eternal/Create native hunting review")]
        public static string Create()
        {
            if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play mode before creating the review.");
            if(SceneManager.GetActiveScene().isDirty)throw new InvalidOperationException("Save the current scene first.");
            Directory.CreateDirectory("Assets/Game/Resources/Eternal/Materials");AssetDatabase.Refresh();
            PaintedImpactInstaller.Apply();
            Material Material(string name,string shader)
            {
                string path="Assets/Game/Resources/Eternal/Materials/"+name+".mat";
                var material=AssetDatabase.LoadAssetAtPath<Material>(path);
                if(material==null){material=new Material(Shader.Find(shader)??throw new InvalidOperationException("Shader missing: "+shader));AssetDatabase.CreateAsset(material,path);}
                return material;
            }
            Material("OriginalPaint","Eternal/OriginalPaint");Material("Particles","Eternal/EffectParticles");
            Material("PaintedArena","Eternal/PaintedArena");
            Material("ReliefPaint","Eternal/OriginalRelief");
            var stone=Material("Stone","Eternal/WeatheredStone");stone.shader=Shader.Find("Eternal/WeatheredStone");
            stone.SetVector("_TileSize",new Vector4(3.05f,3.6f,0,0));
            stone.SetTexture("_BaseMap",Resources.Load<Texture2D>("Eternal/Floor/stone_1024_albedo_ao"));stone.SetTexture("_MicroNormal",Resources.Load<Texture2D>("Eternal/Floor/stone_1024_micro_normal"));EditorUtility.SetDirty(stone);
            string profilePath="Assets/Game/Resources/Eternal/Materials/BattlePost.asset";
            var profile=AssetDatabase.LoadAssetAtPath<VolumeProfile>(profilePath);
            if(profile==null){profile=ScriptableObject.CreateInstance<VolumeProfile>();AssetDatabase.CreateAsset(profile,profilePath);}
            T Component<T>() where T:VolumeComponent
            {if(profile.TryGet<T>(out var found))return found;var component=profile.Add<T>();AssetDatabase.AddObjectToAsset(component,profile);return component;}
            var bloom=Component<Bloom>();bloom.intensity.Override(.6f);bloom.threshold.Override(1.1f);bloom.scatter.Override(.65f);bloom.highQualityFiltering.Override(false);
            var vignette=Component<Vignette>();vignette.intensity.Override(.24f);vignette.smoothness.Override(.75f);vignette.rounded.Override(false);
            EditorUtility.SetDirty(bloom);EditorUtility.SetDirty(vignette);EditorUtility.SetDirty(profile);
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            new GameObject("Native hunting integration review").AddComponent<HuntingMigrationReview>();
            EditorSceneManager.SaveScene(SceneManager.GetActiveScene(),"Assets/Scenes/HuntingReview.unity");AssetDatabase.SaveAssets();
            return "Assets/Scenes/HuntingReview.unity";
        }
    }
}
