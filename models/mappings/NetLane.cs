using Godot;
using PTS.Models.Network;

namespace PTS.Models.Mappings;

public partial class NetLane : Node2D, IMapping<NetLane>
{
    public int Id { get; set; }

    public NetLaneInfo LaneInfo { get; set; }

    public static NetLane Map(GodotObject gdObject)
    {
        return new NetLane
        {
            LaneInfo = gdObject.Get("data").As<NetLaneInfo>(),
            Id = gdObject.Get("id").AsInt32(),
        };
    }
}
