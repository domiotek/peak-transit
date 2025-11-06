using System.Collections.Generic;
using Godot.Collections;
using Newtonsoft.Json;
using PT.Models.WorldDefinition.Network;

namespace PT.Models.WorldDefinition;

public class NetworkDefinition
{
    [JsonProperty("nodes")]
    public required List<NetNodeInfo> Nodes { get; init; }

    [JsonProperty("segments")]
    public required List<NetSegmentInfo> Segments { get; init; }

    public Dictionary Serialize()
    {
        return new Dictionary
        {
            ["nodes"] = new Array<Dictionary>(Nodes.ConvertAll(n => n.Serialize())),
            ["segments"] = new Array<Dictionary>(Segments.ConvertAll(s => s.Serialize())),
        };
    }
}
