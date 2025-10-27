using Godot;

namespace PT.Models.Network;

[GlobalClass]
public partial class NetLaneInfo : RefCounted
{
    public float MaxSpeed { get; set; } = -1f;

    public LaneDirection Direction { get; set; } = LaneDirection.Auto;
}
