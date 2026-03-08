using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class StopDefinition : IDefinition<StopDefinition>
{
    [JsonProperty("id")]
    public int Id { get; set; } = -1;

    [JsonProperty("name")]
    public required string Name { get; set; } = string.Empty;

    [JsonProperty("pos", Required = Required.Always)]
    public required SegmentPosDefinition Position { get; set; }

    [JsonProperty("demandPreset", Required = Required.Always)]
    public required int DemandPresetIndex { get; set; }

    [JsonProperty("drawStripes")]
    public required bool DrawStripes { get; set; } = true;

    [JsonProperty("canWait")]
    public required bool CanWait { get; set; } = true;

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["id"] = Id,
            ["name"] = Name,
            ["pos"] = Position.Serialize(),
            ["demandPreset"] = DemandPresetIndex,
            ["drawStripes"] = DrawStripes,
            ["canWait"] = CanWait,
        };
        return dict;
    }

    public static StopDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        var stopDefinition = new StopDefinition
        {
            Id = data.ContainsKey("id") ? data["id"].AsInt32() : -1,
            Name = data["name"].AsString() ?? string.Empty,
            Position = SegmentPosDefinition.Deserialize(data["pos"].AsGodotDictionary() ?? []),
            DemandPresetIndex = data["demandPreset"].AsInt32(),
            DrawStripes = data["drawStripes"].AsBool(),
            CanWait = data["canWait"].AsBool(),
        };
        return stopDefinition;
    }
}
