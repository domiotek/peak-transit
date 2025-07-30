using System.Collections.Generic;
using System.Linq;
using Godot;

namespace PTS.Models.Mappings;

public partial class NetworkNode : Node2D, IMapping<NetworkNode>
{
    public int Id { get; set; }

    public List<int> IncomingEndpoints { get; set; }

    public List<int> OutgoingEndpoints { get; set; }

    public List<NetSegment> ConnectedSegments { get; set; } = [];

    private NetworkNode() { }

    public static NetworkNode Map(GodotObject nodeObject)
    {
        var newNode = new NetworkNode
        {
            Id = nodeObject.Get("id").AsInt32(),
            IncomingEndpoints = nodeObject.Get("incoming_endpoints").AsInt32Array().ToList() ?? [],
            OutgoingEndpoints = nodeObject.Get("outgoing_endpoints").AsInt32Array().ToList() ?? [],
            ConnectedSegments =
            [
                .. nodeObject
                    .Get("connected_segments")
                    .AsGodotObjectArray<GodotObject>()
                    .ToList()
                    .Select(NetSegment.Map),
            ],
        };

        return newNode;
    }
}
