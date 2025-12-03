using Godot.Collections;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class DepotDefinition : IDefinition<DepotDefinition>
{
    [JsonProperty("name")]
    public required string Name { get; set; } = string.Empty;

    [JsonProperty("pos", Required = Required.Always)]
    public required SegmentPosDefinition Position { get; set; }

    [JsonProperty("busCount")]
    public required int RegularBusCapacity { get; set; } = 6;

    [JsonProperty("articulatedBusCount")]
    public required int ArticulatedBusCapacity { get; set; } = 4;

    public Dictionary Serialize()
    {
        var dict = new Dictionary
        {
            ["name"] = Name,
            ["pos"] = Position.Serialize(),
            ["busCount"] = RegularBusCapacity,
            ["articulatedBusCount"] = ArticulatedBusCapacity,
        };
        return dict;
    }

    public static DepotDefinition Deserialize(Dictionary data)
    {
        var depotDefinition = new DepotDefinition
        {
            Name = data["name"].AsString() ?? string.Empty,
            Position = SegmentPosDefinition.Deserialize(data["pos"].AsGodotDictionary() ?? []),
            RegularBusCapacity = data["busCount"].AsInt32(),
            ArticulatedBusCapacity = data["articulatedBusCount"].AsInt32(),
        };
        return depotDefinition;
    }
}
