using Godot;
using PT.Models.Network;

namespace PT.Models.Mappings;

public partial class NetLane : RefCounted, IMapping<NetLane>
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
            LaneInfo = gdObject.Get("data").As<NetLaneInfo>(),
            Id = gdObject.Get("id").AsInt32(),
        };
    }
}
