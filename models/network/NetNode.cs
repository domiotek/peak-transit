using System;
using Godot;
using Godot.Collections;

namespace PTS.Models.Network;

public enum IntersectionType
{
    Default,
    TrafficLights,
}

[GlobalClass]
public partial class NetNode : GodotObject
{
    public int Id { get; set; } = -1;
    public Vector2 Position { get; set; } = Vector2.Zero;

    public IntersectionType IntersectionType { get; set; } = IntersectionType.Default;

    public Array<int> PrioritySegments { get; set; } = [];

    public Array<int> StopSegments { get; set; } = [];

    public NetNode(int id, Vector2 position)
    {
        Id = id;
        Position = position;
    }
}
