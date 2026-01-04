using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class TerminalDefinition : IDefinition<TerminalDefinition>
{
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
            Name = data["name"].AsString() ?? string.Empty,
            Position = SegmentPosDefinition.Deserialize(data["pos"].AsGodotDictionary() ?? []),
            DemandPresetIndex = data["demandPreset"].As<int>(),
        };
        return terminalDefinition;
    }
}
