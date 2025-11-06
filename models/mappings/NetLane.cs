using Godot;
using PT.Models.WorldDefinition.Network;

namespace PT.Models.Mappings;

public partial class NetLane : IMapping<NetLane>
{
    private GodotObject _sourceObject;

    public int Id { get; set; }

    public NetLaneInfo LaneInfo { get; set; }

    public float GetMaxAllowedSpeed()
    {
        return _sourceObject.Call("get_max_allowed_speed").As<float>();
    }

    public float GetLaneUsage()
    {
        return _sourceObject.Call("get_lane_usage").As<float>();
    }

    public static NetLane Map(GodotObject gdObject)
    {
        return new NetLane
        {
            _sourceObject = gdObject,
            LaneInfo = NetLaneInfo.Deserialize(
                gdObject
                    .Get("data")
                    .AsGodotObject()
                    .Call("serialize")
                    .As<Godot.Collections.Dictionary>()
            ),
            Id = gdObject.Get("id").AsInt32(),
        };
    }
}
