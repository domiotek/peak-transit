using Godot;
using Godot.Collections;
using PTS.Models.Network;

namespace PTS.Constants;

[GlobalClass]
public partial class NetworkDefinition : GodotObject
{
    public Array<NetNode> Nodes { get; } =
        [
            new NetNode(0, new Vector2(-114, 46)) { IntersectionType = IntersectionType.Default },
            new NetNode(1, new Vector2(126, 47)),
            new NetNode(2, new Vector2(238, 97)),
            new NetNode(3, new Vector2(428, 37)),
            new NetNode(4, new Vector2(765, -302))
            {
                IntersectionType = IntersectionType.TrafficLights,
                PrioritySegments = [6, 3],
                StopSegments = [5],
            },
            new NetNode(5, new Vector2(400, -600)),
            new NetNode(6, new Vector2(1000, -600)),
            new NetNode(7, new Vector2(-600, -800)),
            new NetNode(8, new Vector2(300, 1000)),
            new NetNode(9, new Vector2(-600, 200)) { PrioritySegments = [0, 10] },
            new NetNode(10, new Vector2(-600, 800)),
            new NetNode(11, new Vector2(-1200, 200)),
            new NetNode(12, new Vector2(800, 1500)),
        ];

    public Array<NetSegmentInfo> Segments { get; } =
        new()
        {
            new NetSegmentInfo(0, 1, 0.2f, CurveDirection.CounterClockwise)
            {
                Relations =
                [
                    new(0) { Lanes = [new(), new()] },
                    new(1) { Lanes = [new() { Direction = LaneDirection.Auto }, new()] },
                ],
            },
            new NetSegmentInfo(1, 2)
            {
                Relations =
                [
                    new(1) { Lanes = [new(), new(), new()] },
                    new(2) { Lanes = [new(), new(), new()] },
                ],
            },
            new NetSegmentInfo(2, 3, 0.4f)
            {
                Relations = [new(2) { Lanes = [new(), new()] }, new(3) { Lanes = [new(), new()] }],
            },
            new NetSegmentInfo(3, 4, 0.1f, CurveDirection.CounterClockwise)
            {
                Relations =
                [
                    new(3)
                    {
                        Lanes =
                        [
                            new() { Direction = LaneDirection.Left },
                            new() { Direction = LaneDirection.ForwardLeft },
                            new(),
                        ],
                    },
                    new(4) { Lanes = [new(), new()] },
                ],
            },
            new NetSegmentInfo(4, 5, 0.1f, CurveDirection.Clockwise)
            {
                Relations = [new(4) { Lanes = [new()] }, new(5) { Lanes = [new()] }],
            },
            new NetSegmentInfo(4, 6, 0.1f, CurveDirection.Clockwise)
            {
                Relations =
                [
                    new(4) { Lanes = [new(), new(), new()] },
                    new(6) { Lanes = [new(), new(), new()] },
                ],
            },
            new NetSegmentInfo(0, 7, 0.1f, CurveDirection.Clockwise)
            {
                Relations = [new(0) { Lanes = [new(), new()] }, new(7) { Lanes = [new(), new()] }],
            },
            new NetSegmentInfo(0, 8, 0.1f, CurveDirection.Clockwise)
            {
                Relations = [new(0) { Lanes = [new(), new()] }, new(8) { Lanes = [new(), new()] }],
            },
            new NetSegmentInfo(0, 9, 0.1f, CurveDirection.Clockwise)
            {
                Relations = [new(0) { Lanes = [new(), new()] }, new(9) { Lanes = [new(), new()] }],
            },
            new NetSegmentInfo(9, 10, 0.1f, CurveDirection.Clockwise)
            {
                Relations = [new(9) { Lanes = [new(), new(), new()] }, new(10) { Lanes = [new()] }],
            },
            new NetSegmentInfo(9, 11, 0.1f, CurveDirection.Clockwise)
            {
                Relations = [new(9) { Lanes = [new(), new()] }, new(11) { Lanes = [new(), new()] }],
            },
            new NetSegmentInfo(10, 8, 0.4f, CurveDirection.Clockwise)
            {
                Relations = [new(10) { Lanes = [new(), new(), new()] }, new(8) { Lanes = [new()] }],
            },
            new NetSegmentInfo(8, 12, 0.1f, CurveDirection.Clockwise)
            {
                Relations = [new(8) { Lanes = [new(), new()] }, new(12) { Lanes = [new(), new()] }],
            },
        };
}
