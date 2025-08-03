using Godot;
using Godot.Collections;

namespace PTS.Models.Network;

public enum CurveDirection
{
    Clockwise = 1,
    CounterClockwise = -1,
}

[GlobalClass]
public partial class NetSegmentInfo : Node
{
    public Array<int> Nodes { get; } = [];

    public float CurveStrength { get; set; }
    public CurveDirection CurveDirection { get; set; }

    public Array<NetConnectionInfo> Relations { get; set; } = [];

    public NetSegmentInfo(
        int nodeA,
        int nodeB,
        float curveStrength = 0f,
        CurveDirection curveDirection = CurveDirection.Clockwise
    )
    {
        Nodes.Add(nodeA);
        Nodes.Add(nodeB);
        CurveStrength = curveStrength;
        CurveDirection = curveDirection;
    }
}
