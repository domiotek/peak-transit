using System.Collections.Generic;
using System.Linq;

namespace PT.Models.TimeTable;

public class Trip
{
    public required int RouteId { get; set; }

    public required TimeOfDay DepartureTime { get; set; }

    public required TimeOfDay ArrivalTime { get; set; }

    public required Dictionary<int, TimeOfDay> StopTimes { get; set; }

    public required double Duration { get; set; }

    public Godot.Collections.Dictionary Serialize()
    {
        var stopTimesDict = new Godot.Collections.Dictionary();

        foreach (var kvp in StopTimes)
        {
            stopTimesDict[kvp.Key] = kvp.Value.Serialize();
        }

        var dict = new Godot.Collections.Dictionary
        {
            ["routeId"] = RouteId,
            ["departureTime"] = DepartureTime.Serialize(),
            ["arrivalTime"] = ArrivalTime.Serialize(),
            ["stopTimes"] = stopTimesDict,
            ["duration"] = Duration,
        };
        return dict;
    }

    public static Trip Deserialize(Godot.Collections.Dictionary dict)
    {
        return new Trip
        {
            RouteId = (int)dict["routeId"],
            DepartureTime = TimeOfDay.Deserialize(
                (Godot.Collections.Dictionary)dict["departureTime"]
            ),
            ArrivalTime = TimeOfDay.Deserialize((Godot.Collections.Dictionary)dict["arrivalTime"]),
            StopTimes = ((Godot.Collections.Dictionary)dict["stopTimes"]).ToDictionary(
                kvp => (int)kvp.Key,
                kvp => TimeOfDay.Deserialize((Godot.Collections.Dictionary)kvp.Value)
            ),
            Duration = (double)dict["duration"],
        };
    }
}
