# Godot Project Export Script
# UTF-8 encoding

param(
    [string]$GodotPath = "C:\Program Files (x86)\Godot\Godot_v4.3-stable_win64.exe",
    [string]$OutputDir = "builds"
)

Write-Host "=== Godot Project Export Script ===" -ForegroundColor Green
Write-Host "Project: Studio2" -ForegroundColor Yellow
Write-Host "Godot Path: $GodotPath" -ForegroundColor Yellow

# Check if Godot exists
if (!(Test-Path $GodotPath)) {
    Write-Host "Error: Godot executable not found at: $GodotPath" -ForegroundColor Red
    exit 1
}

Write-Host "Found Godot executable" -ForegroundColor Green

# Create output directory
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

# Create export presets
$exportPresets = @'
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="builds/Studio2.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
binary_format/architecture="x86_64"
application/product_name="Studio2"
application/file_description="Studio Management System"
application/company_name=""
application/copyright=""
'@

$exportPresetsPath = "export_presets.cfg"
if (!(Test-Path $exportPresetsPath)) {
    $exportPresets | Out-File -FilePath $exportPresetsPath -Encoding UTF8
    Write-Host "Created export presets file" -ForegroundColor Green
}

# Export project
Write-Host "Starting project export..." -ForegroundColor Cyan
$exportArgs = @(
    "--headless",
    "--export-release",
    "Windows Desktop",
    "$OutputDir\Studio2.exe"
)

try {
    & $GodotPath @exportArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Export successful!" -ForegroundColor Green
        
        # Create user data files
        Write-Host "Creating user data files..." -ForegroundColor Cyan
        $userDataDir = "$OutputDir\userdata"
        
        if (!(Test-Path "$userDataDir\teams")) {
            New-Item -ItemType Directory -Path "$userDataDir\teams" -Force | Out-Null
        }
        if (!(Test-Path "$userDataDir\announcers")) {
            New-Item -ItemType Directory -Path "$userDataDir\announcers" -Force | Out-Null
        }
        
        # Teams data
        $teamsJson = @'
[
    {
        "name": "Team Alpha",
        "balance": 1000,
        "score": 95,
        "rank": 1,
        "icon_path": "",
        "id": "team_001"
    },
    {
        "name": "Team Beta", 
        "balance": 800,
        "score": 88,
        "rank": 2,
        "icon_path": "",
        "id": "team_002"
    },
    {
        "name": "Team Gamma",
        "balance": 600,
        "score": 76,
        "rank": 3,
        "icon_path": "",
        "id": "team_003"
    }
]
'@
        
        # Announcers data
        $announcersJson = @'
{
    "announcers": [
        {
            "icon_path": "",
            "id": "announcer_001",
            "name": "Announcer 1"
        },
        {
            "icon_path": "",
            "id": "announcer_002", 
            "name": "Announcer 2"
        },
        {
            "icon_path": "",
            "id": "announcer_003",
            "name": "Announcer 3"
        }
    ],
    "count": 3,
    "timestamp": 1751684636.471
}
'@
        
        $teamsJson | Out-File -FilePath "$userDataDir\teams\teams.json" -Encoding UTF8
        $announcersJson | Out-File -FilePath "$userDataDir\announcers\current_announcer.json" -Encoding UTF8
        
        Write-Host "User data files created successfully" -ForegroundColor Green
        Write-Host "Output directory: $((Resolve-Path $OutputDir).Path)" -ForegroundColor Yellow
        
    } else {
        Write-Host "Export failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Export failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "=== Export Complete ===" -ForegroundColor Green
