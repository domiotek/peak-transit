using Godot.Collections;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class DepotDefinition : IDefinition<DepotDefinition>
{
    [JsonProperty("id")]
    public int Id { get; set; } = -1;

    [JsonProperty("name")]
    public required string Name { get; set; } = string.Empty;

    [JsonProperty("busIdPrefix")]
    public required string BusIdPrefix { get; set; } = string.Empty;

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
            ["id"] = Id,
            ["name"] = Name,
            ["pos"] = Position.Serialize(),
            ["busCount"] = RegularBusCapacity,
            ["articulatedBusCount"] = ArticulatedBusCapacity,
            ["busIdPrefix"] = BusIdPrefix,
        };
        return dict;
    }

    public static DepotDefinition Deserialize(Dictionary data)
    {
        var depotDefinition = new DepotDefinition
        {
            Id = data.ContainsKey("id") ? data["id"].AsInt32() : -1,
            Name = data["name"].AsString() ?? string.Empty,
            BusIdPrefix = data["busIdPrefix"].AsString() ?? string.Empty,
            Position = SegmentPosDefinition.Deserialize(data["pos"].AsGodotDictionary() ?? []),
            RegularBusCapacity = data["busCount"].AsInt32(),
            ArticulatedBusCapacity = data["articulatedBusCount"].AsInt32(),
        };
        return depotDefinition;
    }
}
