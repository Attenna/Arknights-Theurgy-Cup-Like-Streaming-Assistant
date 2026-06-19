# Streaming Assistant Framework - Documentation

## Overview

The **Streaming Assistant Framework** is a generic, reusable template for building streaming applications. It provides a modular architecture that loads all content dynamically from user-provided folders without any hardcoded game-specific data.

## Quick Start

1. Create a content folder (e.g., `user_content/`)
2. Create a `manifest.json` file
3. Add your players, teams, and selections data
4. Run the application

## Framework Architecture

```
framework_cs/
├── Core/
│   └── FrameworkCore.cs        # Main entry point
├── Content/
│   ├── ContentSchema.cs        # Schema definitions
│   ├── ContentLoader.cs        # Content loading system
│   └── ContentRegistry.cs      # Central content registry
├── Config/
│   └── ConfigManager.cs         # Configuration management
├── Validation/
│   └── ContentValidator.cs     # Content validation
└── Extensions/
    └── ExtensionInterface.cs    # Extension points
```

## Content Directory Structure

```
user_content/
├── manifest.json          # Content pack manifest (REQUIRED)
├── players.json           # Player definitions
├── teams.json             # Team definitions
├── selections.json        # Selection options
├── game_rules.json        # Game rules configuration
└── assets/                # Asset files (images, icons)
    ├── players/           # Player avatar images
    ├── teams/            # Team logo images
    └── selections/       # Selection item images
```

## File Formats

### manifest.json

```json
{
    "content_version": "1.0.0",
    "name": "My Content Pack",
    "author": "Your Name",
    "description": "Description of your content pack",
    "players": "players.json",
    "teams": "teams.json",
    "selections": "selections.json",
    "game_rules": "game_rules.json"
}
```

### players.json

```json
[
    {
        "id": "player_001",
        "name": "Player Name",
        "team_id": "team_001",
        "icon_path": "assets/players/player001.png",
        "captain": false,
        "stats": {
            "score": 100,
            "money_taken": 50
        },
        "custom_fields": {
            "any_custom_key": "any_custom_value"
        }
    }
]
```

### teams.json

```json
[
    {
        "id": "team_001",
        "name": "Team Name",
        "icon_path": "assets/teams/team001.png",
        "members": ["player_001", "player_002"],
        "captain_id": "player_001",
        "custom_fields": {}
    }
]
```

### selections.json

```json
{
    "characters": [
        {
            "id": "char_001",
            "name": "Character Name",
            "icon_path": "assets/selections/char001.png"
        }
    ],
    "relics": [
        {
            "id": "relic_001",
            "name": "Relic Name"
        }
    ]
}
```

### game_rules.json

```json
{
    "initial_balance": 1000,
    "max_players_per_team": 10,
    "score_calculation": "sum",
    "allow_custom_fields": true,
    "required_selections": ["characters"]
}
```

## How to Run and Test the Framework

### Prerequisites

1. **Godot Engine 4.x** - The framework is built for Godot 4.x with C# support
2. **.NET 6+** - Required for C# scripting in Godot

### Setting Up the Project

1. Open the project in Godot Engine
2. Ensure C# support is enabled (Project > Tools > C# > Build)

### Running the Test Scene

The framework includes a test scene to validate content loading:

1. **Load the test scene**: `scene/framework_test.tscn`
2. **Configure content path**: In the Inspector, set `Content Path` to your content directory
3. **Enable debug logging**: Check `Enable Debug Logging` for detailed output
4. **Run the scene**

### Expected Log Output

When running the test scene with the example content, you should see:

```
════════════════════════════════════════════════════════════════
                    FRAMEWORK TEST SCENE                        
════════════════════════════════════════════════════════════════

[STEP 1] Initializing Framework Components
✓ ContentValidator initialized
✓ ContentLoader initialized
✓ Signals connected

[STEP 2] Loading Content
Content Path: framework/docs/examples/example_content

[STEP 2.1] Validating Content Directory
Directory Valid: True

[STEP 2.2] Loading All Content
[INFO ][12:00:00.000] ════════════════════════════════════════
[INFO ][12:00:00.001] Starting content loading process...
[INFO ][12:00:00.002] Content base path: framework/docs/examples/example_content
[INFO ][12:00:00.003] ────────────────────────────────────────
[INFO ][12:00:00.004] Step 1: Loading manifest.json...
[SUCCESS][12:00:00.010] Manifest loaded successfully
[INFO ][12:00:00.011] ────────────────────────────────────────
[INFO ][12:00:00.012] Step 2: Loading content files based on manifest...
[INFO ][12:00:00.013] Loading players from: players.json
[SUCCESS][12:00:00.018] Players loaded: 4 valid entries
[INFO ][12:00:00.019] Loading teams from: teams.json
[SUCCESS][12:00:00.022] Teams loaded: 2 valid entries
[INFO ][12:00:00.023] Loading selections from: selections.json
[SUCCESS][12:00:00.028] Selections loaded: 6 valid entries
[INFO ][12:00:00.029] Loading game rules from: game_rules.json
[SUCCESS][12:00:00.031] Game rules loaded
[INFO ][12:00:00.032] ────────────────────────────────────────
[SUCCESS][12:00:00.033] ╔══════════════════════════════════╗
[SUCCESS][12:00:00.034] ║ CONTENT LOADING COMPLETED SUCCESSFULLY ║
[SUCCESS][12:00:00.035] ╚══════════════════════════════════╝
[SUCCESS][12:00:00.036]   Players:      4
[SUCCESS][12:00:00.037]   Teams:        2
[SUCCESS][12:00:00.038]   Selections:   6
[SUCCESS][12:00:00.039]   Game Rules:   Loaded

[STEP 3] Load Results
Success: True
Players Loaded: 4
Teams Loaded: 2
Selections Loaded: 6

[STEP 4] Validating Asset References
[INFO ][12:00:00.040] ════════════════════════════════════════
[INFO ][12:00:00.041] Validating asset references...
[INFO ][12:00:00.042] Asset base path: framework/docs/examples/example_content
[INFO ][12:00:00.043] Checking 4 player icons...
[INFO ][12:00:00.044] Checking 2 team icons...
[INFO ][12:00:00.045] Checking 6 selection icons...
[SUCCESS][12:00:00.046] All asset references validated successfully
✓ All asset references validated successfully

[STEP 5] Statistics
Validation Errors: 0
Validation Warnings: 0

════════════════════════════════════════════════════════════════
                    TEST COMPLETED                              
════════════════════════════════════════════════════════════════
```

