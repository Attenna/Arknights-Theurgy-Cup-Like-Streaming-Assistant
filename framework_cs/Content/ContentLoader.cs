using Godot;
using System;
using System.Collections.Generic;

namespace Framework.Content;

/// <summary>
/// Handles loading content from user-provided directories
/// </summary>
public partial class ContentLoader : RefCounted
{
    public signal void ContentLoaded(string contentType, int count);
    public signal void ContentLoadFailed(string contentType, string error);
    
    public enum LogLevel
    {
        Debug,
        Info,
        Warning,
        Error
    }

    private string _contentBasePath = "";
    private ContentValidator _validator;
    private LogLevel _logLevel = LogLevel.Info;
    private bool _logTimestamps = true;

    public ContentLoader(ContentValidator validator = null)
    {
        _validator = validator ?? new ContentValidator();
        _validator.ValidationError += OnValidationError;
        _validator.ValidationWarning += OnValidationWarning;
        LogInfo("ContentLoader initialized");
    }

    public void SetLogLevel(LogLevel level)
    {
        _logLevel = level;
        LogInfo($"Log level set to: {level}");
    }

    public void SetLogTimestamps(bool enabled)
    {
        _logTimestamps = enabled;
    }

    public void SetContentBasePath(string path)
    {
        _contentBasePath = path;
        LogInfo($"Content base path set to: {path}");
    }

    public string GetContentBasePath()
    {
        return _contentBasePath;
    }

    public Dictionary LoadAllContent()
    {
        LogInfo("════════════════════════════════════════════════════════════════");
        LogInfo("Starting content loading process...");
        LogInfo($"Content base path: {_contentBasePath}");
        
        var results = new Dictionary
        {
            ["success"] = false,
            ["players"] = new Array(),
            ["teams"] = new Array(),
            ["selections"] = new Array(),
            ["game_rules"] = new Dictionary(),
            ["errors"] = new Array(),
            ["warnings"] = new Array()
        };

        // Try to load manifest first
        LogInfo("────────────────────────────────────────────────────────────────");
        LogInfo("Step 1: Loading manifest.json...");
        
        var manifest = LoadManifest();
        if (manifest == null)
        {
            LogWarning("No valid manifest.json found, falling back to legacy loading");
            (results["errors"] as Array).Add("No valid manifest.json found");
            var legacyResults = LoadLegacyContent();
            LogInfo("Legacy content loading completed");
            return legacyResults;
        }
        
        LogSuccess("Manifest loaded successfully");
        results["manifest"] = manifest;

        // Log manifest contents
        LogDebug($"Manifest content: {JSON.stringify(manifest)}");

        // Load content based on manifest paths
        LogInfo("────────────────────────────────────────────────────────────────");
        LogInfo("Step 2: Loading content files based on manifest...");

        if (manifest.TryGetValue("players", out var playersPath) && playersPath is string playersPathStr)
        {
            LogInfo($"Loading players from: {playersPathStr}");
            results["players"] = LoadPlayersFile(_contentBasePath.PathJoin(playersPathStr));
            LogSuccess($"Players loaded: {(results["players"] as Array).Count} valid entries");
        }
        else
        {
            LogWarning("No players file specified in manifest");
        }

        if (manifest.TryGetValue("teams", out var teamsPath) && teamsPath is string teamsPathStr)
        {
            LogInfo($"Loading teams from: {teamsPathStr}");
            results["teams"] = LoadTeamsFile(_contentBasePath.PathJoin(teamsPathStr));
            LogSuccess($"Teams loaded: {(results["teams"] as Array).Count} valid entries");
        }
        else
        {
            LogWarning("No teams file specified in manifest");
        }

        if (manifest.TryGetValue("selections", out var selectionsPath) && selectionsPath is string selectionsPathStr)
        {
            LogInfo($"Loading selections from: {selectionsPathStr}");
            results["selections"] = LoadSelectionsFile(_contentBasePath.PathJoin(selectionsPathStr));
            LogSuccess($"Selections loaded: {(results["selections"] as Array).Count} valid entries");
        }
        else
        {
            LogWarning("No selections file specified in manifest");
        }

        if (manifest.TryGetValue("game_rules", out var rulesPath) && rulesPath is string rulesPathStr)
        {
            LogInfo($"Loading game rules from: {rulesPathStr}");
            results["game_rules"] = LoadGameRules(_contentBasePath.PathJoin(rulesPathStr));
            LogSuccess("Game rules loaded");
        }
        else
        {
            LogWarning("No game_rules file specified in manifest, using defaults");
            results["game_rules"] = GetDefaultGameRules();
        }

        results["success"] = true;
        
        LogInfo("────────────────────────────────────────────────────────────────");
        LogSuccess("╔══════════════════════════════════════════════════════════════╗");
        LogSuccess("║              CONTENT LOADING COMPLETED SUCCESSFULLY         ║");
        LogSuccess("╚══════════════════════════════════════════════════════════════╝");
        LogSuccess($"  Players:      {(results["players"] as Array).Count}");
        LogSuccess($"  Teams:        {(results["teams"] as Array).Count}");
        LogSuccess($"  Selections:   {(results["selections"] as Array).Count}");
        LogSuccess($"  Game Rules:   Loaded");

        return results;
    }

