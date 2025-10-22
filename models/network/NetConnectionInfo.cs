using Godot;
using Godot.Collections;
using PT.Models.Buildings;

namespace PT.Models.Network;

[GlobalClass]
public partial class NetConnectionInfo : GodotObject
{
    public int StartNodeId { get; private set; }

    public Array<NetLaneInfo> Lanes { get; set; } = [];

    public Array<BuildingInfo> Buildings { get; set; } = [];

    public NetConnectionInfo(int startNodeId)
    {
        StartNodeId = startNodeId;
    }
}
