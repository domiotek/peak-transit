namespace PT.Models.TimeTable;

public class TripStep
{
    public required int StepId { get; set; }

    public required int TravelTime { get; set; }

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["step_id"] = StepId,
            ["travel_time"] = TravelTime,
        };
        return dict;
    }

    public static TripStep Deserialize(Godot.Collections.Dictionary dict)
    {
        return new TripStep
        {
            StepId = (int)dict["step_id"],
            TravelTime = (int)dict["travel_time"],
        };
    }
}
