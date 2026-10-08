using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

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
            Material Material(string name,string shader)
            {
                string path="Assets/Game/Resources/Eternal/Materials/"+name+".mat";
                var material=AssetDatabase.LoadAssetAtPath<Material>(path);
                if(material==null){material=new Material(Shader.Find(shader)??throw new InvalidOperationException("Shader missing: "+shader));AssetDatabase.CreateAsset(material,path);}
                return material;
            }
            Material("OriginalPaint","Eternal/OriginalPaint");Material("Particles","Eternal/EffectParticles");
            var stone=Material("Stone","Eternal/WeatheredStone");stone.shader=Shader.Find("Eternal/WeatheredStone");
            stone.SetTexture("_BaseMap",Resources.Load<Texture2D>("Eternal/Floor/stone_1024_albedo_ao"));stone.SetTexture("_MicroNormal",Resources.Load<Texture2D>("Eternal/Floor/stone_1024_micro_normal"));EditorUtility.SetDirty(stone);
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            new GameObject("Native hunting integration review").AddComponent<HuntingMigrationReview>();
            EditorSceneManager.SaveScene(SceneManager.GetActiveScene(),"Assets/Scenes/HuntingReview.unity");AssetDatabase.SaveAssets();
            return "Assets/Scenes/HuntingReview.unity";
        }
    }
}
