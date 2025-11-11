using System.Collections.Generic;
using Godot;
using Godot.Collections;

namespace PT.Models.Network;

public enum EndpointType
{
    Incoming,
    Outgoing,
}

public class NetLaneEndpoint
{
    public int Id { get; set; } = -1;
    public Vector2 Position { get; set; }

    public int SegmentId { get; set; }

    public int NodeId { get; set; }

    public EndpointType Type { get; set; }

    public bool IsAtPathStart { get; set; } = false;

    public int LaneId { get; set; } = -1;

    public int LaneNumber { get; set; } = -1;

    public List<int> Connections { get; } = [];

    public bool IsOutgoing()
    {
        return Type == EndpointType.Outgoing;
    }

    public Dictionary Serialize()
    {
        var dict = new Dictionary
        {
            ["Id"] = Id,
            ["Position"] = Position,
            ["SegmentId"] = SegmentId,
            ["NodeId"] = NodeId,
            ["Type"] = (int)Type,
            ["IsAtPathStart"] = IsAtPathStart,
            ["LaneId"] = LaneId,
            ["LaneNumber"] = LaneNumber,
            ["Connections"] = Connections.ToArray(),
        };
        return dict;
    }

    public static NetLaneEndpoint Deserialize(Dictionary dict)
    {
        var endpoint = new NetLaneEndpoint
        {
            Id = (int)dict["Id"],
            Position = (Vector2)dict["Position"],
            SegmentId = (int)dict["SegmentId"],
            NodeId = (int)dict["NodeId"],
            Type = (bool)dict["IsOutgoing"] ? EndpointType.Outgoing : EndpointType.Incoming,
            IsAtPathStart = (bool)dict["IsAtPathStart"],
            LaneId = (int)dict["LaneId"],
            LaneNumber = (int)dict["LaneNumber"],
        };

        var connectionsArray = dict["Connections"].AsInt64Array();
        foreach (var conn in connectionsArray)
        {
            endpoint.Connections.Add((int)conn);
        }

        return endpoint;
    }
}
