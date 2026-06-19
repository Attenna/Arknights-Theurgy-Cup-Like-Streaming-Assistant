using Godot;
using System;
using System.Collections.Generic;

namespace Framework.Config;

/// <summary>
/// Manages framework and game configuration
/// </summary>
public partial class ConfigManager : RefCounted
{
    public signal void ConfigLoaded(string configType);
    public signal void ConfigChanged(string configType, string key);

    private Dictionary _frameworkConfig = new();
    private Dictionary _gameConfig = new();
    private string _contentDir = "";
    private string _configDir = "";

    public ConfigManager()
    {
        _frameworkConfig = GetDefaultFrameworkConfig();
        _gameConfig = new Dictionary();
    }

    private Dictionary GetDefaultFrameworkConfig()
    {
        return new Dictionary
        {
            ["content_directory"] = "user_content",
            ["auto_load_content"] = true,
            ["enable_validation"] = true,
            ["enable_extensions"] = true,
            ["log_level"] = "info",
            ["auto_backup"] = true,
            ["backup_count"] = 5
        };
    }

    public void SetContentDirectory(string dir)
    {
        _contentDir = dir;
        _frameworkConfig["content_directory"] = dir;
    }

    public string GetContentDirectory()
    {
        return _contentDir;
    }

    public void SetConfigDirectory(string dir)
    {
        _configDir = dir;
    }

    public string GetConfigDirectory()
    {
        return _configDir;
    }

    public bool LoadFrameworkConfig(string path)
    {
        string configPath = path.PathJoin("framework_config.json");
        if (!FileAccess.FileExists(configPath))
        {
            GD.PushWarning("Framework config not found, using defaults");
            return false;
        }

        using var file = FileAccess.Open(configPath, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            GD.PushError($"Cannot open framework config: {configPath}");
            return false;
        }

        var content = file.GetAsText();
        file.Close();
        var data = JSON.ParseString(content);

        if (data is Dictionary dataDict)
        {
            foreach (string key in _frameworkConfig.Keys)
            {
                if (dataDict.ContainsKey(key))
                {
                    _frameworkConfig[key] = dataDict[key];
                }
            }
            EmitSignal(nameof(ConfigLoaded), "framework");
            return true;
        }

        GD.PushError("Invalid framework config format");
        return false;
    }

    public bool SaveFrameworkConfig(string path)
    {
        string configPath = path.PathJoin("framework_config.json");
        using var file = FileAccess.Open(configPath, FileAccess.ModeFlags.Write);
        if (file == null)
        {
            GD.PushError($"Cannot save framework config: {configPath}");
            return false;
        }

        file.StoreString(JSON.stringify(_frameworkConfig, "\t"));
        file.Close();
        return true;
    }

    public bool LoadGameConfig(string path)
    {
        if (!FileAccess.FileExists(path))
            return false;

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null)
            return false;

        var content = file.GetAsText();
        file.Close();
        var data = JSON.ParseString(content);

        if (data is Dictionary dataDict)
        {
            _gameConfig = dataDict;
            EmitSignal(nameof(ConfigLoaded), "game");
            return true;
        }

        return false;
    }

    public bool SaveGameConfig(string path)
    {
        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Write);
        if (file == null)
            return false;

        file.StoreString(JSON.stringify(_gameConfig, "\t"));
        file.Close();
        return true;
    }

    public Variant GetFrameworkConfig(string key, Variant defaultValue = null)
    {
        return _frameworkConfig.TryGetValue(key, out var value) ? value : defaultValue;
    }

    public void SetFrameworkConfig(string key, Variant value)
    {
        _frameworkConfig[key] = value;
        EmitSignal(nameof(ConfigChanged), "framework", key);
    }

    public Variant GetGameConfig(string key, Variant defaultValue = null)
    {
        return _gameConfig.TryGetValue(key, out var value) ? value : defaultValue;
    }

    public void SetGameConfig(string key, Variant value)
    {
        _gameConfig[key] = value;
        EmitSignal(nameof(ConfigChanged), "game", key);
    }

    public bool HasGameConfig(string key)
    {
        return _gameConfig.ContainsKey(key);
    }

    public Dictionary GetAllFrameworkConfig()
    {
        return new Dictionary(_frameworkConfig);
    }

    public Dictionary GetAllGameConfig()
    {
        return new Dictionary(_gameConfig);
    }

    public void ResetFrameworkConfig()
    {
        _frameworkConfig = GetDefaultFrameworkConfig();
        EmitSignal(nameof(ConfigChanged), "framework", "");
    }

    public Array ValidateConfig()
    {
        var errors = new Array();

        if (string.IsNullOrEmpty(_contentDir))
        {
            errors.Add("Content directory is not set");
        }
        else if (!DirAccess.DirExistsAbsolute(_contentDir))
        {
            errors.Add($"Content directory does not exist: {_contentDir}");
        }

        if (_frameworkConfig.TryGetValue("log_level", out var logLevel))
        {
            string level = logLevel.ToString();
            if (level != "debug" && level != "info" && level != "warning" && level != "error")
            {
                errors.Add($"Invalid log_level: {level}");
            }
        }

        return errors;
    }
}
