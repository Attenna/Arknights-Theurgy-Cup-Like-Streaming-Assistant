using Godot;
using System;
using System.Collections.Generic;

namespace Framework.Content;

/// <summary>
/// Defines the schema structure for all content files
/// </summary>
public partial class ContentSchema : RefCounted
{
    public const string SCHEMA_VERSION = "1.0";

    public static Dictionary<string, object> GetPlayerSchema()
    {
        return new Dictionary<string, object>
        {
            ["type"] = "player",
            ["version"] = SCHEMA_VERSION,
            ["fields"] = new Dictionary<string, object>
            {
                ["id"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Unique player identifier" },
                ["name"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Player display name" },
                ["team_id"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Associated team ID" },
                ["icon_path"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Path to player avatar image" },
                ["captain"] = new Dictionary<string, object> { ["type"] = Variant.Type.Bool, ["required"] = false, ["default"] = false, ["description"] = "Whether player is team captain" },
                ["custom_fields"] = new Dictionary<string, object> { ["type"] = Variant.Type.Dictionary, ["required"] = false, ["description"] = "User-defined custom fields" }
            }
        };
    }

    public static Dictionary<string, object> GetTeamSchema()
    {
        return new Dictionary<string, object>
        {
            ["type"] = "team",
            ["version"] = SCHEMA_VERSION,
            ["fields"] = new Dictionary<string, object>
            {
                ["id"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Unique team identifier" },
                ["name"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Team display name" },
                ["icon_path"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Path to team logo image" },
                ["members"] = new Dictionary<string, object> { ["type"] = Variant.Type.Array, ["required"] = false, ["default"] = new Array<Variant>(), ["description"] = "List of player IDs in team" },
                ["captain_id"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Captain player ID" },
                ["custom_fields"] = new Dictionary<string, object> { ["type"] = Variant.Type.Dictionary, ["required"] = false, ["description"] = "User-defined custom fields" }
            }
        };
    }

    public static Dictionary<string, object> GetSelectionSchema()
    {
        return new Dictionary<string, object>
        {
            ["type"] = "selection",
            ["version"] = SCHEMA_VERSION,
            ["fields"] = new Dictionary<string, object>
            {
                ["id"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Unique selection identifier" },
                ["name"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Display name" },
                ["category"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Category (e.g., character, relic, squad)" },
                ["icon_path"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Path to selection icon" },
                ["custom_fields"] = new Dictionary<string, object> { ["type"] = Variant.Type.Dictionary, ["required"] = false, ["description"] = "User-defined custom fields" }
            }
        };
    }

    public static Dictionary<string, object> GetSceneSchema()
    {
        return new Dictionary<string, object>
        {
            ["type"] = "scene",
            ["version"] = SCHEMA_VERSION,
            ["fields"] = new Dictionary<string, object>
            {
                ["id"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Unique scene identifier" },
                ["name"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Scene display name" },
                ["scene_type"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Type: main_vision, streaming_arena, waiting, custom" },
                ["assets"] = new Dictionary<string, object> { ["type"] = Variant.Type.Dictionary, ["required"] = false, ["description"] = "Scene-specific asset paths" },
                ["custom_fields"] = new Dictionary<string, object> { ["type"] = Variant.Type.Dictionary, ["required"] = false, ["description"] = "User-defined custom fields" }
            }
        };
    }

    public static Dictionary<string, object> GetGameRulesSchema()
    {
        return new Dictionary<string, object>
        {
            ["type"] = "game_rules",
            ["version"] = SCHEMA_VERSION,
            ["fields"] = new Dictionary<string, object>
            {
                ["initial_balance"] = new Dictionary<string, object> { ["type"] = Variant.Type.Int, ["required"] = false, ["default"] = 0, ["description"] = "Starting balance" },
                ["max_players_per_team"] = new Dictionary<string, object> { ["type"] = Variant.Type.Int, ["required"] = false, ["default"] = 10, ["description"] = "Maximum players per team" },
                ["score_calculation"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["default"] = "sum", ["description"] = "How team score is calculated: sum, average, custom" },
                ["allow_custom_fields"] = new Dictionary<string, object> { ["type"] = Variant.Type.Bool, ["required"] = false, ["default"] = true, ["description"] = "Allow custom fields in entities" },
                ["required_selections"] = new Dictionary<string, object> { ["type"] = Variant.Type.Array, ["required"] = false, ["default"] = new Array<Variant>(), ["description"] = "Required selection categories" }
            }
        };
    }

    public static Dictionary<string, object> GetContentManifestSchema()
    {
        return new Dictionary<string, object>
        {
            ["type"] = "manifest",
            ["version"] = SCHEMA_VERSION,
            ["fields"] = new Dictionary<string, object>
            {
                ["content_version"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = true, ["description"] = "Content pack version" },
                ["author"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Content author" },
                ["description"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Content pack description" },
                ["players"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Path to players data file" },
                ["teams"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Path to teams data file" },
                ["selections"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Path to selections data file" },
                ["scenes"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Path to scenes configuration file" },
                ["game_rules"] = new Dictionary<string, object> { ["type"] = Variant.Type.String, ["required"] = false, ["description"] = "Path to game rules file" }
            }
        };
    }

    public static Dictionary<string, Dictionary<string, object>> GetAllSchemas()
    {
        return new Dictionary<string, Dictionary<string, object>>
        {
            ["player"] = GetPlayerSchema(),
            ["team"] = GetTeamSchema(),
            ["selection"] = GetSelectionSchema(),
            ["scene"] = GetSceneSchema(),
            ["game_rules"] = GetGameRulesSchema(),
            ["manifest"] = GetContentManifestSchema()
        };
    }
}
