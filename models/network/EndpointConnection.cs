using System.Collections.Generic;
using System.Linq;
using PT.Models.PathFinding;
using PT.Models.WorldDefinition.Network;

namespace PT.Models.Network;

public class EndpointConnection
{
    public BaseLaneDirection Direction { get; set; }

    public List<VehicleCategory> AllowedVehicles { get; } = [];

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["Direction"] = (int)Direction,
            ["AllowedVehicles"] = AllowedVehicles.Select(vc => (int)vc).ToArray(),
        };
        return dict;
    }

    public static EndpointConnection Deserialize(Godot.Collections.Dictionary data)
    {
        var connection = new EndpointConnection
        {
            Direction = (BaseLaneDirection)(int)data["Direction"],
        };

        var allowedVehiclesArray = data["AllowedVehicles"].AsInt32Array();

        foreach (var vcObj in allowedVehiclesArray)
        {
            connection.AllowedVehicles.Add((VehicleCategory)vcObj);
        }

        return connection;
    }
}
