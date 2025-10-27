using System;
using Godot;
using Godot.Collections;

namespace PT.Models.PathFinding;

public partial class PathingRequest : RefCounted
{
    public Guid RequestId { get; } = Guid.NewGuid();
    public int StartNodeId { get; set; }
    public int EndNodeId { get; set; }

    public int ForcedStartEndpointId { get; set; } = -1;
    public int ForcedEndEndpointId { get; set; } = -1;

    public PathingRequest(
        int startNodeId,
        int endNodeId,
        int forcedStartEndpointId = -1,
        int forcedEndEndpointId = -1
    )
    {
        StartNodeId = startNodeId;
        EndNodeId = endNodeId;
        ForcedStartEndpointId = forcedStartEndpointId;
        ForcedEndEndpointId = forcedEndEndpointId;
    }

    public PathingResponse CompleteRequest(
        PathingState state,
        Array<PathStep> resultPath,
        float totalCost = 0.0f
    )
    {
        return PathingResponse.CompleteRequest(this, state, resultPath, totalCost);
    }
}
