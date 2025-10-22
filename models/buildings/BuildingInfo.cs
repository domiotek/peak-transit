using Godot;

namespace PT.Models.Buildings;

[GlobalClass]
public partial class BuildingInfo : GodotObject
{
    public BuildingType Type { get; set; }

    public float OffsetPosition { get; set; } = 0f;

    public BuildingInfo(BuildingType type, float offsetPosition = 0f)
    {
        Type = type;
        OffsetPosition = offsetPosition;
    }
}
