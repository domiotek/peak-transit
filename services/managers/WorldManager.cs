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

    public Dictionary GetEmptyWorldDefinition()
    {
        return new WorldDefinition
        {
            Name = "New World",
            Description = "A newly created, empty world.",
            CreatedAt = DateTime.UtcNow.ToString(),
            MapDefinition = new MapDefinition()
            {
                MapSize = new System.Numerics.Vector2(5000, 5000),
            },
            NetworkDefinition = new NetworkDefinition() { Nodes = [], Segments = [] },
            TransportDefinition = new TransportDefinition()
            {
                Stops = [],
                Lines = [],
                Terminals = [],
                DemandPresets = [],
                Depots = [],
            },
        }.Serialize();
    }

    public string GetDefaultWorldFilePath()
    {
        return Path.Combine(builtInWorldDirectory, defaultWorldFileName);
    }

    public (WorldDefinition parsedDef, string parsingError) LoadWorldDefinition(string filePath)
    {
        if (!FSHelper.EnsureFileExists(filePath))
            return (null, "File does not exist");

        var isBuiltIn = filePath.StartsWith(
            builtInWorldDirectory,
            StringComparison.OrdinalIgnoreCase
        );

        var fileContents = FileAccess.Open(filePath, FileAccess.ModeFlags.Read).GetAsText();

        try
        {
            var definition = Newtonsoft.Json.JsonConvert.DeserializeObject<WorldDefinition>(
                fileContents
            );
            definition.FilePath = filePath;
            definition.BuiltIn = isBuiltIn;

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

    public Dictionary SaveWorldDefinition(
        Dictionary worldDefinition,
        string fileName,
        bool allowOverwrite = false
    )
    {
        if (string.IsNullOrWhiteSpace(fileName))
        {
            return new Dictionary
            {
                ["success"] = false,
                ["errorCode"] = "EMPTY_FILE_NAME",
                ["savingError"] = "File name cannot be empty.",
            };
        }

        var filePath = Path.Combine(worldDirectory, fileName);

        if (!allowOverwrite && FSHelper.EnsureFileExists(filePath))
        {
            return new Dictionary
            {
                ["success"] = false,
                ["errorCode"] = "FILE_ALREADY_EXISTS",
                ["savingError"] = "A world file with the same name already exists.",
            };
        }

        WorldDefinition definition;
        try
        {
            definition = WorldDefinition.Deserialize(worldDefinition);
        }
        catch (Exception ex)
        {
            return new Dictionary
            {
                ["success"] = false,
                ["errorCode"] = "DESERIALIZATION_ERROR",
                ["savingError"] = $"Failed to deserialize world definition: {ex.Message}",
            };
        }

        var serializedDef = Newtonsoft.Json.JsonConvert.SerializeObject(
            definition,
            Newtonsoft.Json.Formatting.None
        );

        try
        {
            using var file = FileAccess.Open(filePath, FileAccess.ModeFlags.Write);
            if (file == null)
            {
                throw new Exception("Could not open file for writing.");
            }
            file.StoreString(serializedDef);
            file.Close();

            return new Dictionary { ["success"] = true, ["filePath"] = filePath };
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Failed to save world definition to {filePath}: {ex.Message}");
            return new Dictionary
            {
                ["success"] = false,
                ["errorCode"] = "SAVE_ERROR",
                ["savingError"] = ex.Message,
            };
        }
    }

    public string SanitizeWorldFileName(string fileName)
    {
        return FSHelper.SanitizeFileName(fileName);
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
