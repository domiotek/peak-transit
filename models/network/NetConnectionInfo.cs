using Godot;
using Godot.Collections;

namespace PT.Models.Network;

[GlobalClass]
public partial class NetConnectionInfo : GodotObject
{
    public int StartNodeId { get; private set; }

    public Array<NetLaneInfo> Lanes { get; set; } = [];

    public NetConnectionInfo(int startNodeId)
    {
        StartNodeId = startNodeId;
    }
}
