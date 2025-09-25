using System;
using System.Collections.Generic;
using System.Linq;
using PTS.DependencyProvider;
using PTS.Models.Mappings;
using PTS.Models.Network;
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

    private static readonly Dictionary<int, NetSegment> _segmentCache = new();

    public static void ClearCache()
    {
        foreach (var segment in _segmentCache.Values)
        {
            segment?.QueueFree();
        }
        _segmentCache.Clear();
    }

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

        var explorationSet = new PriorityQueue<AStarNode, float>();
        var bestCostToState = new Dictionary<string, double>();
        var visitedNodes = new HashSet<int>();
        var bestSolutionNodes = new HashSet<int>();
        AStarNode bestSolution = null;

        var startNode = new AStarNode(startNodeId)
        {
            GraphNode = startGraphNode,
            GCost = 0,
            HCost = CalculateHeuristic(startGraphNode, endGraphNode),
        };

        explorationSet.Enqueue(startNode, startNode.FCost);

        while (explorationSet.Count > 0)
        {
            var currentNode = explorationSet.Dequeue();
            string currentStateKey = $"{currentNode.NodeId}_{currentNode.FromEndpointId}";
            if (
                currentNode.GCost
                > bestCostToState.GetValueOrDefault(currentStateKey, double.MaxValue)
            )
            {
                continue;
            }

            bestCostToState[currentStateKey] = currentNode.GCost;

            if (currentNode.NodeId == endNodeId)
            {
                if (bestSolution == null || currentNode.GCost < bestSolution.GCost)
                {
                    bestSolution = currentNode;
                    bestSolutionNodes = GetNodesInPath(bestSolution);
                }
                continue;
            }

            if (
                bestSolution != null
                && visitedNodes.Contains(currentNode.NodeId)
                && !bestSolutionNodes.Contains(currentNode.NodeId)
            )
            {
                continue;
            }

            visitedNodes.Add(currentNode.NodeId);

            if (
                bestSolution != null
                && !bestSolutionNodes.Contains(currentNode.NodeId)
                && currentNode.FCost >= bestSolution.GCost
            )
            {
                continue;
            }

            var graphNode = graph.GetNode(currentNode.NodeId);
            if (graphNode == null)
                continue;

            var neighborNodes = ExploreNeighborNodes(graph, currentNode, endGraphNode);

            foreach (var neighbor in neighborNodes)
            {
                explorationSet.Enqueue(neighbor, neighbor.FCost);
            }
        }

        if (bestSolution != null)
        {
            return ReconstructPath(bestSolution);
        }

        throw new InvalidOperationException(
            $"No path found from node {startNodeId} to node {endNodeId}"
        );
    }

    private static List<AStarNode> ExploreNeighborNodes(
        NetGraph graph,
        AStarNode currentNode,
        GraphNode endNode
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

                var fromEndpoint = currentNode.GraphNode.OutgoingToIncomingEndpointsMapping[
                    viaPoint
                ];

                var explorationNode = new AStarNode(neighborId)
                {
                    Parent = currentNode.Clone(),
                    GraphNode = neighborGraphNode,
                    GCost = tentativeGCost,
                    HCost = CalculateHeuristic(neighborGraphNode, endNode, fromEndpoint),
                    FromEndpointId = fromEndpoint,
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

    private static HashSet<int> GetNodesInPath(AStarNode solution)
    {
        var nodesInPath = new HashSet<int>();
        var current = solution;
        while (current != null)
        {
            nodesInPath.Add(current.NodeId);
            current = current.Parent;
        }
        return nodesInPath;
    }

    private static float CalculateHeuristic(
        GraphNode fromNode,
        GraphNode toNode,
        int? viaEndpointId = null
    )
    {
        var endpoint = fromNode.Endpoints.Find(e => e.Id == viaEndpointId);

        if (endpoint != null)
        {
            return endpoint.Position.DistanceTo(toNode.Position);
        }
        else
        {
            return fromNode.Position.DistanceTo(toNode.Position);
        }
    }

    private static float CalculateCurrentCost(AStarNode node)
    {
        var cost = 1f;

        if (node.FromEndpointId != null && node.ToEndpointId != null)
        {
            var fromEndpoint = NetworkManager.GetLaneEndpoint((int)node.FromEndpointId);
            var toEndpoint = NetworkManager.GetLaneEndpoint((int)node.ToEndpointId);

            var switchingCost = ApplyLaneSwitchingCost(fromEndpoint, toEndpoint);
            var speedBonus = ApplySpeedLimitBonus(toEndpoint);

            cost += switchingCost;
            cost += speedBonus;
        }

        return cost;
    }

    private static float ApplyLaneSwitchingCost(
        NetLaneEndpoint fromEndpoint,
        NetLaneEndpoint toEndpoint
    )
    {
        var laneDifference = Math.Abs(fromEndpoint.LaneNumber - toEndpoint.LaneNumber);

        return laneDifference * 0.5f;
    }

    private static float ApplySpeedLimitBonus(NetLaneEndpoint fromEndpoint)
    {
        if (!_segmentCache.TryGetValue(fromEndpoint.SegmentId, out var targetSegment))
        {
            targetSegment = NetworkManager.GetSegment(fromEndpoint.SegmentId);
            _segmentCache[fromEndpoint.SegmentId] = targetSegment;
        }

        var targetLane = targetSegment.Lanes.FirstOrDefault(lane => lane.Id == fromEndpoint.LaneId);

        var speedLimit = targetLane.GetMaxAllowedSpeed();

        const float maxExpectedSpeed = 150f;
        const float defaultMaxSpeed = 120f;
        const float penaltyMultiplier = 2.0f;

        if (float.IsInfinity(speedLimit) || speedLimit > maxExpectedSpeed)
        {
            speedLimit = defaultMaxSpeed;
        }

        var penalty = (1.0f - (speedLimit / maxExpectedSpeed)) * penaltyMultiplier;
        return penalty;
    }
}
