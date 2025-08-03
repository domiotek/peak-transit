using System;
using Godot;
using Godot.Collections;

namespace PTS.Models.PathFinding;

public partial class PathingRequest : GodotObject
{
    public Guid RequestId { get; } = Guid.NewGuid();
    public int StartNodeId { get; set; }
    public int EndNodeId { get; set; }

    public PathingRequest(int startNodeId, int endNodeId)
    {
        StartNodeId = startNodeId;
        EndNodeId = endNodeId;
    }

    public PathingResponse CompleteRequest(PathingState state, Array<PathStep> resultPath)
    {
        return PathingResponse.CompleteRequest(this, state, resultPath);
    }
}
