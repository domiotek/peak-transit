using Godot;
using Godot.Collections;

namespace PTS.Models.Network;

[GlobalClass]
public partial class NetConnectionInfo : Node
{
    public int StartNodeId { get; private set; }

    public Array<NetLaneInfo> Lanes { get; set; } = [];

    public NetConnectionInfo(int startNodeId)
    {
        StartNodeId = startNodeId;
    }
}
