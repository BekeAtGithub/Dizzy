# Dizzy - Azure DevOps Security & Analysis Tool  .
# Main script that serves as the entry point when launched from the GUI.

param(
    [Parameter(Mandatory = $false)]
    [string]$EncodedOptions = ""
)

# Get the script's directory
$scriptPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}

# Import Core modules
$corePath = Join-Path -Path $scriptPath -ChildPath "Core"

# Import ADO-Dashboard module which will handle loading all dependencies
$dashboardPath = Join-Path -Path $corePath -ChildPath "ADO-Dashboard.ps1"

if (Test-Path $dashboardPath) {
    . $dashboardPath
    Write-Host "Successfully loaded ADO-Dashboard.ps1" -ForegroundColor Green
}
else {
    Write-Error "Critical module not found: ADO-Dashboard.ps1 at $dashboardPath"
    exit
}

# Decode options from GUI if provided
$options = $null
if (-not [string]::IsNullOrEmpty($EncodedOptions)) {
    try {
        $jsonString = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedOptions))
        $options = $jsonString | ConvertFrom-Json
        
        Write-Host "Received scan options from GUI:" -ForegroundColor Cyan
        $options | Format-List
    }
    catch {
        Write-Error "Failed to decode options: $_"
    }
}

# Function for interactive mode when no parameters are provided
function Start-InteractiveMode {
    # Show banner
    Write-Host @"
    
    ╔═══════════════════════════════════════════════════════════╗
    ║                       DIZZY                               ║
    ║           Azure DevOps Security & Analysis Tool           ║
    ╚═══════════════════════════════════════════════════════════╝
    
"@ -ForegroundColor Cyan

    # Check if we're already configured
    $config = Get-DizzyConfig
    
    if ($null -eq $config) {
        Write-Host "No configuration found. Let's set up Dizzy first." -ForegroundColor Yellow
        
        # Get Organization URL
        $orgUrl = Read-Host "Enter Azure DevOps Organization URL (e.g., https://dev.azure.com/your-organization)"
        
        # Get PAT token
        $pat = Read-Host "Enter Personal Access Token (will be stored securely)" -AsSecureString
        $patPlainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pat)
        )
        
        # Get Project
        $project = Read-Host "Enter Project Name"
        
        # Optional: Repository
        $repo = Read-Host "Enter Repository Name (optional, press Enter to skip)"
        
        # Optional: Pipeline ID
        $pipelineId = Read-Host "Enter Pipeline ID (optional, press Enter to skip)"
        
        # Create config folder
        $configFolder = Join-Path -Path $env:USERPROFILE -ChildPath ".dizzy"
        if (-not (Test-Path $configFolder)) {
            New-Item -Path $configFolder -ItemType Directory -Force | Out-Null
        }
        
        # Save configuration
        $configFile = Join-Path -Path $configFolder -ChildPath "config.json"
        $configData = @{
            OrganizationUrl = $orgUrl
            Project = $project
            Repository = $repo
            PipelineId = $pipelineId
            LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        $configData | ConvertTo-Json | Out-File -FilePath $configFile -Force
        
        # Store PAT in environment variable
        [Environment]::SetEnvironmentVariable("DIZZY_PAT", $patPlainText, "User")
        
        Write-Host "Configuration saved successfully!" -ForegroundColor Green
        
        # Test connection
        Write-Host "Testing connection to Azure DevOps..." -ForegroundColor Cyan
        if (Test-AzureDevOpsConnection) {
            Write-Host "Connection successful!" -ForegroundColor Green
        }
        else {
            Write-Host "Connection failed. Please check your organization URL and PAT." -ForegroundColor Red
            return
        }
    }
    else {
        Write-Host "Found existing configuration:" -ForegroundColor Cyan
        Write-Host "  Organization: $($config.OrganizationUrl)" -ForegroundColor White
        Write-Host "  Project: $($config.Project)" -ForegroundColor White
        if (-not [string]::IsNullOrWhiteSpace($config.Repository)) {
            Write-Host "  Repository: $($config.Repository)" -ForegroundColor White
        }
        if (-not [string]::IsNullOrWhiteSpace($config.PipelineId)) {
            Write-Host "  Pipeline ID: $($config.PipelineId)" -ForegroundColor White
        }
        
        # Test connection
        Write-Host "Testing connection to Azure DevOps..." -ForegroundColor Cyan
        if (Test-AzureDevOpsConnection) {
            Write-Host "Connection successful!" -ForegroundColor Green
        }
        else {
            Write-Host "Connection failed. You may need to update your PAT." -ForegroundColor Red
            
            $updatePat = Read-Host "Would you like to update your PAT? (Y/N)"
            if ($updatePat.ToUpper() -eq "Y") {
                $pat = Read-Host "Enter Personal Access Token (will be stored securely)" -AsSecureString
                $patPlainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pat)
                )
                
                # Store PAT in environment variable
                [Environment]::SetEnvironmentVariable("DIZZY_PAT", $patPlainText, "User")
                
                Write-Host "PAT updated successfully!" -ForegroundColor Green
                
                # Test connection again
                Write-Host "Testing connection to Azure DevOps..." -ForegroundColor Cyan
                if (Test-AzureDevOpsConnection) {
                    Write-Host "Connection successful!" -ForegroundColor Green
                }
                else {
                    Write-Host "Connection still failed. Please check your PAT and try again." -ForegroundColor Red
                    return
                }
            }
            else {
                Write-Host "Continuing with existing configuration." -ForegroundColor Yellow
            }
        }
    }
    
    # Ask for scan options
    Write-Host "Let's configure your scan options." -ForegroundColor Cyan
    
    # Components to scan
    $scanRepo = $true
    $scanPipeline = $true
    $scanBuild = $true
    $scanRelease = $true
    
    $askRepo = Read-Host "Scan repositories for secrets/API keys? (Y/N, default: Y)"
    if ($askRepo.ToUpper() -eq "N") { $scanRepo = $false }
    
    $askPipeline = Read-Host "Analyze pipeline definitions? (Y/N, default: Y)"
    if ($askPipeline.ToUpper() -eq "N") { $scanPipeline = $false }
    
    $askBuild = Read-Host "Analyze build history and artifacts? (Y/N, default: Y)"
    if ($askBuild.ToUpper() -eq "N") { $scanBuild = $false }
    
    $askRelease = Read-Host "Analyze release definitions and history? (Y/N, default: Y)"
    if ($askRelease.ToUpper() -eq "N") { $scanRelease = $false }
    
