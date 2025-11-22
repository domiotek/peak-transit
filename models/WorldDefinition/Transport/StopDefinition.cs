using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class StopDefinition : IDefinition<StopDefinition>
{
    [JsonProperty("name")]
    public required string Name { get; set; } = string.Empty;

    [JsonProperty("pos", Required = Required.Always)]
    public required SegmentPosDefinition Position { get; set; }

    [JsonProperty("demandPreset")]
    public required int DemandPreset { get; set; } = -1;

    [JsonProperty("drawStripes")]
    public required bool DrawStripes { get; set; } = true;

    [JsonProperty("canWait")]
    public required bool CanWait { get; set; } = true;

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["name"] = Name,
            ["pos"] = Position.Serialize(),
            ["demandPreset"] = DemandPreset,
            ["drawStripes"] = DrawStripes,
            ["canWait"] = CanWait,
        };
        return dict;
    }

    public static StopDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        var stopDefinition = new StopDefinition
        {
            Name = data["name"].AsString() ?? string.Empty,
            Position = SegmentPosDefinition.Deserialize(data["pos"].AsGodotDictionary() ?? []),
            DemandPreset = data["demandPreset"].AsInt32(),
            DrawStripes = data["drawStripes"].AsBool(),
            CanWait = data["canWait"].AsBool(),
        };
        return stopDefinition;
    }
}
