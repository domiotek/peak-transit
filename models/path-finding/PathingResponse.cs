using System.Collections.Generic;
using Godot;
using Godot.Collections;

namespace PT.Models.PathFinding;

public partial class PathingResponse : PathingRequest
{
    private PathingResponse()
        : base(0, 0, VehicleCategory.Private) { }

    public PathingState State { get; internal set; } = PathingState.Pending;

    public List<PathStep> Path { get; internal set; } = [];

    public float TotalCost { get; internal set; } = 0.0f;

    public Dictionary Serialize()
    {
        var dict = new Dictionary
        {
            ["StartNodeId"] = StartNodeId,
            ["EndNodeId"] = EndNodeId,
            ["ForcedStartEndpointId"] = ForcedStartEndpointId,
            ["ForcedEndEndpointId"] = ForcedEndEndpointId,
            ["State"] = (int)State,
            ["TotalCost"] = TotalCost,
            ["Path"] = new Array<Dictionary>(),
        };

        foreach (var step in Path)
        {
            var stepDict = new Dictionary
            {
                ["FromNodeId"] = step.FromNodeId,
                ["ToNodeId"] = step.ToNodeId,
                ["ViaEndpointId"] = step.ViaEndpointId,
            };
            dict["Path"].As<Array<Dictionary>>().Add(stepDict);
        }

        return dict;
    }

    public static PathingResponse CompleteRequest(
        PathingRequest request,
        PathingState state,
        List<PathStep> resultPath,
        float totalCost = 0.0f
    )
    {
        var response = new PathingResponse
        {
            StartNodeId = request.StartNodeId,
            EndNodeId = request.EndNodeId,
            State = state,
            TotalCost = totalCost,
            ForcedStartEndpointId = request.ForcedStartEndpointId,
            ForcedEndEndpointId = request.ForcedEndEndpointId,
            Path = resultPath,
        };

        return response;
    }
}
