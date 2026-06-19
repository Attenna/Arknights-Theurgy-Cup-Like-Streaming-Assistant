using Godot;
using System;
using System.Collections.Generic;

namespace Framework.Validation;

/// <summary>
/// Validates content files against schemas
/// </summary>
public partial class ContentValidator : RefCounted
{
    public signal void ValidationError(string message, string field, string entityId);
    public signal void ValidationWarning(string message, string field, string entityId);
    
    public enum LogLevel
    {
        Debug,
        Info,
        Warning,
        Error
    }

    private string _schemaVersion;
    private LogLevel _logLevel = LogLevel.Info;
    private bool _logTimestamps = true;
    private int _errorCount = 0;
    private int _warningCount = 0;

    public ContentValidator(string schemaVersion = "1.0")
    {
        _schemaVersion = schemaVersion;
        LogInfo($"ContentValidator initialized with schema version: {schemaVersion}");
    }

    public void SetLogLevel(LogLevel level)
    {
        _logLevel = level;
        LogInfo($"Validation log level set to: {level}");
    }

    public void SetLogTimestamps(bool enabled)
    {
        _logTimestamps = enabled;
    }

    public int GetErrorCount() => _errorCount;
    public int GetWarningCount() => _warningCount;
    public void ResetCounters() { _errorCount = 0; _warningCount = 0; }

    public bool ValidatePlayer(Dictionary player, string entityId = "")
    {
        LogDebug($"════════════════════════════════════════════════════════════════");
        LogDebug($"Validating player: {entityId ?? "unknown"}");
        
        var schema = ContentSchema.GetPlayerSchema();
        var errors = new List<string>();
        var fields = schema["fields"] as Dictionary<string, object>;

        LogDebug($"Schema fields count: {fields.Count}");
        LogDebug($"Player fields count: {player.Count}");

        foreach (var fieldName in fields.Keys)
        {
            var fieldInfo = fields[fieldName] as Dictionary<string, object>;
            bool required = fieldInfo.TryGetValue("required", out var req) && (bool)req;
            
            LogDebug($"Checking field: {fieldName} (required: {required})");

            if (required)
            {
                if (!player.ContainsKey(fieldName) || player[fieldName] == null)
                {
                    string error = $"Missing required field: {fieldName}";
                    LogError(error);
                    errors.Add(error);
                }
                else if (fieldInfo.TryGetValue("type", out var expectedType) && expectedType is Variant.Type type)
                {
                    if (type == Variant.Type.String && player[fieldName] is string str && string.IsNullOrEmpty(str))
                    {
                        string error = $"Field cannot be empty: {fieldName}";
                        LogError(error);
                        errors.Add(error);
                    }
                }
            }
        }

        foreach (var key in player.Keys)
        {
            string keyStr = key.ToString();
            if (keyStr == "custom_fields")
                continue;

            if (!fields.ContainsKey(keyStr))
            {
                string warning = $"Unknown field: {keyStr}";
                LogWarning(warning);
                EmitSignal(nameof(ValidationWarning), warning, keyStr, entityId);
            }
            else if (fields[keyStr] is Dictionary<string, object> fieldInfo && fieldInfo.TryGetValue("type", out var expectedType))
            {
                var actualValue = player[key];
                Variant.Type expectedVariantType = Variant.Type.Nil;
                
                if (expectedType is Variant.Type)
                {
                    expectedVariantType = (Variant.Type)expectedType;
                }

                if (expectedVariantType != Variant.Type.Nil && !IsValidType(actualValue, expectedVariantType))
                {
                    string error = $"Invalid type for field '{keyStr}': expected {expectedVariantType}, got {Variant.GetType(actualValue)}";
                    LogError(error);
                    errors.Add(error);
                }

                if (expectedVariantType == Variant.Type.String && actualValue is string str && string.IsNullOrEmpty(str))
                {
                    string error = $"Field cannot be empty: {keyStr}";
                    LogError(error);
                    errors.Add(error);
                }
            }
        }

        if (errors.Count == 0)
        {
            LogSuccess($"Player validation passed: {entityId}");
            return true;
        }

        LogError($"Player validation failed: {entityId} ({errors.Count} errors)");
        foreach (var error in errors)
        {
            EmitSignal(nameof(ValidationError), error, "", entityId);
        }
        return false;
    }

