using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public enum RouteStepType
{
    Terminal,
    Stop,
    Waypoint,
}

public class RouteStepDefinition : IDefinition<RouteStepDefinition>
{
    [JsonProperty("type", Required = Required.Always)]
    public required RouteStepType StepType { get; set; }

    [JsonProperty("targetId", Required = Required.Always)]
    public required int TargetId { get; set; }

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["type"] = (int)StepType,
            ["targetId"] = TargetId,
        };
        return dict;
    }

    public static RouteStepDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        var routeStepDefinition = new RouteStepDefinition
        {
            StepType = (RouteStepType)data["type"].AsInt32(),
            TargetId = data["targetId"].AsInt32(),
        };
        return routeStepDefinition;
    }
}
