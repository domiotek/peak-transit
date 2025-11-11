using System.Collections.Generic;
using System.Linq;
using Godot;

namespace PT.Models.Mappings;

public partial class NetSegment : IMapping<NetSegment>
{
    public int Id { get; set; }

    public List<int> Nodes { get; set; } = [];

    public List<int> Endpoints { get; set; } = [];

    public List<NetLane> Lanes { get; set; } = [];

    public Dictionary<int, int> EndpointToEndpointMapping { get; set; } = [];

    private NetSegment() { }

    public static NetSegment Map(GodotObject segmentObject)
    {
        var newSegment = new NetSegment
        {
            Id = segmentObject.Get("id").AsInt32(),
            Nodes =
                segmentObject
                    .Get("nodes")
                    .AsGodotObjectArray<GodotObject>()
                    .ToList()
                    .Select(n => n.Get("id").AsInt32())
                    .ToList() ?? [],
            Endpoints = segmentObject.Get("endpoints").AsInt32Array().ToList() ?? [],
            EndpointToEndpointMapping = segmentObject
                .Get("endpoints_mappings")
                .AsGodotDictionary<int, int>()
                .ToDictionary(),
            Lanes =
            [
                .. segmentObject
                    .Get("lanes")
                    .AsGodotObjectArray<GodotObject>()
                    .ToList()
                    .Select(NetLane.Map),
            ],
        };

        return newSegment;
    }
}
