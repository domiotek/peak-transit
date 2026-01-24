using System.Collections.Generic;
using Godot;

namespace PT.Helpers;

public static class FSHelper
{
    public static bool EnsureFileExists(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return false;
        }

        if (!FileAccess.FileExists(path))
        {
            if (path.StartsWith("user://", System.StringComparison.OrdinalIgnoreCase))
            {
                string resolvedPath = ResolveUserPath(path);
                if (!FileAccess.FileExists(resolvedPath))
                {
                    return false;
                }
            }
            else
            {
                return false;
            }
        }
        return true;
    }

    public static bool EnsureDirectoryExists(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return false;
        }

        if (!DirAccess.DirExistsAbsolute(path))
        {
            if (path.StartsWith("user://", System.StringComparison.OrdinalIgnoreCase))
            {
                DirAccess.MakeDirAbsolute(path);
            }

            if (!DirAccess.DirExistsAbsolute(path))
            {
                return false;
            }
        }
        return true;
    }

    public static string ResolveUserPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return path;
        }

        if (path.StartsWith("user://", System.StringComparison.OrdinalIgnoreCase))
        {
            string userDataDir = OS.GetUserDataDir();
            return path.Replace(
                "user://",
                userDataDir + "/",
                System.StringComparison.OrdinalIgnoreCase
            );
        }

        return path;
    }

    public static string SanitizeFileName(string fileName)
    {
        var invalidChars = System.IO.Path.GetInvalidFileNameChars();
        foreach (var invalidChar in invalidChars)
        {
            fileName = fileName.Replace(invalidChar.ToString(), "_");
        }
        return fileName;
    }
}
