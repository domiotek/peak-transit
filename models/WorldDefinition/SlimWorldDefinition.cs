using System.Collections.Generic;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition;

public class SlimWorldDefinition
{
    [JsonProperty("name")]
    public required string Name { get; set; }

    [JsonIgnore]
    public string FilePath { get; set; } = string.Empty;

    [JsonProperty("description")]
    public required string Description { get; set; }

    [JsonProperty("createdAt")]
    public required string CreatedAt { get; set; }

    [JsonIgnore]
    public bool BuiltIn { get; set; } = false;

    public Godot.Collections.Dictionary Serialize()
    {
        return new Godot.Collections.Dictionary
        {
            ["name"] = Name,
            ["filePath"] = FilePath,
            ["description"] = Description,
            ["createdAt"] = CreatedAt,
            ["builtIn"] = BuiltIn,
        };
    }
}