# Scan depth
$scanDepthOptions = @("Light", "Medium", "Deep")
$scanDepthPrompt = @"
Select scan depth:
  1: Light (Faster)
  2: Medium 
  3: Deep (Default - In Depth)
Enter choice (1-3):
"@
$scanDepthChoice = Read-Host $scanDepthPrompt

$scanDepth = "Deep" # Default
switch ($scanDepthChoice) {
    "1" { $scanDepth = "Light" }
    "2" { $scanDepth = "Medium" }
    "3" { $scanDepth = "Deep" }
    "" { $scanDepth = "Deep" }  # Empty input also selects the default
}
    
    # Days to look back
    $daysInput = Read-Host "Enter history period in days (default: 30)"
    $daysToLookBack = 30 # Default
    if (-not [string]::IsNullOrWhiteSpace($daysInput) -and [int]::TryParse($daysInput, [ref]$null)) {
        $daysToLookBack = [int]$daysInput
    }
    
    # Output folder
    $defaultOutput = Join-Path -Path $env:USERPROFILE -ChildPath "Dizzy-Results"
    $outputInput = Read-Host "Enter output folder path (default: $defaultOutput)"
    $outputFolder = $defaultOutput
    if (-not [string]::IsNullOrWhiteSpace($outputInput)) {
        $outputFolder = $outputInput
    }
    
    # Confirm settings
    Write-Host "Scan Configuration Summary:" -ForegroundColor Cyan
    Write-Host "  - Scan Repositories: $scanRepo" -ForegroundColor White
    Write-Host "  - Analyze Pipelines: $scanPipeline" -ForegroundColor White
    Write-Host "  - Analyze Builds: $scanBuild" -ForegroundColor White
    Write-Host "  - Analyze Releases: $scanRelease" -ForegroundColor White
    Write-Host "  - Scan Depth: $scanDepth" -ForegroundColor White
    Write-Host "  - History Period: $daysToLookBack days" -ForegroundColor White
    Write-Host "  - Output Folder: $outputFolder" -ForegroundColor White
    
    $confirm = Read-Host "Start scan with these settings? (Y/N, default: Y)"
    if ($confirm.ToUpper() -eq "N") {
        Write-Host "Scan canceled." -ForegroundColor Yellow
        return
    }
    
    # Start analysis
    Start-DizzyAnalysis -RepositoryName $config.Repository `
                       -PipelineId $config.PipelineId `
                       -ScanDepth $scanDepth `
                       -DaysToLookBack $daysToLookBack `
                       -SkipRepoScan:(-not $scanRepo) `
                       -SkipPipelineScan:(-not $scanPipeline) `
                       -SkipBuildScan:(-not $scanBuild) `
                       -SkipReleaseScan:(-not $scanRelease) `
                       -OutputFolder $outputFolder
}

# Main execution logic
if ($options) {
    # Run in non-interactive mode with options from GUI
    try {
        Write-Host "Starting Dizzy analysis with GUI options..." -ForegroundColor Cyan
        
        $skipRepoScan = -not $options.ScanRepositories
        $skipPipelineScan = -not $options.ScanPipelines
        $skipBuildScan = -not $options.ScanBuilds
        $skipReleaseScan = -not $options.ScanReleases
        
        # Get config for repository and pipeline info
        $config = Get-DizzyConfig
        $repoName = if ($config -and -not [string]::IsNullOrWhiteSpace($config.Repository)) { $config.Repository } else { "" }
        $pipelineId = if ($config -and -not [string]::IsNullOrWhiteSpace($config.PipelineId)) { $config.PipelineId } else { "" }
        
        # Start analysis
        Start-DizzyAnalysis -RepositoryName $repoName `
                           -PipelineId $pipelineId `
                           -ScanDepth $options.ScanDepth `
                           -DaysToLookBack $options.HistoryDays `
                           -SkipRepoScan:$skipRepoScan `
                           -SkipPipelineScan:$skipPipelineScan `
                           -SkipBuildScan:$skipBuildScan `
                           -SkipReleaseScan:$skipReleaseScan
    }
    catch {
        Write-Error "Error running analysis with GUI options: $_"
    }
}
else {
    # Run in interactive mode
    Start-InteractiveMode
}

# Keep window open if running directly
if ($Host.Name -eq "ConsoleHost") {
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}



