using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Godot.Collections;
using PTS.DependencyProvider;
using PTS.Models.Network;
using PTS.Services.Adapters;

namespace PTS.Managers;

[GlobalClass]
public partial class LaneCalculator : GodotObject
{
    public Godot.Collections.Dictionary<int, Array<int>> CalculateLaneConnections(
        Array<NetLaneEndpoint> incomingEndpoints,
        Array<NetLaneEndpoint> leftEndpoints,
        Array<NetLaneEndpoint> forwardEndpoints,
        Array<NetLaneEndpoint> rightEndpoints
    )
    {
        if (incomingEndpoints.Count == 0)
            return [];

        var netManager = CSInjector.Inject<NetworkManagerAdapter>("NetworkManager");

        var lanes = netManager.GetSegment(incomingEndpoints[0].SegmentId).Lanes;

        var connections = new Godot.Collections.Dictionary<int, Array<int>>();

        var sortedIncoming = incomingEndpoints.OrderBy(e => e.LaneNumber).ToArray();

        var directionsCount = new[]
        {
            leftEndpoints.Count,
            forwardEndpoints.Count,
            rightEndpoints.Count,
        }.Count(count => count > 0);

        var hasSufficientIncomingLanes = sortedIncoming.Length >= directionsCount;

        for (int i = 0; i < sortedIncoming.Length; i++)
        {
            var lane = sortedIncoming[i];
            var laneInfo = lanes.Where(l => l.Id == lane.LaneId).FirstOrDefault()?.LaneInfo;
            List<int> laneConnections;

            if (laneInfo.Direction != LaneDirection.Auto)
            {
                laneConnections = SetForcedLaneConnections(
                    laneInfo.Direction,
                    lane,
                    forwardEndpoints,
                    leftEndpoints,
                    rightEndpoints
                );
            }
            else
            {
                laneConnections = CalculateLaneConnections(
                    i,
                    sortedIncoming.Length,
                    lane,
                    laneInfo,
                    leftEndpoints,
                    rightEndpoints,
                    forwardEndpoints,
                    hasSufficientIncomingLanes
                );
            }

            connections[lane.Id] = [.. laneConnections];
        }

        return connections;
    }

    private List<int> SetForcedLaneConnections(
        LaneDirection direction,
        NetLaneEndpoint laneEndpoint,
        Array<NetLaneEndpoint> forwardEndpoints,
        Array<NetLaneEndpoint> leftEndpoints,
        Array<NetLaneEndpoint> rightEndpoints,
        int n = 2
    )
    {
        var connections = new List<int>();

        if (
            direction == LaneDirection.Forward
            || direction == LaneDirection.All
            || direction == LaneDirection.ForwardLeft
            || direction == LaneDirection.ForwardRight
        )
            connections.AddRange(MapToNTargetEndpoints(forwardEndpoints, laneEndpoint, n));

        if (direction == LaneDirection.Left || direction == LaneDirection.ForwardLeft)
        {
            connections.AddRange(MapToNTargetEndpoints(leftEndpoints, laneEndpoint, n));
        }

        if (direction == LaneDirection.Right || direction == LaneDirection.ForwardRight)
        {
            connections.AddRange(MapToNTargetEndpoints(rightEndpoints, laneEndpoint, n));
        }

        if (direction == LaneDirection.Backward)
        {
            // Not supported yet
        }

        return connections;
    }

    private List<int> MapToNTargetEndpoints(
        Array<NetLaneEndpoint> targetEndpoints,
        NetLaneEndpoint laneEndpoint,
        int n = 2
    )
    {
        if (targetEndpoints.Count != 0)
            return
            [
                .. targetEndpoints
                    .Where(x => Math.Abs(x.LaneNumber - laneEndpoint.LaneNumber) < n)
                    .Select(x => x.Id),
            ];

        return [];
    }

    private List<int> CalculateLaneConnections(
        int laneIndex,
        int lanesCount,
        NetLaneEndpoint laneEndpoint,
        NetLaneInfo laneInfo,
        Array<NetLaneEndpoint> leftEndpoints,
        Array<NetLaneEndpoint> rightEndpoints,
        Array<NetLaneEndpoint> forwardEndpoints,
        bool hasSufficientIncomingLanes
    )
    {
        var connections = new List<int>();

        if (laneIndex == lanesCount - 1 && rightEndpoints.Count != 0)
            connections.Add(rightEndpoints.MaxBy(x => x.LaneNumber).Id);

        if (laneIndex == 0 && leftEndpoints.Count != 0)
            connections.Add(leftEndpoints.MinBy(x => x.LaneNumber).Id);

        if ((connections.Count == 0 || !hasSufficientIncomingLanes) && forwardEndpoints.Count != 0)
            connections.AddRange(
                forwardEndpoints
                    .Where(x => Math.Abs(x.LaneNumber - laneEndpoint.LaneNumber) < 2)
                    .Select(x => x.Id)
            );

        return connections;
    }
}
