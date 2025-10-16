using Godot.Collections;

namespace PT.Models.PathFinding;

public partial class PathingResponse : PathingRequest
{
    private PathingResponse()
        : base(0, 0) { }

    public PathingState State { get; internal set; } = PathingState.Pending;

    public Array<PathStep> Path { get; internal set; } = [];

    public float TotalCost { get; internal set; } = 0.0f;

    public static PathingResponse CompleteRequest(
        PathingRequest request,
        PathingState state,
        Array<PathStep> resultPath,
        float totalCost = 0.0f
    )
    {
        var response = new PathingResponse
        {
            StartNodeId = request.StartNodeId,
            EndNodeId = request.EndNodeId,
            State = state,
            Path = resultPath,
            TotalCost = totalCost,
            ForcedStartEndpointId = request.ForcedStartEndpointId,
            ForcedEndEndpointId = request.ForcedEndEndpointId,
        };

        return response;
    }
}
