using System.Collections.Generic;
using System.Linq;
using Godot;
using Godot.Collections;
using PTS.DependencyProvider;
using PTS.Services.Adapters;

namespace PTS.Models.Mappings;

public partial class NetworkNode : Node2D, IMapping<NetworkNode>
{
    public int Id { get; set; }

    public new Vector2 Position { get; set; }

    public List<int> IncomingEndpoints { get; set; }

    public List<int> OutgoingEndpoints { get; set; }

    public List<NetSegment> ConnectedSegments { get; set; } = [];

    public System.Collections.Generic.Dictionary<int, List<int>> EndpointConnections { get; set; } =
        [];
    public List<NetLaneEndpoint> Endpoints { get; private set; } = [];

    private NetworkNode() { }

    public static NetworkNode Map(GodotObject nodeObject)
    {
        var id = nodeObject.Get("id").AsInt32();
        var networkManager = CSInjector.Inject<NetworkManagerAdapter>("NetworkManager");

        var newNode = new NetworkNode
        {
            Id = id,
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
            EndpointConnections = nodeObject
                .Get("connections")
                .AsGodotDictionary<int, Array<int>>()
                .ToDictionary(kvp => kvp.Key, kvp => kvp.Value.ToList()),

            Position = nodeObject.Get("global_position").AsVector2(),
            Endpoints = networkManager.GetNodeLaneEndpoints(id),
        };

        return newNode;
    }
}
