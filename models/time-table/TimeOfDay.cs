namespace PT.Models.TimeTable;

public class TimeOfDay
{
    public int Hour { get; set; }

    public int Minute { get; set; }

    public int TotalMinutes { get; set; }

    public TimeOfDay(int hour, int minute, int? totalMinutes = null)
    {
        Hour = hour;
        Minute = minute;
        TotalMinutes = totalMinutes ?? (hour * 60 + minute);
    }

    public TimeOfDay(int totalMinutes)
    {
        TotalMinutes = totalMinutes;
        Hour = totalMinutes / 60 % 24;
        Minute = totalMinutes % 60;
    }

    public TimeOfDay AddMinutes(int minutesToAdd)
    {
        int totalMinutes = TotalMinutes + minutesToAdd;
        int newHour = totalMinutes / 60 % 24;
        int newMinute = totalMinutes % 60;

        return new TimeOfDay(newHour, newMinute, totalMinutes);
    }

    public Godot.Collections.Dictionary Serialize()
    {
        return new Godot.Collections.Dictionary
        {
            ["hour"] = Hour,
            ["minute"] = Minute,
            ["totalMinutes"] = TotalMinutes,
        };
    }

    public static TimeOfDay Deserialize(Godot.Collections.Dictionary dict)
    {
        return new TimeOfDay(
            (int)dict["hour"],
            (int)dict["minute"],
            dict.ContainsKey("totalMinutes") ? (int)dict["totalMinutes"] : (int?)null
        );
    }
}
