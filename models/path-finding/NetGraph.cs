using System;
using System.Collections.Generic;
using System.Linq;

namespace PT.Models.PathFinding;

public partial class NetGraph : IDisposable
{
    private Dictionary<int, GraphNode> Nodes { get; } = [];

    public void AddNode(Mappings.NetworkNode networkNode)
    {
        var node = new GraphNode(networkNode);

        foreach (var segment in networkNode.ConnectedSegments)
        {
            var otherNode = segment.Nodes.Where(n => n != networkNode.Id);
            if (!otherNode.Any())
            {
                continue;
            }

            var route = new GraphRoute
            {
                Via = [.. networkNode.OutgoingEndpoints.Where(segment.Endpoints.Contains)],
            };

            node.ConnectedNodes[otherNode.First()] = route;

            foreach (var mapping in segment.EndpointToEndpointMapping)
            {
                if (!networkNode.OutgoingEndpoints.Contains(mapping.Key))
                    continue;
                node.OutgoingToIncomingEndpointsMapping[mapping.Key] = mapping.Value;
            }
        }

        Nodes[networkNode.Id] = node;
    }

    public GraphNode GetNode(int nodeId)
    {
        return Nodes.TryGetValue(nodeId, out var node) ? node : null;
    }

    public bool ContainsNode(int nodeId)
    {
        return Nodes.ContainsKey(nodeId);
    }

    public IEnumerable<GraphNode> GetAllNodes()
    {
        return Nodes.Values;
    }

    public void Dispose()
    {
        foreach (var node in Nodes.Values)
        {
            node.Dispose();
        }

        Nodes.Clear();
        GC.SuppressFinalize(this);
    }
}
