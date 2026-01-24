using System.Collections.Generic;
using System.Linq;
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

    public static NetSegmentInfo Deserialize(Godot.Collections.Dictionary data)
    {
        return new NetSegmentInfo
        {
            Nodes = data.TryGetValue("nodes", out var nodes) ? [.. nodes.AsGodotArray<int>()] : [],
            CurveStrength = data.TryGetValue("bendStrength", out var bendStrength)
                ? (float)bendStrength
                : 0f,
            CurveDirection = data.TryGetValue("bendDir", out var bendDir)
                ? (CurveDirection)(int)bendDir
                : CurveDirection.Clockwise,
            Relations = data.TryGetValue("relations", out var relations)
                ?
                [
                    .. relations
                        .AsGodotArray<Godot.Collections.Dictionary>()
                        .ToArray()
                        .Select(relationData => NetRelationInfo.Deserialize(relationData ?? [])),
                ]
                : [],
            MaxSpeed = data.TryGetValue("maxSpeed", out var maxSpeed) ? (float)maxSpeed : -1f,
        };
    }
}
