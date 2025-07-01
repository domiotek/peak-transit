using Godot;

namespace PTS.Models;

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
