using System;
using Godot;
using Godot.Collections;
using PTS.Models;

namespace PTS.Managers;

[GlobalClass]
public partial class PathFinder : Node
{
    private NetGraph Graph { get; set; } = new NetGraph();

    public void BuildGraph(Array<GodotObject> nodes, Dictionary<int, NetLaneEndpoint> endpoints)
    {
        foreach (var nodeObject in nodes)
        {
            var netNode = Models.Mappings.NetworkNode.Map(nodeObject);

            Graph.AddNode(netNode);
        }
    }
}
