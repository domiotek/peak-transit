using Godot;

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

    public NetNode(int id, Vector2 position)
    {
        Id = id;
        Position = position;
    }
}
