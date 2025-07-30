using System.Collections.Generic;

namespace PTS.Models;

public class GraphNode
{
    public int Id { get; set; }

    public Dictionary<int, NodesRelation> ConnectedNodes { get; } = [];

    public GraphNode(Mappings.NetworkNode node)
    {
        Id = node.Id;
    }
}
