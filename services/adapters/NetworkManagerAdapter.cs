using System.Linq;
using Godot;
using Godot.Collections;
using PT.Models.Mappings;
using PT.Models.Network;

namespace PT.Services.Adapters;

public class NetworkManagerAdapter(GodotObject managerGdObject)
{
    private readonly GodotObject _managerGdObject = managerGdObject;

    public NetLaneEndpoint GetLaneEndpoint(int id)
    {
        return NetLaneEndpoint.Deserialize(
            _managerGdObject.Call("get_lane_endpoint", id).As<Dictionary>()
        );
    }

    public GodotObjectCollection<NetLaneEndpoint> GetNodeLaneEndpoints(int nodeId)
    {
        return new GodotObjectCollection<NetLaneEndpoint>(
            [
                .. _managerGdObject
                    .Call("get_node_endpoints", nodeId)
                    .AsGodotArray<Dictionary>()
                    .Select(NetLaneEndpoint.Deserialize),
            ]
        );
    }

    public NetSegment GetSegment(int segmentId)
    {
        return NetSegment.Map(_managerGdObject.Call("get_segment", segmentId).AsGodotObject());
    }
}
