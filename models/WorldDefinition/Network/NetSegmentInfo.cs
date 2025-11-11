using System.Collections.Generic;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Network;

public enum CurveDirection
{
    Clockwise = 1,
    CounterClockwise = -1,
}

public class NetSegmentInfo
{
    [JsonProperty("nodes", Required = Required.Always)]
    public required List<int> Nodes { get; init; } = [];

    [JsonProperty("bendStrength")]
    public float CurveStrength { get; init; } = 0f;

    [JsonProperty("bendDir", Required = Required.Always)]
    public required CurveDirection CurveDirection { get; init; }

    [JsonProperty("relations", Required = Required.Always)]
    public required List<NetRelationInfo> Relations { get; init; }

    [JsonProperty("maxSpeed")]
    public float MaxSpeed { get; init; } = -1f;

    public Godot.Collections.Dictionary Serialize()
    {
        return new Godot.Collections.Dictionary
        {
            ["nodes"] = new Godot.Collections.Array<int>(Nodes),
            ["bendStrength"] = CurveStrength,
            ["bendDir"] = (int)CurveDirection,
            ["relations"] = new Godot.Collections.Array<Godot.Collections.Dictionary>(
                Relations.ConvertAll(relation => relation.Serialize())
            ),
            ["maxSpeed"] = MaxSpeed,
        };
    }
}
