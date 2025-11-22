using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class SegmentPosDefinition : IDefinition<SegmentPosDefinition>
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

    public static SegmentPosDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        var segmentPosDefinition = new SegmentPosDefinition
        {
            Segment = data["segment"].AsInt32Array()?.ToList() ?? [],
            Offset = data["offset"].As<float>(),
        };
        return segmentPosDefinition;
    }
}
