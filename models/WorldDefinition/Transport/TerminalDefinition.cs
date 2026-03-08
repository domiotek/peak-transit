using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class TerminalDefinition : IDefinition<TerminalDefinition>
{
    [JsonProperty("id")]
    public int Id { get; set; } = -1;

    [JsonProperty("name")]
    public required string Name { get; set; } = string.Empty;

    [JsonProperty("pos", Required = Required.Always)]
    public required SegmentPosDefinition Position { get; set; }

    [JsonProperty("demandPreset", Required = Required.Always)]
    public required int DemandPresetIndex { get; set; }

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["id"] = Id,
            ["name"] = Name,
            ["pos"] = Position.Serialize(),
            ["demandPreset"] = DemandPresetIndex,
        };
        return dict;
    }

    public static TerminalDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        var terminalDefinition = new TerminalDefinition
        {
            Id = data.ContainsKey("id") ? data["id"].AsInt32() : -1,
            Name = data["name"].AsString() ?? string.Empty,
            Position = SegmentPosDefinition.Deserialize(data["pos"].AsGodotDictionary() ?? []),
            DemandPresetIndex = data["demandPreset"].As<int>(),
        };
        return terminalDefinition;
    }
}
