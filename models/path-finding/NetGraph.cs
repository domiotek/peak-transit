using System.Collections.Generic;
using System.Linq;

namespace PTS.Models;

public partial class NetGraph
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

            var nodesRelation = new NodesRelation
            {
                AvailableEndpoints =
                [
                    .. networkNode.OutgoingEndpoints.Where(segment.Endpoints.Contains),
                ],
            };

            node.ConnectedNodes[otherNode.First()] = nodesRelation;
        }

        Nodes[networkNode.Id] = node;
    }
}
