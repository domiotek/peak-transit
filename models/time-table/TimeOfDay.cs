namespace PT.Models.TimeTable;

public class TimeOfDay
{
    public required int Hour { get; set; }

    public required int Minute { get; set; }

    public TimeOfDay AddMinutes(int minutesToAdd)
    {
        int totalMinutes = Hour * 60 + Minute + minutesToAdd;
        int newHour = totalMinutes / 60 % 24;
        int newMinute = totalMinutes % 60;

        return new TimeOfDay { Hour = newHour, Minute = newMinute };
    }

    public Godot.Collections.Dictionary Serialize()
    {
        return new Godot.Collections.Dictionary { ["hour"] = Hour, ["minute"] = Minute };
    }

    public static TimeOfDay Deserialize(Godot.Collections.Dictionary dict)
    {
        return new TimeOfDay { Hour = (int)dict["hour"], Minute = (int)dict["minute"] };
    }
}
