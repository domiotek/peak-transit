using Godot;

namespace PTS.Models.Network;

[GlobalClass]
public partial class NetNode : Node
{
    public int Id { get; set; } = -1;
    public Vector2 Position { get; set; } = Vector2.Zero;

    public NetNode(int id, Vector2 position)
    {
        Id = id;
        Position = position;
    }
}
