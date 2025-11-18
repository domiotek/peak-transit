using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using PT.DependencyProvider;
using PT.Models.Mappings;
using PT.Models.Network;
using PT.Models.PathFinding;
using PT.Services.Adapters;

namespace PT.Helpers;

class AStarNode(int nodeId)
{
    public int NodeId { get; set; } = nodeId;
    public string NodeRouteKey { get; set; }
    public float GCost { get; set; } = float.MaxValue;
    public float HCost { get; set; } = 0;
    public float FCost => GCost + HCost;
    public AStarNode Parent { get; set; } = null;
    public int Depth { get; set; } = 0;

    public GraphNode GraphNode { get; set; } = null;

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

    private static readonly ConcurrentDictionary<int, NetSegment> _segmentCache = new();

    public static void ClearCache()
    {
        _segmentCache.Clear();
    }

    public static (List<PathStep> path, float totalCost) FindPathAStar(
        NetGraph graph,
        int startNodeId,
        int endNodeId,
        VehicleCategory vehicleType,
        int? forcedStartEndpointId,
        int? forcedEndEndpointId,
        CancellationToken cancellationToken = default
    )
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (!graph.ContainsNode(startNodeId) || !graph.ContainsNode(endNodeId))
        {
            throw new ArgumentException("Start or end node not found in graph");
        }

        if (startNodeId == endNodeId)
        {
            return (new List<PathStep>(), 0.0f);
        }

        var startGraphNode = graph.GetNode(startNodeId);
        var endGraphNode = graph.GetNode(endNodeId);

        if (
            forcedStartEndpointId != null
            && !startGraphNode.OutgoingToIncomingEndpointsMapping.ContainsKey(
                (int)forcedStartEndpointId
            )
        )
        {
            throw new ArgumentException("Forced start endpoint not found in start graph node");
        }

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
            cancellationToken.ThrowIfCancellationRequested();

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
                if (
                    forcedEndEndpointId == null
                    || currentNode.FromEndpointId == forcedEndEndpointId
                )
                {
                    if (bestSolution == null || currentNode.GCost < bestSolution.GCost)
                    {
                        bestSolution = currentNode;
                        bestSolutionNodes = GetNodesInPath(bestSolution);
                    }
                    else
                    {
                        continue;
                    }
                }
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

            var neighborNodes = ExploreNeighborNodes(
                graph,
                currentNode,
                endGraphNode,
                vehicleType,
                forcedStartEndpointId
            );

            forcedStartEndpointId = null;

            foreach (var neighbor in neighborNodes)
            {
                explorationSet.Enqueue(neighbor, neighbor.FCost);
            }
        }

        if (bestSolution != null)
        {
            return (ReconstructPath(bestSolution), bestSolution.GCost);
        }

        throw new InvalidOperationException(
            $"No path found from node {startNodeId} to node {endNodeId}"
        );
    }

    private static List<AStarNode> ExploreNeighborNodes(
        NetGraph graph,
        AStarNode currentNode,
        GraphNode endNode,
        VehicleCategory vehicleType,
        int? forcedEndpoint
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
                .Where(via => forcedEndpoint == null || via == forcedEndpoint)
                .Where(via =>
                {
                    if (currentNode.FromEndpointId == null)
                        return true;

                    var sourceEndpoint = currentNode.GraphNode.Endpoints.FirstOrDefault(e =>
                        e.Id == currentNode.FromEndpointId
                    );

                    if (sourceEndpoint == null)
                        return false;

                    var allowedVehicles = sourceEndpoint.ConnectionsExt.ContainsKey(via)
                        ? sourceEndpoint.ConnectionsExt[via].AllowedVehicles
                        : new List<VehicleCategory>();

                    return allowedVehicles.Count == 0 || allowedVehicles.Contains(vehicleType);
                })
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
                    Depth = currentNode.Depth + 1,
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

            var segment = GetSegment(fromEndpoint.SegmentId);
            var lane = segment.Lanes.FirstOrDefault(l => l.Id == fromEndpoint.LaneId);

            var switchingCost = ApplyLaneSwitchingCost(fromEndpoint, toEndpoint);
            var speedBonus = ApplySpeedLimitBonus(lane);
            var usageCost = ApplyLaneUsageCost(lane, node.Depth);

            cost += switchingCost;
            cost += speedBonus;
            cost += usageCost;
        }

        return cost;
    }

    private static NetSegment GetSegment(int segmentId)
    {
        if (!_segmentCache.TryGetValue(segmentId, out var targetSegment))
        {
            targetSegment = NetworkManager.GetSegment(segmentId);
            _segmentCache[segmentId] = targetSegment;
        }
        return targetSegment;
    }

    private static float ApplyLaneSwitchingCost(
        NetLaneEndpoint fromEndpoint,
        NetLaneEndpoint toEndpoint
    )
    {
        var laneDifference = Math.Abs(fromEndpoint.LaneNumber - toEndpoint.LaneNumber);

        return laneDifference * 0.5f;
    }

    private static float ApplySpeedLimitBonus(NetLane lane)
    {
        var speedLimit = lane.GetMaxAllowedSpeed();

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

    private static float ApplyLaneUsageCost(NetLane lane, int depth)
    {
        var usage = lane.GetLaneUsage();

        const float maxUsage = 1.0f;
        const float usagePenaltyMultiplier = 4.0f;
        const float depthPenaltyMultiplier = 0.1f;
        const float usageDepthDecayFactor = 0.1f;

        if (usage < 0 || usage > maxUsage)
        {
            usage = 0;
        }

        var depthReduction = Math.Min(depth * usageDepthDecayFactor, 0.8f);
        var adjustedUsagePenalty = usage * usagePenaltyMultiplier * (1.0f - depthReduction);

        var depthPenalty = depth * depthPenaltyMultiplier;

        return adjustedUsagePenalty + depthPenalty;
    }
}
