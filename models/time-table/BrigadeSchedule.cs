using System.Collections.Generic;

namespace PT.Models.TimeTable;

public class BrigadeSchedule
{
    public required int BrigadeId { get; set; }

    public required List<Trip> Trips { get; set; } = new();

    public required int TotalCycleTime { get; set; }

    public Godot.Collections.Dictionary Serialize()
    {
        var tripsSerialized = new Godot.Collections.Array();
        foreach (var trip in Trips)
        {
            tripsSerialized.Add(trip.Serialize());
        }

        var dict = new Godot.Collections.Dictionary
        {
            ["brigade_id"] = BrigadeId,
            ["trips"] = tripsSerialized,
            ["cycle_time"] = TotalCycleTime,
        };
        return dict;
    }

    public static BrigadeSchedule Deserialize(Godot.Collections.Dictionary dict)
    {
        var tripsArray = (Godot.Collections.Array)dict["trips"];
        var trips = new List<Trip>();
        foreach (var tripObj in tripsArray)
        {
            var tripDict = (Godot.Collections.Dictionary)tripObj;
            trips.Add(Trip.Deserialize(tripDict));
        }

        return new BrigadeSchedule
        {
            BrigadeId = (int)dict["brigade_id"],
            Trips = trips,
            TotalCycleTime = (int)dict["cycle_time"],
        };
    }
}