    public bool ValidateTeam(Dictionary team, string entityId = "")
    {
        LogDebug($"════════════════════════════════════════════════════════════════");
        LogDebug($"Validating team: {entityId ?? "unknown"}");
        
        var schema = ContentSchema.GetTeamSchema();
        var errors = new List<string>();
        var fields = schema["fields"] as Dictionary<string, object>;

        LogDebug($"Schema fields count: {fields.Count}");
        LogDebug($"Team fields count: {team.Count}");

        foreach (var fieldName in fields.Keys)
        {
            var fieldInfo = fields[fieldName] as Dictionary<string, object>;
            bool required = fieldInfo.TryGetValue("required", out var req) && (bool)req;
            
            LogDebug($"Checking field: {fieldName} (required: {required})");

            if (required)
            {
                if (!team.ContainsKey(fieldName) || team[fieldName] == null)
                {
                    string error = $"Missing required field: {fieldName}";
                    LogError(error);
                    errors.Add(error);
                }
            }
        }

        if (team.TryGetValue("members", out var members) && members is Array membersArray)
        {
            LogDebug($"Validating members array (size: {membersArray.Count})");
            
            for (int i = 0; i < membersArray.Count; i++)
            {
                if (membersArray[i] is not string)
                {
                    string error = $"Member at index {i} must be a string (got {Variant.GetType(membersArray[i])})";
                    LogError(error);
                    errors.Add(error);
                }
            }
        }

        if (errors.Count == 0)
        {
            LogSuccess($"Team validation passed: {entityId}");
            return true;
        }

        LogError($"Team validation failed: {entityId} ({errors.Count} errors)");
        foreach (var error in errors)
        {
            EmitSignal(nameof(ValidationError), error, "", entityId);
        }
        return false;
    }

    public bool ValidateSelection(Dictionary selection, string entityId = "")
    {
        LogDebug($"════════════════════════════════════════════════════════════════");
        LogDebug($"Validating selection: {entityId ?? "unknown"}");
        
        var schema = ContentSchema.GetSelectionSchema();
        var errors = new List<string>();
        var fields = schema["fields"] as Dictionary<string, object>;

        LogDebug($"Schema fields count: {fields.Count}");
        LogDebug($"Selection fields count: {selection.Count}");

        foreach (var fieldName in fields.Keys)
        {
            var fieldInfo = fields[fieldName] as Dictionary<string, object>;
            bool required = fieldInfo.TryGetValue("required", out var req) && (bool)req;
            
            LogDebug($"Checking field: {fieldName} (required: {required})");

            if (required)
            {
                if (!selection.ContainsKey(fieldName) || selection[fieldName] == null)
                {
                    string error = $"Missing required field: {fieldName}";
                    LogError(error);
                    errors.Add(error);
                }
            }
        }

        if (errors.Count == 0)
        {
            LogSuccess($"Selection validation passed: {entityId}");
            return true;
        }

        LogError($"Selection validation failed: {entityId} ({errors.Count} errors)");
        foreach (var error in errors)
        {
            EmitSignal(nameof(ValidationError), error, "", entityId);
        }
        return false;
    }

    public bool ValidateGameRules(Dictionary rules)
    {
        LogDebug($"════════════════════════════════════════════════════════════════");
        LogDebug($"Validating game rules");
        
        var schema = ContentSchema.GetGameRulesSchema();
        var errors = new List<string>();
        var fields = schema["fields"] as Dictionary<string, object>;

        LogDebug($"Schema fields count: {fields.Count}");
        LogDebug($"Rules fields count: {rules.Count}");

        foreach (var fieldName in fields.Keys)
        {
            var fieldInfo = fields[fieldName] as Dictionary<string, object>;
            bool required = fieldInfo.TryGetValue("required", out var req) && (bool)req;
            
            LogDebug($"Checking field: {fieldName} (required: {required})");

            if (required)
            {
                if (!rules.ContainsKey(fieldName) || rules[fieldName] == null)
                {
                    string error = $"Missing required field: {fieldName}";
                    LogError(error);
                    errors.Add(error);
                }
            }
        }

        if (rules.TryGetValue("score_calculation", out var calc) && calc is string calcStr)
        {
            LogDebug($"Validating score_calculation: {calcStr}");
            
            if (calcStr != "sum" && calcStr != "average" && calcStr != "custom")
            {
                string error = $"Invalid score_calculation: {calcStr} (must be 'sum', 'average', or 'custom')";
                LogError(error);
                errors.Add(error);
            }
        }

        if (errors.Count == 0)
        {
            LogSuccess("Game rules validation passed");
            return true;
        }

        LogError($"Game rules validation failed ({errors.Count} errors)");
        foreach (var error in errors)
        {
            EmitSignal(nameof(ValidationError), error, "", "");
        }
        return false;
    }

    public bool ValidateManifest(Dictionary manifest)
    {
        LogDebug($"════════════════════════════════════════════════════════════════");
        LogDebug($"Validating manifest");
        
        var schema = ContentSchema.GetContentManifestSchema();
        var errors = new List<string>();
        var fields = schema["fields"] as Dictionary<string, object>;

        LogDebug($"Schema fields count: {fields.Count}");
        LogDebug($"Manifest fields count: {manifest.Count}");

        foreach (var fieldName in fields.Keys)
        {
            var fieldInfo = fields[fieldName] as Dictionary<string, object>;
            bool required = fieldInfo.TryGetValue("required", out var req) && (bool)req;
            
            LogDebug($"Checking field: {fieldName} (required: {required})");

            if (required)
            {
                if (!manifest.ContainsKey(fieldName) || manifest[fieldName] == null)
                {
                    string error = $"Missing required field: {fieldName}";
                    LogError(error);
                    errors.Add(error);
                }
            }
        }

        if (manifest.TryGetValue("content_version", out var version) && version is string versionStr)
        {
            LogDebug($"Validating content_version: {versionStr}");
            
            if (!IsValidVersionFormat(versionStr))
            {
                string error = $"Invalid content_version format: {versionStr} (expected x.y.z)";
                LogError(error);
                errors.Add(error);
            }
        }

        if (errors.Count == 0)
        {
            LogSuccess("Manifest validation passed");
            return true;
        }

        LogError($"Manifest validation failed ({errors.Count} errors)");
        foreach (var error in errors)
        {
            EmitSignal(nameof(ValidationError), error, "", "");
        }
        return false;
    }

