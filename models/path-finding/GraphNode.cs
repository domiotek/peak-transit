using System.Collections.Generic;
using Godot;
using PT.Models.Network;

namespace PT.Models.PathFinding;

public class GraphNode(Mappings.NetworkNode node)
{
    public int Id { get; set; } = node.Id;

    public Vector2 Position { get; set; } = node.Position;

    public Dictionary<int, GraphRoute> ConnectedNodes { get; } = [];

    public Dictionary<int, List<int>> EndpointConnections { get; } = node.EndpointConnections;

    public List<NetLaneEndpoint> Endpoints { get; } = node.Endpoints;

    public Dictionary<int, int> OutgoingToIncomingEndpointsMapping { get; } = [];
}
