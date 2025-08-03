using Godot;

namespace PTS.Models.PathFinding;

public partial class PathStep : GodotObject
{
    public int FromNodeId { get; }

    public int ToNodeId { get; }

    public int ViaEndpointId { get; }

    public PathStep(int fromNodeId, int toNodeId, int viaEndpointId)
    {
        FromNodeId = fromNodeId;
        ToNodeId = toNodeId;
        ViaEndpointId = viaEndpointId;
    }
}
