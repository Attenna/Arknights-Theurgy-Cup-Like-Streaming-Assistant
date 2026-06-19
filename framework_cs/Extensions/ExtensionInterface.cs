using Godot;
using System;
using System.Collections.Generic;

namespace Framework.Extensions;

/// <summary>
/// Defines extension points for framework customization
/// </summary>
public partial class ExtensionInterface : RefCounted
{
    public enum ExtensionType
    {
        CustomGameRules,
        CustomValidator,
        CustomRenderer,
        CustomSceneFactory,
        CustomImporter
    }

    public signal void ExtensionRegistered(ExtensionType extensionType, string extensionId);
    public signal void ExtensionUnregistered(ExtensionType extensionType, string extensionId);
    public signal void ExtensionError(string extensionId, string error);

    private Dictionary _extensions = new();
    private bool _enabled = true;

    public bool RegisterExtension(string extensionId, ExtensionType extensionType, Godot.Object handler)
    {
        if (!_enabled)
        {
            GD.PushWarning("Extensions are disabled");
            return false;
        }

        if (_extensions.ContainsKey(extensionId))
        {
            GD.PushError($"Extension already registered: {extensionId}");
            return false;
        }

        _extensions[extensionId] = new Dictionary
        {
            ["type"] = extensionType,
            ["handler"] = handler,
            ["enabled"] = true
        };

        EmitSignal(nameof(ExtensionRegistered), extensionType, extensionId);
        GD.Print($"Extension registered: {extensionId} (type: {GetTypeName(extensionType)})");
        return true;
    }

    public bool UnregisterExtension(string extensionId)
    {
        if (!_extensions.ContainsKey(extensionId))
            return false;

        var ext = _extensions[extensionId] as Dictionary;
        EmitSignal(nameof(ExtensionUnregistered), (ExtensionType)(int)ext["type"], extensionId);
        _extensions.Remove(extensionId);
        return true;
    }

    public Godot.Object GetExtension(string extensionId)
    {
        if (_extensions.TryGetValue(extensionId, out var ext))
        {
            return (ext as Dictionary)["handler"] as Godot.Object;
        }
        return null;
    }

    public Array GetExtensionsByType(ExtensionType extensionType)
    {
        var result = new Array();
        foreach (string extId in _extensions.Keys)
        {
            var ext = _extensions[extId] as Dictionary;
            if ((ExtensionType)(int)ext["type"] == extensionType)
            {
                result.Add(ext["handler"]);
            }
        }
        return result;
    }

    public bool SetExtensionEnabled(string extensionId, bool enabled)
    {
        if (!_extensions.ContainsKey(extensionId))
            return false;

        (_extensions[extensionId] as Dictionary)["enabled"] = enabled;
        return true;
    }

    public bool IsExtensionEnabled(string extensionId)
    {
        if (_extensions.TryGetValue(extensionId, out var ext))
        {
            return (bool)(ext as Dictionary)["enabled"];
        }
        return false;
    }

    public Dictionary GetAllExtensions()
    {
        return new Dictionary(_extensions);
    }

    private string GetTypeName(ExtensionType type)
    {
        return type switch
        {
            ExtensionType.CustomGameRules => "CustomGameRules",
            ExtensionType.CustomValidator => "CustomValidator",
            ExtensionType.CustomRenderer => "CustomRenderer",
            ExtensionType.CustomSceneFactory => "CustomSceneFactory",
            ExtensionType.CustomImporter => "CustomImporter",
            _ => "Unknown"
        };
    }

    /// <summary>
    /// Custom game rules interface
    /// </summary>
    public partial class CustomGameRules : Godot.Object
    {
        public virtual int CalculateTeamScore(Array players, Dictionary rules)
        {
            int total = 0;
            foreach (var player in players)
            {
                if (player is Dictionary playerDict &&
                    playerDict.TryGetValue("stats", out var stats) &&
                    stats is Dictionary statsDict &&
                    statsDict.TryGetValue("score", out var score))
                {
                    total += Convert.ToInt32(score);
                }
            }
            return total;
        }

        public virtual int CalculateTeamBalance(int initialBalance, Array players)
        {
            int totalTaken = 0;
            foreach (var player in players)
            {
                if (player is Dictionary playerDict &&
                    playerDict.TryGetValue("stats", out var stats) &&
                    stats is Dictionary statsDict &&
                    statsDict.TryGetValue("money_taken", out var moneyTaken))
                {
                    totalTaken += Convert.ToInt32(moneyTaken);
                }
            }
            return initialBalance - totalTaken;
        }

        public virtual Array ValidateGameState(ContentRegistry registry, Dictionary rules)
        {
            return new Array(); // Return empty array means valid
        }
    }

    /// <summary>
    /// Custom validator interface
    /// </summary>
    public partial class CustomValidator : Godot.Object
    {
        public virtual Array ValidatePlayer(Dictionary player)
        {
            return new Array(); // Return empty array means valid
        }

        public virtual Array ValidateTeam(Dictionary team, Array players)
        {
            return new Array();
        }

        public virtual Array ValidateSelection(Dictionary selection)
        {
            return new Array();
        }
    }

    /// <summary>
    /// Custom renderer interface
    /// </summary>
    public partial class CustomRenderer : Godot.Object
    {
        public virtual void RenderPlayer(Dictionary player, Control parent)
        {
        }

        public virtual void RenderTeam(Dictionary team, Control parent)
        {
        }

        public virtual void RenderSelection(Dictionary selection, Control parent)
        {
        }
    }
}