## Debug Logging

The framework includes comprehensive logging to help diagnose issues:

### Log Levels

- **Debug**: Detailed information for troubleshooting
- **Info**: General progress messages
- **Warning**: Potential issues that don't block loading
- **Error**: Critical issues that prevent loading

### Setting Log Levels

```csharp
// ContentLoader
var loader = new ContentLoader();
loader.SetLogLevel(ContentLoader.LogLevel.Debug);

// ContentValidator  
var validator = new ContentValidator();
validator.SetLogLevel(ContentValidator.LogLevel.Debug);
```

### Log Output Format

```
[LEVEL][timestamp] Message
```

- `[DEBUG]`: Detailed debug information
- `[INFO]`: General information
- `[SUCCESS]`: Successful operation
- `[WARN]`: Warning (potential issue)
- `[ERROR]`: Error (critical issue)
- `[VAL-DBG]`: Validation debug
- `[VAL-INFO]`: Validation information
- `[VAL-WARN]`: Validation warning
- `[VAL-ERROR]`: Validation error

## Troubleshooting Common Issues

### Content Loading Failed

**Symptom**: "No valid manifest.json found"

**Solution**:
1. Check that `manifest.json` exists in your content directory
2. Verify the JSON format is valid
3. Ensure `content_version` field is present

### Validation Errors

**Symptom**: "Missing required field: id"

**Solution**:
1. Check your JSON files for missing required fields
2. Ensure all players have `id`, `name`, and `team_id`
3. Ensure all teams have `id` and `name`

### Asset Not Found

**Symptom**: "Player icon not found: ..."

**Solution**:
1. Verify the `icon_path` in your data files
2. Ensure the asset file exists at the specified path
3. Use relative paths from the content directory

### JSON Parsing Error

**Symptom**: "Invalid JSON format"

**Solution**:
1. Validate your JSON with a JSON validator
2. Check for missing commas or brackets
3. Ensure proper quote escaping

## Extension Points

The framework provides extension interfaces for customization:

### CustomGameRules

```csharp
public partial class MyCustomRules : ExtensionInterface.CustomGameRules
{
    public override int CalculateTeamScore(Array players, Dictionary rules)
    {
        // Custom implementation
        return base.CalculateTeamScore(players, rules);
    }
}
```

### CustomValidator

```csharp
public partial class MyCustomValidator : ExtensionInterface.CustomValidator
{
    public override Array ValidatePlayer(Dictionary player)
    {
        var errors = new Array();
        // Custom validation
        return errors;
    }
}
```

## API Reference

### FrameworkCore

**Properties:**
- `ContentRegistry` - Central content registry
- `ContentLoader` - Content loading system
- `ContentValidator` - Content validation
- `ConfigManager` - Configuration management

**Methods:**
- `LoadContentFromPath(string path)` - Load content from specified directory
- `LoadDefaultContent()` - Load content from default directory
- `ReloadContent()` - Reload current content
- `ValidateAllContent(string assetBasePath)` - Validate all loaded content

### ContentLoader

**Methods:**
- `LoadAllContent()` - Load all content from current base path
- `ValidateAssetReferences(Dictionary content, string assetBasePath)` - Validate asset references
- `SetLogLevel(LogLevel level)` - Set logging level
- `GetAvailableContentPacks(string basePath)` - Get available content packs

### ContentValidator

**Methods:**
- `ValidatePlayer(Dictionary player, string entityId)` - Validate player data
- `ValidateTeam(Dictionary team, string entityId)` - Validate team data
- `ValidateSelection(Dictionary selection, string entityId)` - Validate selection data
- `ValidateManifest(Dictionary manifest)` - Validate manifest
- `ValidateContentDirectory(string basePath)` - Validate content directory
- `SetLogLevel(LogLevel level)` - Set logging level
- `GetErrorCount()` - Get number of validation errors
- `GetWarningCount()` - Get number of validation warnings
- `ResetCounters()` - Reset error/warning counters

## Example Content

The framework includes example content at `framework/docs/examples/example_content/`:

- `manifest.json` - Content pack manifest
- `players.json` - 4 sample players (Alice, Bob, Charlie, Diana)
- `teams.json` - 2 sample teams (Red Team, Blue Team)
- `selections.json` - Characters and relics selections
- `game_rules.json` - Game rules configuration

## Tips for Content Creation

1. **Use unique IDs**: Every player and team should have a unique ID
2. **Match team_ids**: Player's `team_id` should match team's `id`
3. **Organize assets**: Keep assets in subdirectories by type
4. **Version your content**: Use semantic versioning (x.y.z)
5. **Test incrementally**: Run the test scene frequently to catch issues early
6. **Enable debug logging**: Use debug log level when troubleshooting
