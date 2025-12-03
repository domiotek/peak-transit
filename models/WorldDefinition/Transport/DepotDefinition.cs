using Godot.Collections;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class DepotDefinition : IDefinition<DepotDefinition>
{
    [JsonProperty("name")]
    public required string Name { get; set; } = string.Empty;

    [JsonProperty("pos", Required = Required.Always)]
    public required SegmentPosDefinition Position { get; set; }

    public Dictionary Serialize()
    {
        var dict = new Dictionary { ["name"] = Name, ["pos"] = Position.Serialize() };
        return dict;
    }

    public static DepotDefinition Deserialize(Dictionary data)
    {
        var depotDefinition = new DepotDefinition
        {
            Name = data["name"].AsString() ?? string.Empty,
            Position = SegmentPosDefinition.Deserialize(data["pos"].AsGodotDictionary() ?? []),
        };
        return depotDefinition;
    }
}
