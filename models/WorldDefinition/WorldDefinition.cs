using Newtonsoft.Json;

namespace PT.Models.WorldDefinition;

public partial class WorldDefinition : SlimWorldDefinition
{
    [JsonProperty("map", Required = Required.Always)]
    public required MapDefinition MapDefinition { get; init; }

    [JsonProperty("network", Required = Required.Always)]
    public required NetworkDefinition NetworkDefinition { get; init; }

    public new Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["name"] = Name,
            ["description"] = Description,
            ["createdAt"] = CreatedAt,
            ["builtIn"] = BuiltIn,
            ["map"] = MapDefinition.Serialize(),
            ["network"] = NetworkDefinition.Serialize(),
        };
        return dict;
    }
}