    private bool IsValidType(Variant value, Variant.Type expectedType)
    {
        if (expectedType == Variant.Type.Nil)
            return value == null || value.VariantType == Variant.Type.Nil;

        if (value == null)
            return false;

        var actualType = Variant.GetType(value);
        bool isValid = actualType == expectedType;
        
        if (!isValid)
        {
            LogDebug($"Type mismatch: expected {expectedType}, got {actualType}");
        }
        
        return isValid;
    }

    private bool IsValidVersionFormat(string version)
    {
        var parts = version.Split('.');
        
        LogDebug($"Version format check: {version} -> {parts.Length} parts");
        
        if (parts.Length < 2 || parts.Length > 3)
            return false;

        foreach (var part in parts)
        {
            if (!int.TryParse(part, out _))
                return false;
        }
        return true;
    }

    public Dictionary ValidateContentDirectory(string basePath)
    {
        LogInfo("════════════════════════════════════════════════════════════════");
        LogInfo($"Validating content directory: {basePath}");
        
        var results = new Dictionary
        {
            ["valid"] = true,
            ["errors"] = new Array(),
            ["warnings"] = new Array(),
            ["manifest_valid"] = false,
            ["players_count"] = 0,
            ["teams_count"] = 0,
            ["selections_count"] = 0
        };

        string manifestPath = basePath.PathJoin("manifest.json");
        if (FileAccess.FileExists(manifestPath))
        {
            LogInfo($"Found manifest: {manifestPath}");
            
            using var file = FileAccess.Open(manifestPath, FileAccess.ModeFlags.Read);
            if (file != null)
            {
                var content = file.GetAsText();
                file.Close();
                var manifest = JSON.ParseString(content);
                
                if (manifest is Dictionary manifestDict)
                {
                    results["manifest_valid"] = ValidateManifest(manifestDict);
                    
                    if (manifestDict.TryGetValue("players", out var playersPath) && playersPath is string pp)
                    {
                        string fullPath = basePath.PathJoin(pp);
                        if (FileAccess.FileExists(fullPath))
                        {
                            LogInfo($"Found players file: {pp}");
                        }
                        else
                        {
                            string error = $"Players file not found: {fullPath}";
                            LogError(error);
                            (results["errors"] as Array).Add(error);
                            results["valid"] = false;
                        }
                    }
                    
                    if (manifestDict.TryGetValue("teams", out var teamsPath) && teamsPath is string tp)
                    {
                        string fullPath = basePath.PathJoin(tp);
                        if (FileAccess.FileExists(fullPath))
                        {
                            LogInfo($"Found teams file: {tp}");
                        }
                        else
                        {
                            string error = $"Teams file not found: {fullPath}";
                            LogError(error);
                            (results["errors"] as Array).Add(error);
                            results["valid"] = false;
                        }
                    }
                }
            }
        }
        else
        {
            LogWarning("No manifest.json found in content directory");
            (results["warnings"] as Array).Add("No manifest.json found");
        }

        if ((results["errors"] as Array).Count == 0)
        {
            LogSuccess("Content directory validation completed successfully");
        }
        else
        {
            LogError($"Content directory validation completed with {(results["errors"] as Array).Count} errors");
        }

        return results;
    }

    private void LogDebug(string message)
    {
        if (_logLevel <= LogLevel.Debug)
        {
            GD.Print(_logTimestamps ? $"[VAL-DBG][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[VAL-DBG] {message}");
        }
    }

    private void LogInfo(string message)
    {
        if (_logLevel <= LogLevel.Info)
        {
            GD.Print(_logTimestamps ? $"[VAL-INFO][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[VAL-INFO] {message}");
        }
    }

    private void LogSuccess(string message)
    {
        if (_logLevel <= LogLevel.Info)
        {
            GD.Print(_logTimestamps ? $"[VAL-SUCCESS][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[VAL-SUCCESS] {message}");
        }
    }

    private void LogWarning(string message)
    {
        _warningCount++;
        if (_logLevel <= LogLevel.Warning)
        {
            GD.PushWarning(_logTimestamps ? $"[VAL-WARN][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[VAL-WARN] {message}");
        }
    }

    private void LogError(string message)
    {
        _errorCount++;
        GD.PushError(_logTimestamps ? $"[VAL-ERROR][{DateTime.Now:HH:mm:ss.fff}] {message}" : $"[VAL-ERROR] {message}");
    }
}
