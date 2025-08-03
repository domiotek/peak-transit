using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using PTS.DependencyProvider;
using PTS.Models;
using PTS.Models.PathFinding;
using PTS.Services.Adapters;

namespace PTS.Helpers;

class AStarNode(int nodeId)
{
    public int NodeId { get; set; } = nodeId;
    public string NodeRouteKey { get; set; }
    public float GCost { get; set; } = float.MaxValue;
    public float HCost { get; set; } = 0;
    public float FCost => GCost + HCost;
    public AStarNode Parent { get; set; } = null;

    public Models.PathFinding.GraphNode GraphNode { get; set; } = null;

    public int? FromEndpointId { get; set; } = null;
    public int? ToEndpointId { get; set; } = null;

    public AStarNode Clone()
    {
        return MemberwiseClone() as AStarNode;
    }
}

public class AStarPathing
{
    public static NetworkManagerAdapter NetworkManager = CSInjector.Inject<NetworkManagerAdapter>(
        "NetworkManager"
    );

    public static List<PathStep> FindPathAStar(NetGraph graph, int startNodeId, int endNodeId)
    {
        if (!graph.ContainsNode(startNodeId) || !graph.ContainsNode(endNodeId))
        {
            throw new ArgumentException("Start or end node not found in graph");
        }

        if (startNodeId == endNodeId)
        {
            return [];
        }
        var startGraphNode = graph.GetNode(startNodeId);
        var endGraphNode = graph.GetNode(endNodeId);

        var explorationSet = new List<AStarNode>();
        var allNodes = new Dictionary<int, AStarNode>();

        var startNode = new AStarNode(startNodeId)
        {
            GraphNode = startGraphNode,
            GCost = 0,
            HCost = CalculateHeuristic(startGraphNode, endGraphNode),
        };

        allNodes[startNodeId] = startNode;
        explorationSet.Add(startNode);

        while (explorationSet.Count > 0)
        {
            var currentNode = explorationSet.OrderBy(n => n.FCost).ThenBy(n => n.HCost).First();
            explorationSet.Remove(currentNode);

            if (currentNode.NodeId == endNodeId)
            {
                return ReconstructPath(currentNode);
            }

            var graphNode = graph.GetNode(currentNode.NodeId);
            if (graphNode == null)
                continue;

            var neighborNodes = ExploreNeighborNodes(graph, currentNode, endGraphNode);

            explorationSet.AddRange(neighborNodes);
        }

        throw new InvalidOperationException(
            $"No path found from node {startNodeId} to node {endNodeId}"
        );
    }

    private static List<AStarNode> ExploreNeighborNodes(
        NetGraph graph,
        AStarNode currentNode,
        Models.PathFinding.GraphNode endNode
    )
    {
        var result = new List<AStarNode>();

        foreach (var connection in currentNode.GraphNode.ConnectedNodes)
        {
            int neighborId = connection.Key;
            var neighborGraphNode = graph.GetNode(neighborId);
            var route = connection.Value;

            var availableEndpoints =
                currentNode.FromEndpointId != null
                    ? currentNode.GraphNode.EndpointConnections[(int)currentNode.FromEndpointId]
                    : null;

            var filteredViaPoints = route
                .Via.Where(via => availableEndpoints == null || availableEndpoints.Contains(via))
                .ToList();

            foreach (var viaPoint in filteredViaPoints)
            {
                currentNode.NodeRouteKey = $"{currentNode.NodeId}_{neighborId}_{viaPoint}";

                currentNode.ToEndpointId = viaPoint;

                float tentativeGCost = currentNode.GCost + CalculateCurrentCost(currentNode);

                var explorationNode = new AStarNode(neighborId)
                {
                    Parent = currentNode.Clone(),
                    GraphNode = neighborGraphNode,
                    GCost = tentativeGCost,
                    HCost = CalculateHeuristic(neighborGraphNode, endNode),
                    FromEndpointId = currentNode.GraphNode.OutgoingToIncomingEndpointsMapping[
                        viaPoint
                    ],
                };

                result.Add(explorationNode);
            }
        }

        return result;
    }

    private static List<PathStep> ReconstructPath(AStarNode goalNode)
    {
        var path = new List<PathStep>();
        var current = goalNode;

        while (current.Parent != null)
        {
            var step = new PathStep(
                current.Parent.NodeId,
                current.NodeId,
                current.Parent.ToEndpointId ?? -1
            );
            path.Insert(0, step);
            current = current.Parent;
        }

        return path;
    }

    private static float CalculateHeuristic(
        Models.PathFinding.GraphNode fromNode,
        Models.PathFinding.GraphNode toNode
    )
    {
        return fromNode.Position.DistanceTo(toNode.Position);
    }

    private static float CalculateCurrentCost(AStarNode node)
    {
        var cost = 1f;

        if (node.FromEndpointId != null && node.ToEndpointId != null)
        {
            cost += ApplyLaneSwitchingCost((int)node.FromEndpointId, (int)node.ToEndpointId);
        }

        return cost;
    }

    private static float ApplyLaneSwitchingCost(int fromEndpointId, int toEndpointId)
    {
        var fromEndpoint = NetworkManager.GetLaneEndpoint(fromEndpointId);
        var toEndpoint = NetworkManager.GetLaneEndpoint(toEndpointId);

        var laneDifference = Math.Abs(fromEndpoint.LaneNumber - toEndpoint.LaneNumber);

        return laneDifference * 0.5f;
    }
}
