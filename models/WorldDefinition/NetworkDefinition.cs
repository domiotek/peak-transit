using System.Collections.Generic;
using System.Linq;
using Godot.Collections;
using Newtonsoft.Json;
using PT.Models.WorldDefinition.Network;

namespace PT.Models.WorldDefinition;

public class NetworkDefinition
{
    [JsonProperty("nodes", Required = Required.Always)]
    public required List<NetNodeInfo> Nodes { get; init; }

    [JsonProperty("segments", Required = Required.Always)]
    public required List<NetSegmentInfo> Segments { get; init; }

    public Dictionary Serialize()
    {
        return new Dictionary
        {
            ["nodes"] = new Array<Dictionary>(Nodes.ConvertAll(n => n.Serialize())),
            ["segments"] = new Array<Dictionary>(Segments.ConvertAll(s => s.Serialize())),
        };
    }

    public static NetworkDefinition Deserialize(Dictionary data)
    {
        return new NetworkDefinition
        {
            Nodes =
            [
                .. data["nodes"]
                    .AsGodotArray<Dictionary>()
                    .ToArray()
                    .Select(nodeData => NetNodeInfo.Deserialize(nodeData ?? [])),
            ],
            Segments =
            [
                .. data["segments"]
                    .AsGodotArray<Dictionary>()
                    .ToArray()
                    .Select(segmentData => NetSegmentInfo.Deserialize(segmentData ?? [])),
            ],
        };
    }
}
