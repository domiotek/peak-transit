using Godot;

namespace PTS.Models.Network;

[GlobalClass]
public partial class NetLaneInfo : GodotObject
{
    public int MaxSpeed { get; set; } = 0;

    public LaneDirection Direction { get; set; } = LaneDirection.Auto;
}
