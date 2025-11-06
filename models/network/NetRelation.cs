using Godot;

namespace PT.Models.Network;

[GlobalClass]
public partial class NetRelation : GodotObject
{
    public Node2D StartNode { get; set; }
    public Node2D EndNode { get; set; }

    public NetConnectionInfo ConnectionInfo { get; set; }
}
