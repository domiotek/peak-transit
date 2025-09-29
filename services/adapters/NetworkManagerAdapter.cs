using System.Collections.Generic;
using Godot;
using PT.Models.Mappings;
using PT.Models.Network;

namespace PT.Services.Adapters;

public class NetworkManagerAdapter(GodotObject managerGdObject)
{
    private readonly GodotObject _managerGdObject = managerGdObject;

    public NetLaneEndpoint GetLaneEndpoint(int id)
    {
        return (NetLaneEndpoint)_managerGdObject.Call("get_lane_endpoint", id);
    }

    public List<NetLaneEndpoint> GetNodeLaneEndpoints(int nodeId)
    {
        return
        [
            .. _managerGdObject
                .Call("get_node_endpoints", nodeId)
                .AsGodotObjectArray<NetLaneEndpoint>(),
        ];
    }

    public NetSegment GetSegment(int segmentId)
    {
        return NetSegment.Map(_managerGdObject.Call("get_segment", segmentId).AsGodotObject());
    }
}