    private Dictionary GetDefaultGameRules()
    {
        return new Dictionary
        {
            ["initial_balance"] = 0,
            ["max_players_per_team"] = 10,
            ["score_calculation"] = "sum",
            ["allow_custom_fields"] = true,
            ["required_selections"] = new Array()
        };
    }

    private Dictionary LoadManifest()
    {
        string manifestPath = _contentBasePath.PathJoin("manifest.json");
        LogDebug($"Checking manifest path: {manifestPath}");

        if (!FileAccess.FileExists(manifestPath))
        {
            LogWarning($"Manifest file not found: {manifestPath}");
            return null;
        }

        LogDebug($"Opening manifest file: {manifestPath}");
        using var file = FileAccess.Open(manifestPath, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            LogError($"Cannot open manifest file: {manifestPath} (Error: {FileAccess.GetOpenError()})");
            return null;
        }

        LogDebug("Reading manifest content...");
        var content = file.GetAsText();
        file.Close();
        
        LogDebug($"Raw manifest content (first 500 chars): {content.Substring(0, Math.Min(content.Length, 500))}...");

        LogDebug("Parsing manifest JSON...");
        var data = JSON.ParseString(content);

        if (data is Dictionary dict)
        {
            LogDebug("Validating manifest...");
            if (_validator.ValidateManifest(dict))
            {
                LogDebug("Manifest validation passed");
                return dict;
            }
            else
            {
                LogWarning("Manifest validation failed");
                return null;
            }
        }
        else
        {
            LogError($"Manifest JSON parsing failed: Expected Dictionary, got {Variant.GetType(data)}");
            return null;
        }
    }

    private Array LoadPlayersFile(string path)
    {
        var players = new Array();
        int totalCount = 0;
        int validCount = 0;
        int invalidCount = 0;

        LogDebug($"Loading players from: {path}");

        if (!FileAccess.FileExists(path))
        {
            LogError($"Players file not found: {path}");
            EmitSignal(nameof(ContentLoadFailed), "players", $"File not found: {path}");
            return players;
        }

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            LogError($"Cannot open players file: {path} (Error: {FileAccess.GetOpenError()})");
            EmitSignal(nameof(ContentLoadFailed), "players", $"Cannot open file: {path}");
            return players;
        }

        var content = file.GetAsText();
        file.Close();
        
        LogDebug($"Players file size: {content.Length} characters");

        var data = JSON.ParseString(content);

