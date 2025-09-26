using Godot;
using Godot.Collections;
using PTS.Models.Network;

namespace PTS.Models.Mappings;

public partial class NetLane : Node2D, IMapping<NetLane>
{
    private GodotObject _sourceObject;

    public int Id { get; set; }

    public NetLaneInfo LaneInfo { get; set; }

    public float GetMaxAllowedSpeed()
    {
        return _sourceObject.Call("get_max_allowed_speed").As<float>();
    }

    public Dictionary GetLaneUsage()
    {
        return _sourceObject.Call("get_vehicles_stats").As<Dictionary>();
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
