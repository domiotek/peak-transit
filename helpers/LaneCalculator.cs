using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Godot.Collections;
using PTS.Models;

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
            var laneConnections = new List<int>();

            if (i == sortedIncoming.Length - 1 && rightEndpoints.Any())
                laneConnections.AddRange([rightEndpoints.MaxBy(x => x.LaneNumber).Id]);

            if (i == 0 && leftEndpoints.Any())
                laneConnections.AddRange([leftEndpoints.MinBy(x => x.LaneNumber).Id]);

            if (
                (laneConnections.Count == 0 || !hasSufficientIncomingLanes)
                && forwardEndpoints.Any()
            )
                laneConnections.AddRange(
                    forwardEndpoints
                        .Where(x => Math.Abs(x.LaneNumber - lane.LaneNumber) < 2)
                        .Select(x => x.Id)
                );

            connections[lane.Id] = [.. laneConnections];
        }

        return connections;
    }
}