        if (data is Array dataArray)
        {
            totalCount = dataArray.Count;
            LogInfo($"Found {totalCount} player entries to process");

            for (int i = 0; i < dataArray.Count; i++)
            {
                LogDebug($"Processing player entry #{i + 1}");
                
                if (dataArray[i] is Dictionary player)
                {
                    string entityId = player.TryGetValue("id", out var id) ? id.ToString() : $"unknown_{i}";
                    LogDebug($"  Player ID: {entityId}");

                    if (_validator.ValidatePlayer(player, entityId))
                    {
                        players.Add(player);
                        validCount++;
                        LogDebug($"  ✓ Validation passed");
                    }
                    else
                    {
                        invalidCount++;
                        LogWarning($"  ✗ Validation failed for player: {entityId}");
                    }
                }
                else
                {
                    invalidCount++;
                    LogWarning($"  ✗ Player at index {i} is not a dictionary (type: {Variant.GetType(dataArray[i])})");
                }
            }
            
            LogInfo($"Player processing complete: {validCount} valid, {invalidCount} invalid out of {totalCount} total");
            EmitSignal(nameof(ContentLoaded), "players", validCount);
        }
        else
        {
            LogError($"Players file JSON parsing failed: Expected Array, got {Variant.GetType(data)}");
            EmitSignal(nameof(ContentLoadFailed), "players", "Invalid JSON format: expected array");
        }

