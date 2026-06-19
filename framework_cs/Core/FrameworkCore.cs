using Godot;
using System;
using System.Collections.Generic;

namespace Framework.Core;

/// <summary>
/// Main framework entry point
/// </summary>
public partial class FrameworkCore : Node
{
    public const string VERSION = "1.0.0";

    public signal void FrameworkReady();
    public signal void FrameworkError(string message);
    public signal void ContentLoadStarted();
    public signal void ContentLoadCompleted(bool success, Dictionary stats);

    public Framework.Content.ContentRegistry ContentRegistry { get; private set; }
    public Framework.Content.ContentLoader ContentLoader { get; private set; }
    public Framework.Validation.ContentValidator ContentValidator { get; private set; }
    public Framework.Config.ConfigManager ConfigManager { get; private set; }

    private bool _initialized = false;
    private bool _contentLoaded = false;

    public override void _Ready()
    {
        GD.Print($"Framework Core v{VERSION} initializing...");
        InitializeFramework();
    }

    private void InitializeFramework()
    {
        ContentRegistry = new Framework.Content.ContentRegistry();
        ContentValidator = new Framework.Validation.ContentValidator();
        ContentLoader = new Framework.Content.ContentLoader(ContentValidator);
        ConfigManager = new Framework.Config.ConfigManager();

        _initialized = true;
        GD.Print("Framework Core initialized successfully");
        EmitSignal(nameof(FrameworkReady));
    }

    public bool LoadContentFromPath(string path)
    {
        if (!_initialized)
        {
            GD.PushError("Framework not initialized");
            return false;
        }

        EmitSignal(nameof(ContentLoadStarted));

        ContentLoader.SetContentBasePath(path);
        var results = ContentLoader.LoadAllContent();

        if (results.TryGetValue("success", out var success) && (bool)success)
        {
            ContentRegistry.LoadFromResults(results);
            _contentLoaded = true;

            var stats = ContentRegistry.GetStats();
            GD.Print($"Content loaded: {stats["total_players"]} players, {stats["total_teams"]} teams, {stats["total_selections"]} selections");
            EmitSignal(nameof(ContentLoadCompleted), true, stats);
            return true;
        }
        else
        {
            var errors = results.TryGetValue("errors", out var errs) ? errs as Array : new Array();
            foreach (var error in errors)
            {
                GD.PushError($"Content load error: {error}");
            }
            EmitSignal(nameof(ContentLoadCompleted), false, new Dictionary { ["errors"] = errors });
            return false;
        }
    }

    public bool LoadDefaultContent()
    {
        string exeDir = GetExeDirectory();
        string defaultContentPath = exeDir.PathJoin(
            ConfigManager.GetFrameworkConfig("content_directory", "user_content").ToString()
        );
        return LoadContentFromPath(defaultContentPath);
    }

    public bool IsContentLoaded()
    {
        return _contentLoaded;
    }

    public Dictionary GetFrameworkInfo()
    {
        return new Dictionary
        {
            ["version"] = VERSION,
            ["content_loaded"] = _contentLoaded,
            ["initialized"] = _initialized,
            ["stats"] = _contentLoaded ? ContentRegistry.GetStats() : new Dictionary()
        };
    }

    private string GetExeDirectory()
    {
        string exePath = OS.GetExecutablePath();
        return exePath.GetBaseDir();
    }

    public bool ReloadContent()
    {
        ContentRegistry.ClearAll();
        return LoadDefaultContent();
    }

    public Array ValidateAllContent(string assetBasePath = "")
    {
        if (!_contentLoaded)
        {
            return new Array { "No content loaded to validate" };
        }

        var content = new Dictionary
        {
            ["players"] = ContentRegistry.GetAllPlayers(),
            ["teams"] = ContentRegistry.GetAllTeams(),
            ["selections"] = ContentRegistry.GetAllSelections()
        };

        return ContentLoader.ValidateAssetReferences(content, assetBasePath);
    }

    public void SetLogLevel(string level)
    {
        ConfigManager.SetFrameworkConfig("log_level", level);
    }

    public static Dictionary GetDocumentation()
    {
        return new Dictionary
        {
            ["framework_name"] = "Streaming Assistant Framework",
            ["version"] = "1.0.0",
            ["purpose"] = "Generic, reusable template for streaming applications",
            ["content_structure"] = new Dictionary
            {
                ["manifest"] = "Content pack manifest (required)",
                ["players"] = "Player entity definitions",
                ["teams"] = "Team entity definitions",
                ["selections"] = "Selection options (characters, items, etc.)",
                ["game_rules"] = "Game rule configurations"
            },
            ["extension_points"] = new Array
            {
                "Custom game rules calculation",
                "Custom UI rendering",
                "Custom scene transitions",
                "Custom validation logic"
            }
        };
    }
}
