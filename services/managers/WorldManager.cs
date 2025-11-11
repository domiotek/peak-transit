using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Godot.Collections;
using PT.DependencyProvider;
using PT.Helpers;
using PT.Models.WorldDefinition;
using Path = System.IO.Path;

namespace PT.Services.Managers.Config;

[GlobalClass]
public partial class WorldManager : RefCounted
{
    private string builtInWorldDirectory;
    private string worldDirectory;
    private string defaultWorldFileName;

    public WorldManager()
    {
        var configManager = DIContainer.Inject<ConfigManager>("ConfigManager");

        builtInWorldDirectory = configManager.BuiltInWorldDirectory;
        worldDirectory = configManager.WorldDirectory;
        defaultWorldFileName = configManager.DefaultWorldFileName;
    }

    public Array<Dictionary> GetAvailableWorlds()
    {
        var worlds = new List<SlimWorldDefinition>();

        CollectWorldsFromPath(builtInWorldDirectory, worlds);
        _ = worlds.Select(w => w.BuiltIn = true).ToList();

        CollectWorldsFromPath(worldDirectory, worlds);

        return [.. worlds.Select(w => w.Serialize())];
    }

    public void OpenWorldsFolder()
    {
        if (!FSHelper.EnsureDirectoryExists(worldDirectory))
            return;

        var path = FSHelper.ResolveUserPath(worldDirectory);

        OS.ShellShowInFileManager(path);
    }

    public string GetDefaultWorldFilePath()
    {
        return Path.Combine(builtInWorldDirectory, defaultWorldFileName);
    }

    public (WorldDefinition parsedDef, string parsingError) LoadWorldDefinition(string filePath)
    {
        if (!FSHelper.EnsureFileExists(filePath))
            return (null, "File does not exist");

        var fileContents = FileAccess.Open(filePath, FileAccess.ModeFlags.Read).GetAsText();

        try
        {
            var definition = Newtonsoft.Json.JsonConvert.DeserializeObject<WorldDefinition>(
                fileContents
            );
            definition.FilePath = filePath;

            return (definition, null);
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Failed to load world definition from {filePath}: {ex.Message}");
            return (null, ex.Message);
        }
    }

    public Dictionary LoadSerializedWorldDefinition(string filePath)
    {
        var (definition, parsingError) = LoadWorldDefinition(filePath);
        return new Dictionary
        {
            ["definition"] = definition?.Serialize(),
            ["parsingError"] = parsingError,
        };
    }

    private static void CollectWorldsFromPath(string basePath, List<SlimWorldDefinition> worlds)
    {
        if (string.IsNullOrWhiteSpace(basePath) || !FSHelper.EnsureDirectoryExists(basePath))
        {
            return;
        }

        var filesInDirectory = DirAccess.GetFilesAt(basePath);
        foreach (var fileName in filesInDirectory)
        {
            if (!fileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var filePath = basePath.EndsWith('/') ? basePath + fileName : basePath + "/" + fileName;
            var fileContents = FileAccess.Open(filePath, FileAccess.ModeFlags.Read).GetAsText();
            var slimWorldDef = Newtonsoft.Json.JsonConvert.DeserializeObject<SlimWorldDefinition>(
                fileContents
            );

            if (slimWorldDef == null)
                continue;

            slimWorldDef.FilePath = filePath;

            worlds.Add(slimWorldDef);
        }
    }
}