        return players;
    }

    private Array LoadTeamsFile(string path)
    {
        var teams = new Array();
        int totalCount = 0;
        int validCount = 0;
        int invalidCount = 0;

        LogDebug($"Loading teams from: {path}");

        if (!FileAccess.FileExists(path))
        {
            LogError($"Teams file not found: {path}");
            EmitSignal(nameof(ContentLoadFailed), "teams", $"File not found: {path}");
            return teams;
        }

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            LogError($"Cannot open teams file: {path} (Error: {FileAccess.GetOpenError()})");
            EmitSignal(nameof(ContentLoadFailed), "teams", $"Cannot open file: {path}");
            return teams;
        }

        var content = file.GetAsText();
        file.Close();
        
        LogDebug($"Teams file size: {content.Length} characters");

        var data = JSON.ParseString(content);

        if (data is Array dataArray)
        {
            totalCount = dataArray.Count;
            LogInfo($"Found {totalCount} team entries to process");

            for (int i = 0; i < dataArray.Count; i++)
            {
                LogDebug($"Processing team entry #{i + 1}");
                
                if (dataArray[i] is Dictionary team)
                {
                    string entityId = team.TryGetValue("id", out var id) ? id.ToString() : $"unknown_{i}";
                    LogDebug($"  Team ID: {entityId}");

                    if (_validator.ValidateTeam(team, entityId))
                    {
                        teams.Add(team);
                        validCount++;
                        LogDebug($"  ✓ Validation passed");
                    }
                    else
                    {
                        invalidCount++;
                        LogWarning($"  ✗ Validation failed for team: {entityId}");
                    }
                }
                else
                {
                    invalidCount++;
                    LogWarning($"  ✗ Team at index {i} is not a dictionary (type: {Variant.GetType(dataArray[i])})");
                }
            }
            
            LogInfo($"Team processing complete: {validCount} valid, {invalidCount} invalid out of {totalCount} total");
            EmitSignal(nameof(ContentLoaded), "teams", validCount);
        }
        else
        {
            LogError($"Teams file JSON parsing failed: Expected Array, got {Variant.GetType(data)}");
            EmitSignal(nameof(ContentLoadFailed), "teams", "Invalid JSON format: expected array");
        }

        return teams;
    }

    private Array LoadSelectionsFile(string path)
    {
        var selections = new Array();

        LogDebug($"Loading selections from: {path}");

        if (!FileAccess.FileExists(path))
        {
            LogError($"Selections file not found: {path}");
            EmitSignal(nameof(ContentLoadFailed), "selections", $"File not found: {path}");
            return selections;
        }

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            LogError($"Cannot open selections file: {path} (Error: {FileAccess.GetOpenError()})");
            EmitSignal(nameof(ContentLoadFailed), "selections", $"Cannot open file: {path}");
            return selections;
        }

        var content = file.GetAsText();
        file.Close();
        
        LogDebug($"Selections file size: {content.Length} characters");

        var data = JSON.ParseString(content);

        if (data is Dictionary categorizedData)
        {
            LogInfo($"Found categorized selections format with {categorizedData.Count} categories");
            
            foreach (string category in categorizedData.Keys)
            {
                LogDebug($"Processing category: {category}");
                
                if (categorizedData[category] is Array categorySelections)
                {
                    LogDebug($"  Found {categorySelections.Count} items in category");
                    
                    for (int i = 0; i < categorySelections.Count; i++)
                    {
                        if (categorySelections[i] is Dictionary selection)
                        {
                            selection["_category"] = category;
                            string entityId = selection.TryGetValue("id", out var sid) ? sid.ToString() : $"{category}_{i}";
                            
                            if (_validator.ValidateSelection(selection, entityId))
                            {
                                selections.Add(selection);
                                LogDebug($"    ✓ Added selection: {entityId}");
                            }
                            else
                            {
                                LogWarning($"    ✗ Validation failed for selection: {entityId}");
                            }
                        }
                        else
                        {
                            LogWarning($"    ✗ Selection at index {i} is not a dictionary");
                        }
                    }
                }
                else
                {
                    LogWarning($"  Category {category} does not contain an array");
                }
            }
        }
        else if (data is Array flatData)
        {
            LogInfo($"Found flat selections format with {flatData.Count} items");
            
            for (int i = 0; i < flatData.Count; i++)
            {
                if (flatData[i] is Dictionary selection)
                {
                    string entityId = selection.TryGetValue("id", out var sid) ? sid.ToString() : $"unknown_{i}";
                    
                    if (_validator.ValidateSelection(selection, entityId))
                    {
                        selections.Add(selection);
                        LogDebug($"  ✓ Added selection: {entityId}");
                    }
                    else
                    {
                        LogWarning($"  ✗ Validation failed for selection: {entityId}");
                    }
                }
                else
                {
                    LogWarning($"  ✗ Selection at index {i} is not a dictionary");
                }
            }
        }
        else
        {
            LogError($"Selections file JSON parsing failed: Expected Dictionary or Array, got {Variant.GetType(data)}");
        }

        LogInfo($"Selections loaded: {selections.Count} valid entries");
        EmitSignal(nameof(ContentLoaded), "selections", selections.Count);
        return selections;
    }

    private Dictionary LoadGameRules(string path)
    {
        var defaultRules = new Dictionary
        {
            ["initial_balance"] = 0,
            ["max_players_per_team"] = 10,
            ["score_calculation"] = "sum",
            ["allow_custom_fields"] = true,
            ["required_selections"] = new Array()
        };

        if (!FileAccess.FileExists(path))
        {
            LogWarning($"Game rules file not found: {path}, using defaults");
            return defaultRules;
        }

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            LogWarning($"Cannot open game rules file: {path}, using defaults (Error: {FileAccess.GetOpenError()})");
            return defaultRules;
        }

        var content = file.GetAsText();
        file.Close();
        
        LogDebug($"Game rules file size: {content.Length} characters");

        var data = JSON.ParseString(content);

        if (data is Dictionary rulesDict)
        {
            LogDebug("Validating game rules...");
            
            if (_validator.ValidateGameRules(rulesDict))
            {
                LogDebug("Game rules validation passed");
                
                foreach (string key in defaultRules.Keys)
                {
                    if (!rulesDict.ContainsKey(key))
                    {
                        LogDebug($"Adding missing default rule: {key} = {defaultRules[key]}");
                        rulesDict[key] = defaultRules[key];
                    }
                }
                return rulesDict;
            }
            else
            {
                LogWarning("Game rules validation failed, using defaults");
            }
        }
        else
        {
            LogError($"Game rules file JSON parsing failed: Expected Dictionary, got {Variant.GetType(data)}");
        }

        return defaultRules;
    }

    private Dictionary LoadLegacyContent()
    {
        LogInfo("Loading content in legacy mode (no manifest)");
        
        var results = new Dictionary
        {
            ["success"] = false,
            ["players"] = new Array(),
            ["teams"] = new Array(),
            ["selections"] = new Array(),
            ["game_rules"] = new Dictionary(),
            ["errors"] = new Array(),
            ["warnings"] = new Array()
        };

        string playersPath = _contentBasePath.PathJoin("players.json");
        if (FileAccess.FileExists(playersPath))
        {
            LogInfo($"Legacy mode: loading players from {playersPath}");
            results["players"] = LoadPlayersFile(playersPath);
        }
        else
        {
            LogWarning($"Legacy mode: players.json not found");
        }

        string teamsPath = _contentBasePath.PathJoin("teams.json");
        if (FileAccess.FileExists(teamsPath))
        {
            LogInfo($"Legacy mode: loading teams from {teamsPath}");
            results["teams"] = LoadTeamsFile(teamsPath);
        }
        else
        {
            LogWarning($"Legacy mode: teams.json not found");
        }

        string selectionsPath = _contentBasePath.PathJoin("selections.json");
        if (FileAccess.FileExists(selectionsPath))
        {
            LogInfo($"Legacy mode: loading selections from {selectionsPath}");
            results["selections"] = LoadSelectionsFile(selectionsPath);
        }

        results["game_rules"] = GetDefaultGameRules();
        results["success"] = (results["players"] as Array).Count > 0 || (results["teams"] as Array).Count > 0;
        
        LogInfo($"Legacy loading completed: success={results["success"]}");
        return results;
    }

    public Array ValidateAssetReferences(Dictionary content, string assetBasePath)
    {
        LogInfo("════════════════════════════════════════════════════════════════");
        LogInfo("Validating asset references...");
        LogInfo($"Asset base path: {assetBasePath}");
        
        var errors = new Array();

        if (content.TryGetValue("players", out var players) && players is Array playersArray)
        {
            LogInfo($"Checking {playersArray.Count} player icons...");
            
            foreach (Dictionary player in playersArray)
            {
                if (player.TryGetValue("icon_path", out var iconPath) && iconPath is string iconPathStr)
                {
                    string resolvedPath = ResolveAssetPath(iconPathStr, assetBasePath);
                    string playerId = player.TryGetValue("id", out var id) ? id.ToString() : "unknown";
                    
                    LogDebug($"  Player {playerId}: {iconPathStr} -> {resolvedPath}");
                    
                    if (!FileAccess.FileExists(resolvedPath))
                    {
                        string errorMsg = $"Player icon not found: {resolvedPath} (referenced by {playerId})";
                        LogError(errorMsg);
                        errors.Add(errorMsg);
                    }
                    else
                    {
                        LogDebug($"  ✓ Found");
                    }
                }
            }
        }

        if (content.TryGetValue("teams", out var teams) && teams is Array teamsArray)
        {
            LogInfo($"Checking {teamsArray.Count} team icons...");
            
            foreach (Dictionary team in teamsArray)
            {
                if (team.TryGetValue("icon_path", out var iconPath) && iconPath is string iconPathStr)
                {
                    string resolvedPath = ResolveAssetPath(iconPathStr, assetBasePath);
                    string teamId = team.TryGetValue("id", out var id) ? id.ToString() : "unknown";
                    
                    LogDebug($"  Team {teamId}: {iconPathStr} -> {resolvedPath}");
                    
                    if (!FileAccess.FileExists(resolvedPath))
                    {
                        string errorMsg = $"Team icon not found: {resolvedPath} (referenced by {teamId})";
                        LogError(errorMsg);
                        errors.Add(errorMsg);
                    }
                    else
                    {
                        LogDebug($"  ✓ Found");
                    }
                }
            }
        }

        if (content.TryGetValue("selections", out var selections) && selections is Array selectionsArray)
        {
            LogInfo($"Checking {selectionsArray.Count} selection icons...");
            
            foreach (Dictionary selection in selectionsArray)
            {
                if (selection.TryGetValue("icon_path", out var iconPath) && iconPath is string iconPathStr)
                {
                    string resolvedPath = ResolveAssetPath(iconPathStr, assetBasePath);
                    string selectionId = selection.TryGetValue("id", out var sid) ? sid.ToString() : "unknown";
                    
                    LogDebug($"  Selection {selectionId}: {iconPathStr} -> {resolvedPath}");
                    
                    if (!FileAccess.FileExists(resolvedPath))
                    {
                        string errorMsg = $"Selection icon not found: {resolvedPath} (referenced by {selectionId})";
                        LogError(errorMsg);
                        errors.Add(errorMsg);
                    }
                    else
                    {
                        LogDebug($"  ✓ Found");
                    }
                }
            }
        }

        if (errors.Count == 0)
        {
            LogSuccess("All asset references validated successfully");
        }
        else
        {
            LogError($"Asset validation completed with {errors.Count} errors");
        }

        return errors;
    }

    private string ResolveAssetPath(string relativePath, string basePath)
    {
        if (relativePath.IsAbsolutePath())
            return relativePath;
        return basePath.PathJoin(relativePath);
    }

    public Dictionary LoadContentFromSubdir(string subdir)
    {
        LogInfo($"Loading content from subdirectory: {subdir}");
        
        string oldBase = _contentBasePath;
        _contentBasePath = _contentBasePath.PathJoin(subdir);
        
        var results = LoadAllContent();
        
        _contentBasePath = oldBase;
        return results;
    }

    public Array GetAvailableContentPacks(string basePath)
    {
        LogInfo($"Scanning for content packs in: {basePath}");
        
        var packs = new Array();

        using var dir = DirAccess.Open(basePath);
        if (dir == null)
        {
            LogError($"Cannot open directory: {basePath}");
            return packs;
        }

        dir.ListDirBegin();
        string dirName = dir.GetNext();
        int foundCount = 0;
        
        while (!string.IsNullOrEmpty(dirName))
        {
            if (dir.CurrentIsDir() && !dirName.BeginsWith("."))
            {
                string manifestPath = basePath.PathJoin(dirName).PathJoin("manifest.json");
                LogDebug($"Checking: {dirName} -> {manifestPath}");
                
                if (FileAccess.FileExists(manifestPath))
                {
                    var manifest = LoadJsonFile(manifestPath);
                    if (manifest is Dictionary manifestDict)
                    {
                        packs.Add(new Dictionary
                        {
                            ["id"] = dirName,
                            ["name"] = manifestDict.TryGetValue("name", out var name) ? name : dirName,
                            ["version"] = manifestDict.TryGetValue("content_version", out var version) ? version : "unknown",
                            ["author"] = manifestDict.TryGetValue("author", out var author) ? author : "unknown",
                            ["description"] = manifestDict.TryGetValue("description", out var desc) ? desc : ""
                        });
                        foundCount++;
                        LogDebug($"  ✓ Found content pack: {dirName}");
                    }
                    else
                    {
                        LogWarning($"  ✗ Invalid manifest in: {dirName}");
                    }
                }
            }
            dirName = dir.GetNext();
        }

        LogInfo($"Found {foundCount} content packs");
        return packs;
    }

    private Variant LoadJsonFile(string path)
    {
        if (!FileAccess.FileExists(path))
        {
            LogDebug($"JSON file not found: {path}");
            return null;
        }

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            LogDebug($"Cannot open JSON file: {path}");
            return null;
        }

        var content = file.GetAsText();
        file.Close();
        return JSON.ParseString(content);
    }

    private void OnValidationError(string message, string field, string entityId)
    {
        LogError($"Validation Error [{entityId}] {field}: {message}");
    }

    private void OnValidationWarning(string message, string field, string entityId)
    {
        LogWarning($"Validation Warning [{entityId}] {field}: {message}");
    }

    private void LogDebug(string message)
    {
        if (_logLevel <= LogLevel.Debug)
        {
            GD.Print(_logTimestamps ? $"[DEBUG][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[DEBUG] {message}");
        }
    }

    private void LogInfo(string message)
    {
        if (_logLevel <= LogLevel.Info)
        {
            GD.Print(_logTimestamps ? $"[INFO ][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[INFO] {message}");
        }
    }

    private void LogSuccess(string message)
    {
        if (_logLevel <= LogLevel.Info)
        {
            GD.Print(_logTimestamps ? $"[SUCCESS][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[SUCCESS] {message}");
        }
    }

    private void LogWarning(string message)
    {
        if (_logLevel <= LogLevel.Warning)
        {
            GD.PushWarning(_logTimestamps ? $"[WARN ][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[WARN] {message}");
        }
    }

    private void LogError(string message)
    {
        GD.PushError(_logTimestamps ? $"[ERROR][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[ERROR] {message}");
    }
}
