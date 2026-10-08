using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class OriginalAssetImporter
    {
        const string Destination = "Assets/OriginalImported/Resources/Eternal";
        [Serializable] sealed class ImportRecord { public string source, destination, sha256; }
        [Serializable] sealed class ImportReport { public int heroCount, skillCount, actorCount; public ImportRecord[] files; }

        // Deliberately explicit: importing never touches the old player's saved game.
        [MenuItem("Eternal/Import original assets")]
        public static string Import()
        {
            string repo = Directory.GetParent(Application.dataPath).Parent.FullName;
            if (!File.Exists(Path.Combine(repo, "AGENTS.md"))) throw new InvalidOperationException("Open Unity/ inside the original repository.");
            var records = new List<ImportRecord>();
            void Copy(string source, string target)
            {
                string from = Path.Combine(repo, source), to = Path.Combine(Application.dataPath, "..", target);
                if (!File.Exists(from)) throw new FileNotFoundException("Original asset missing", from);
                Directory.CreateDirectory(Path.GetDirectoryName(to));
                byte[] bytes = File.ReadAllBytes(from);
                if (!File.Exists(to) || !File.ReadAllBytes(to).SequenceEqual(bytes)) File.WriteAllBytes(to, bytes);
                using var sha = SHA256.Create();
                records.Add(new ImportRecord { source = source, destination = target, sha256 = BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant() });
            }
            Copy("docs/hero-catalog-2026-10-08/hero-catalog.json", Destination + "/hero-catalog.json");
            Copy("assets/mobile25d/catalog.json", Destination + "/actor-catalog.json");
            var actors = JsonUtility.FromJson<ActorCatalog>(File.ReadAllText(Path.Combine(repo, "assets/mobile25d/catalog.json")));
            foreach (var actor in actors.entries)
            {
                Copy("assets/mobile25d/" + actor.id + "/poses_1024.png", Destination + "/Actors/" + actor.id + "/poses.png");
                Copy("assets/mobile25d/" + actor.id + "/frames.json", Destination + "/Actors/" + actor.id + "/frames.json");
                // Retain source relief meshes for the next verified glTF/Unity mesh migration step.
                Copy("assets/mobile25d/" + actor.id + "/billboard.glb", Destination + "/Actors/" + actor.id + "/billboard.glb.bytes");
            }
            foreach (string file in Directory.GetFiles(Path.Combine(repo, "assets/mobile25d/floor"), "*_1024_*.png"))
                Copy("assets/mobile25d/floor/" + Path.GetFileName(file), Destination + "/Floor/" + Path.GetFileName(file));
            foreach (string file in Directory.GetFiles(Path.Combine(repo, "audio/ultra-skills"), "*.wav"))
                Copy("audio/ultra-skills/" + Path.GetFileName(file), Destination + "/Audio/Skills/" + Path.GetFileName(file));
            foreach (string file in Directory.GetFiles(Path.Combine(repo, "audio/v82")))
                if (file.EndsWith(".wav") || file.EndsWith(".ogg")) Copy("audio/v82/" + Path.GetFileName(file), Destination + "/Audio/" + Path.GetFileName(file));
            Copy("assets/fonts/combat/outfit/Outfit-ExtraBold.ttf", Destination + "/Fonts/Outfit-ExtraBold.ttf");
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            foreach (var actor in actors.entries)
            {
                var importer = (TextureImporter)AssetImporter.GetAtPath(Destination + "/Actors/" + actor.id + "/poses.png");
                importer.textureType = TextureImporterType.Default;
                importer.sRGBTexture = true;
                importer.alphaSource = TextureImporterAlphaSource.FromInput;
                importer.alphaIsTransparency = true;
                importer.mipmapEnabled = true;
                importer.wrapMode = TextureWrapMode.Clamp;
                importer.filterMode = FilterMode.Bilinear;
                importer.maxTextureSize = 1024;
                ActorTextureBudget.Configure(importer);
                importer.SaveAndReimport();
            }
            foreach (string path in AssetDatabase.FindAssets("t:Texture2D", new[] { Destination + "/Floor" }).Select(AssetDatabase.GUIDToAssetPath))
            {
                var importer = (TextureImporter)AssetImporter.GetAtPath(path);
                importer.wrapMode = TextureWrapMode.Repeat;
                if (path.Contains("normal")) { importer.textureType = TextureImporterType.NormalMap; importer.sRGBTexture = false; }
                importer.SaveAndReimport();
            }
            var heroes = OriginalCatalog.Heroes;
            if (heroes.hero_count != 30 || heroes.heroes.Length != 30 || heroes.heroes.Sum(h => h.skills.Length) != 120) throw new InvalidDataException("Original roster changed; review the migration instead of truncating it.");
            var report = new ImportReport { heroCount = heroes.hero_count, skillCount = heroes.skill_count, actorCount = actors.entries.Length, files = records.ToArray() };
            Directory.CreateDirectory("../checks/unity-migration-2026-10-08");
            string json = JsonUtility.ToJson(report, true);
            File.WriteAllText("../checks/unity-migration-2026-10-08/original-import.json", json);
            Debug.Log("ETERNAL_ORIGINAL_IMPORT_OK: " + actors.entries.Length + " actors, 30 heroes, 120 skills, " + records.Count + " identical source files.");
            return json;
        }

        [MenuItem("Eternal/Create asset verification scene")]
        public static string CreateVerificationScene()
        {
            if (EditorApplication.isPlaying) throw new InvalidOperationException("Stop Play mode before replacing the verification scene.");
            if (SceneNeedsSave()) throw new InvalidOperationException("Save the current scene before creating the verification scene.");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            new GameObject("Original asset verification").AddComponent<OriginalAssetVerification>();
            Directory.CreateDirectory("Assets/Scenes");
            EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene(), "Assets/Scenes/OriginalAssets.unity");
            return "Assets/Scenes/OriginalAssets.unity";
        }
        static bool SceneNeedsSave() => UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty;
    }
}
