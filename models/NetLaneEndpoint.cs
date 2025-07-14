using Godot;
using Godot.Collections;

namespace PTS.Models;

public enum EndpointType
{
    Incoming,
    Outgoing,
}

[GlobalClass]
public partial class NetLaneEndpoint : Node
{
    public int Id { get; set; } = -1;
    public Vector2 Position { get; set; }

    public int SegmentId { get; set; }

    public int NodeId { get; set; }

    public EndpointType Type { get; set; }
    public int LaneId { get; set; } = -1;

    public int LaneNumber { get; set; } = -1;

    public Array<int> Connections { get; } = [];

    public void SetIsOutgoing(bool state)
    {
        Type = state ? EndpointType.Outgoing : EndpointType.Incoming;
    }

    public bool IsOutgoing()
    {
        return Type == EndpointType.Outgoing;
    }

    public void AddConnection(int otherEndpointId)
    {
        if (!Connections.Contains(otherEndpointId))
        {
            Connections.Add(otherEndpointId);
        }
    }
}
