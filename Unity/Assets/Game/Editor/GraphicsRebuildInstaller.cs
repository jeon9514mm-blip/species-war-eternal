using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Eternal.UnityMigration.Editor
{
    public static class GraphicsRebuildInstaller
    {
        [MenuItem("Eternal/Graphics rebuild/Create royal grove development stage")]
        public static void Create()
        {
            if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty)throw new InvalidOperationException("Stop Play and save the active scene before creating the development stage.");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            new GameObject("Royal grove graphics development").AddComponent<RoyalGroveDevelopmentStage>();
            EditorSceneManager.SaveScene(SceneManager.GetActiveScene(),"Assets/Scenes/RoyalGroveDevelopment.unity");AssetDatabase.SaveAssets();
            // This unfinished scene is intentionally not an APK build entry.
        }
    }
}
