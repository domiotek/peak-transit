using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class StopDefinition : IDefinition<StopDefinition>
{
    [JsonProperty("name")]
    public required string Name { get; set; } = string.Empty;

    [JsonProperty("pos", Required = Required.Always)]
    public required StopPosDefinition Position { get; set; }

    [JsonProperty("demandPreset")]
    public required int DemandPreset { get; set; } = -1;

    [JsonProperty("shelter")]
    public required bool HasShelter { get; set; } = false;

    [JsonProperty("canWait")]
    public required bool CanWait { get; set; } = true;

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["name"] = Name,
            ["pos"] = Position.Serialize(),
            ["demandPreset"] = DemandPreset,
            ["shelter"] = HasShelter,
            ["canWait"] = CanWait,
        };
        return dict;
    }

    public static StopDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        var stopDefinition = new StopDefinition
        {
            Name = data["name"].AsString() ?? string.Empty,
            Position = StopPosDefinition.Deserialize(data["pos"].AsGodotDictionary() ?? []),
            DemandPreset = data["demandPreset"].AsInt32(),
            HasShelter = data["shelter"].AsBool(),
            CanWait = data["canWait"].AsBool(),
        };
        return stopDefinition;
    }
}

public class StopPosDefinition : IDefinition<StopPosDefinition>
{
    [JsonProperty("segment", Required = Required.Always)]
    public required List<int> Segment { get; set; }

    [JsonProperty("offset", Required = Required.Always)]
    public required float Offset { get; set; }

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["segment"] = Segment.ToArray(),
            ["offset"] = Offset,
        };
        return dict;
    }

    public static StopPosDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        var stopPosDefinition = new StopPosDefinition
        {
            Segment = data["segment"].AsInt32Array()?.ToList() ?? [],
            Offset = data["offset"].As<float>(),
        };
        return stopPosDefinition;
    }
}
