# Dizzy - Azure DevOps Analyzer
# Scan orchestration utility functions

# Improve path resolution to be more reliable
$scriptPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}

# Look for Config-Management.ps1 in the same directory as this script
$configModulePath = Join-Path -Path $scriptPath -ChildPath "Config-Management.ps1"

# Import config module if it exists
if (Test-Path $configModulePath) {
    . $configModulePath
} else {
    Write-Error "Required module not found: Config-Management.ps1 at $configModulePath"
    exit
}

# Core scan start function
function Start-DizzyScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Light", "Medium", "Deep")]
        [string]$ScanDepth = "Medium",
        
        [Parameter(Mandatory = $false)]
        [int]$HistoryDays = 30,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipRepoScan,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipPipelineScan,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipBuildScan,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipReleaseScan,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputFolder = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoOpenDashboard
    )
    
    Write-Host @"
    
    ╔═══════════════════════════════════════════════════════════╗
    ║                       DIZZY                               ║
    ║           Azure DevOps Security & Analysis Tool           ║
    ╚═══════════════════════════════════════════════════════════╝
    
"@ -ForegroundColor Cyan

    # Verify configuration and connection
    $config = Get-DizzyConfig
    if ($null -eq $config) {
        Write-Error "Configuration not found. Please run setup first."
        return $null
    }
    
    # Test connection
    Write-Host "Testing connection to Azure DevOps..." -ForegroundColor Cyan
    if (-not (Test-DizzyConnection)) {
        Write-Error "Failed to connect to Azure DevOps. Please check your configuration."
        return $null
    }
    
    Write-Host "Connected to $($config.OrganizationUrl)/$($config.Project)" -ForegroundColor Green
    
    # Test PAT permissions
    Write-Host "Verifying PAT permissions..." -ForegroundColor Cyan
    $permissionsCheck = Test-DizzyPatPermissions
    
    if (-not $permissionsCheck.Result) {
        Write-Warning "Your PAT may not have all required permissions:"
        foreach ($perm in $permissionsCheck.Permissions.GetEnumerator()) {
            $status = if ($perm.Value) { "✓" } else { "✗" }
            Write-Host "  $status $($perm.Key) access" -ForegroundColor $(if ($perm.Value) { "Green" } else { "Red" })
        }
        
        $continue = Read-Host "Continue anyway? (Y/N)"
        if ($continue -ne "Y") {
            Write-Host "Scan canceled. Please update your PAT with necessary permissions." -ForegroundColor Yellow
            return $null
        }
    }
    
    # Create output folder
    $resultFolder = New-DizzyOutputFolder -OutputFolder $OutputFolder
    if ($null -eq $resultFolder) {
        Write-Error "Failed to create output folder."
        return $null
    }
    
    # Start scan timer
    $startTime = Get-Date
    
    # Prepare scan info
    $scanInfo = @{
        OrganizationUrl = $config.OrganizationUrl
        Project = $config.Project
        Repository = $config.Repository
        PipelineId = $config.PipelineId
        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ScanDuration = 0
        ScanDepth = $ScanDepth
        HistoryDays = $HistoryDays
    }
    
    # Initialize the search paths for core modules
    $searchPaths = @(
        # First, try relative to this script's location
        (Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "Core"),
        # Then, try from the execution location
        (Join-Path -Path (Get-Location) -ChildPath "Core")
    )
    
    # Define core modules with their requirements
    $coreModules = @{
        "ADO-Dashboard.ps1" = $true  # Required
        "ADO-RepositoryScanner.ps1" = -not $SkipRepoScan
        "ADO-PipelineAnalyzer.ps1" = -not $SkipPipelineScan
        "ADO-BuildAnalyzer.ps1" = -not $SkipBuildScan
        "ADO-ReleaseAnalyzer.ps1" = -not $SkipReleaseScan
    }
    
    # Find and load core modules
    $moduleResults = @{}
    $corePath = $null
    
    # Try to find the core modules directory
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $testModule = Join-Path -Path $path -ChildPath "ADO-Dashboard.ps1"
            if (Test-Path $testModule) {
                $corePath = $path
                break
            }
        }
    }
    
    if ($null -eq $corePath) {
        Write-Error "Could not locate Core modules directory. Please make sure the Core directory exists with required modules."
        return $null
    }
    
    Write-Host "Found Core modules at: $corePath" -ForegroundColor Green
    
    # Load all modules from the core path
    foreach ($moduleName in $coreModules.Keys) {
        $modulePath = Join-Path -Path $corePath -ChildPath $moduleName
        $isRequired = $coreModules[$moduleName]
        
        if (Test-Path $modulePath) {
            # Import the module
            try {
                . $modulePath
                $moduleResults[$moduleName] = $true
                Write-Host "Loaded module: $moduleName" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to load module $moduleName : $_"
                if ($isRequired) {
                    Write-Error "Required module failed to load. Aborting scan."
                    return $null
                }
                $moduleResults[$moduleName] = $false
            }
        }
        else {
            Write-Warning "Module not found: $moduleName at $modulePath"
            if ($isRequired) {
                Write-Error "Required module not found. Aborting scan."
                return $null
            }
            $moduleResults[$moduleName] = $false
        }
    }
    
    # Search for HTML modules
    $htmlPath = Join-Path -Path (Split-Path -Parent $corePath) -ChildPath "HTML"
    
    if (Test-Path $htmlPath) {
        Write-Host "Found HTML modules at: $htmlPath" -ForegroundColor Green
        
        # Load common HTML modules first
        $htmlModules = @(
            "Dashboard-HTML.ps1",
            "Dashboard-HTML-Details.ps1",
            "Security-HTML.ps1",
            "Security-HTML-Stats.ps1",
            "Security-HTML-Sections.ps1"
        )
        
        foreach ($htmlModule in $htmlModules) {
            $htmlModulePath = Join-Path -Path $htmlPath -ChildPath $htmlModule
            if (Test-Path $htmlModulePath) {
                try {
                    . $htmlModulePath
                    Write-Host "Loaded HTML module: $htmlModule" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to load HTML module $htmlModule : $_"
                }
            }
        }
    }
    else {
        Write-Warning "HTML modules directory not found at: $htmlPath"
    }
    
    # Initialize result object
    $scanResults = @{
        ScanInfo = $scanInfo
        RepositoryResults = $null
        PipelineResults = $null
        BuildResults = $null
        ReleaseResults = $null
    }
    
    # Run repository scan if module is loaded and not skipped
    if ($moduleResults["ADO-RepositoryScanner.ps1"] -and -not $SkipRepoScan) {
        if (Get-Command -Name Start-RepositoryScan -ErrorAction SilentlyContinue) {
            Write-Host "Starting repository scan with $ScanDepth depth..." -ForegroundColor Cyan
            try {
                $repoResults = Start-RepositoryScan -RepositoryName $config.Repository -ScanDepth $ScanDepth
                $scanResults.RepositoryResults = $repoResults
                
                # Generate standalone report if HTML module available
                if (Get-Command -Name New-RepositoryScanHtml -ErrorAction SilentlyContinue) {
                    $repoHtmlPath = New-RepositoryScanHtml -RepositoryResults $repoResults -OutputFolder $resultFolder
                    Write-Host "Repository scan report generated: $repoHtmlPath" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Repository scan failed: $_"
            }
        }
        else {
            Write-Warning "Repository scan function not available."
        }
    }
    
    # Run pipeline scan if module is loaded and not skipped
    if ($moduleResults["ADO-PipelineAnalyzer.ps1"] -and -not $SkipPipelineScan) {
        if (Get-Command -Name Start-PipelineAnalysis -ErrorAction SilentlyContinue) {
            Write-Host "Starting pipeline analysis..." -ForegroundColor Cyan
            try {
                $pipelineResults = Start-PipelineAnalysis -PipelineId $config.PipelineId -IncludeRuns
                $scanResults.PipelineResults = $pipelineResults
                
                # Generate standalone report if HTML module available
                if (Get-Command -Name New-PipelineAnalysisHtml -ErrorAction SilentlyContinue) {
                    $pipelineHtmlPath = New-PipelineAnalysisHtml -PipelineResults $pipelineResults -OutputFolder $resultFolder
                    Write-Host "Pipeline analysis report generated: $pipelineHtmlPath" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Pipeline analysis failed: $_"
            }
        }
        else {
            Write-Warning "Pipeline analysis function not available."
        }
    }
    
    # Run build scan if module is loaded and not skipped
    if ($moduleResults["ADO-BuildAnalyzer.ps1"] -and -not $SkipBuildScan) {
        if (Get-Command -Name Start-BuildAnalysis -ErrorAction SilentlyContinue) {
            Write-Host "Starting build analysis..." -ForegroundColor Cyan
            try {
                $buildResults = Start-BuildAnalysis -DaysToLookBack $HistoryDays
                $scanResults.BuildResults = $buildResults
                
                # Generate standalone report if HTML module available
                if (Get-Command -Name New-BuildAnalysisHtml -ErrorAction SilentlyContinue) {
                    $buildHtmlPath = New-BuildAnalysisHtml -BuildResults $buildResults -OutputFolder $resultFolder
                    Write-Host "Build analysis report generated: $buildHtmlPath" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Build analysis failed: $_"
            }
        }
        else {
            Write-Warning "Build analysis function not available."
        }
    }
    
    # Run release scan if module is loaded and not skipped
    if ($moduleResults["ADO-ReleaseAnalyzer.ps1"] -and -not $SkipReleaseScan) {
        if (Get-Command -Name Start-ReleaseAnalysis -ErrorAction SilentlyContinue) {
            Write-Host "Starting release analysis..." -ForegroundColor Cyan
            try {
                $releaseResults = Start-ReleaseAnalysis -DaysToLookBack $HistoryDays
                $scanResults.ReleaseResults = $releaseResults
                
                # Generate standalone report if HTML module available
                if (Get-Command -Name New-ReleaseAnalysisHtml -ErrorAction SilentlyContinue) {
                    $releaseHtmlPath = New-ReleaseAnalysisHtml -ReleaseResults $releaseResults -OutputFolder $resultFolder
                    Write-Host "Release analysis report generated: $releaseHtmlPath" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Release analysis failed: $_"
            }
        }
        else {
            Write-Warning "Release analysis function not available."
        }
    }
    
    # Generate security report if we have any results and the function exists
    if (Get-Command -Name New-SecurityOverviewHtml -ErrorAction SilentlyContinue) {
        if ($scanResults.RepositoryResults -or $scanResults.PipelineResults -or 
            $scanResults.BuildResults -or $scanResults.ReleaseResults) {
            
            Write-Host "Generating security overview report..." -ForegroundColor Cyan
            $securityHtmlPath = New-SecurityOverviewHtml -RepoResults $scanResults.RepositoryResults `
                                                      -PipelineResults $scanResults.PipelineResults `
                                                      -BuildResults $scanResults.BuildResults `
                                                      -ReleaseResults $scanResults.ReleaseResults `
                                                      -OutputFolder $resultFolder
            
            Write-Host "Security overview report generated: $securityHtmlPath" -ForegroundColor Green
        }
    }
    
    # Generate dashboard if the function exists
    $dashboardPath = $null
    if (Get-Command -Name New-DashboardHtml -ErrorAction SilentlyContinue) {
        Write-Host "Generating main dashboard..." -ForegroundColor Cyan
        try {
            # Calculate scan duration
            $endTime = Get-Date
            $scanDuration = ($endTime - $startTime).TotalMinutes
            $scanResults.ScanInfo.ScanDuration = [math]::Round($scanDuration, 2)
            
            $dashboardPath = New-DashboardHtml -ScanInfo $scanResults.ScanInfo `
                                              -RepoResults $scanResults.RepositoryResults `
                                              -PipelineResults $scanResults.PipelineResults `
                                              -BuildResults $scanResults.BuildResults `
                                              -ReleaseResults $scanResults.ReleaseResults `
                                              -OutputPath (Join-Path -Path $resultFolder -ChildPath "Dizzy-Dashboard.html")
            
            Write-Host "Main dashboard generated: $dashboardPath" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to generate dashboard: $_"
        }
    }
    
    # Calculate and display scan duration
    $endTime = Get-Date
    $scanDuration = ($endTime - $startTime).TotalMinutes
    Write-Host "Scan completed in $([math]::Round($scanDuration, 2)) minutes." -ForegroundColor Green
    
    # Open dashboard in browser if available and requested
    if ($dashboardPath -and (Test-Path $dashboardPath) -and -not $NoOpenDashboard) {
        Write-Host "Opening dashboard in browser..." -ForegroundColor Cyan
        Start-Process $dashboardPath
    }
    
    return @{
        Results = $scanResults
        OutputFolder = $resultFolder
        DashboardPath = $dashboardPath
        Duration = $scanDuration
    }
}

# Rest of the script remains the same

# Function to generate just a security report from existing scan results
function New-DizzySecurityReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScanResults,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputFolder = ""
    )
    
    # Validate scan results
    if ($null -eq $ScanResults -or $null -eq $ScanResults.ScanInfo) {
        Write-Error "Invalid scan results provided."
        return $null
    }
    
    # Create output folder if not specified
    if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
        $resultFolder = New-DizzyOutputFolder
        if ($null -eq $resultFolder) {
            Write-Error "Failed to create output folder."
            return $null
        }
    }
    else {
        $resultFolder = $OutputFolder
        if (-not (Test-Path -Path $resultFolder)) {
            New-Item -Path $resultFolder -ItemType Directory -Force | Out-Null
        }
    }
    
    # Check if security report function exists
    if (-not (Get-Command -Name New-SecurityOverviewHtml -ErrorAction SilentlyContinue)) {
        Write-Error "Security report function not available. Make sure HTML/Security-HTML.ps1 is loaded."
        return $null
    }
    
    # Generate security report
    Write-Host "Generating security overview report from existing scan results..." -ForegroundColor Cyan
    
    try {
        $securityHtmlPath = New-SecurityOverviewHtml -RepoResults $ScanResults.RepositoryResults `
                                                  -PipelineResults $ScanResults.PipelineResults `
                                                  -BuildResults $ScanResults.BuildResults `
                                                  -ReleaseResults $ScanResults.ReleaseResults `
                                                  -OutputFolder $resultFolder
        
        Write-Host "Security overview report generated: $securityHtmlPath" -ForegroundColor Green
        return $securityHtmlPath
    }
    catch {
        Write-Error "Failed to generate security report: $_"
        return $null
    }
}

# Function to export scan results for offline analysis
function Export-DizzyScanResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScanResults,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputFolder = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeSensitiveData
    )
    
    # Validate scan results
    if ($null -eq $ScanResults -or $null -eq $ScanResults.ScanInfo) {
        Write-Error "Invalid scan results provided."
        return $null
    }
    
    # Create output folder if not specified
    if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
        $resultFolder = New-DizzyOutputFolder
        if ($null -eq $resultFolder) {
            Write-Error "Failed to create output folder."
            return $null
        }
    }
    else {
        $resultFolder = $OutputFolder
        if (-not (Test-Path -Path $resultFolder)) {
            New-Item -Path $resultFolder -ItemType Directory -Force | Out-Null
        }
    }
    
    # Create a safe copy of the scan results
    $exportResults = [PSCustomObject]@{
        ScanInfo = $ScanResults.ScanInfo
        RepositoryResults = $null
        PipelineResults = $null
        BuildResults = $null
        ReleaseResults = $null
    }
    
    # Process repository results - mask secrets if not including sensitive data
    if ($ScanResults.RepositoryResults) {
        $exportRepoResults = @()
        
        foreach ($repo in $ScanResults.RepositoryResults) {
            $exportRepo = [PSCustomObject]@{
                RepositoryName = $repo.RepositoryName
                RepositoryId = $repo.RepositoryId
                DefaultBranch = $repo.DefaultBranch
                Url = $repo.Url
                ScanDate = $repo.ScanDate
                ScannedFilesCount = $repo.ScannedFilesCount
                TotalFilesCount = $repo.TotalFilesCount
                Findings = @()
            }
            
            if ($repo.Findings) {
                foreach ($finding in $repo.Findings) {
                    $exportFinding = [PSCustomObject]@{
                        FilePath = $finding.FilePath
                        LineNumber = $finding.LineNumber
                        PatternName = $finding.PatternName
                        Context = $finding.Context
                        Severity = "High"
                    }
                    
                    # Mask sensitive data if requested
                    if (-not $IncludeSensitiveData) {
                        $exportFinding.Context = $exportFinding.Context -replace '(\w+://[^@]+:).+?(@.+)', '$1*****$2'
                        $exportFinding.Context = $exportFinding.Context -replace '(\w+\s*[=:]\s*["\'']).+?(["\'']\s*)', '$1*****$2'
                    }
                    
                    $exportRepo.Findings += $exportFinding
                }
            }
            
            $exportRepoResults += $exportRepo
        }
        
        $exportResults.RepositoryResults = $exportRepoResults
    }
    
    # Process pipeline results
    if ($ScanResults.PipelineResults) {
        $exportResults.PipelineResults = $ScanResults.PipelineResults
    }
    
    # Process build results
    if ($ScanResults.BuildResults) {
        $exportResults.BuildResults = $ScanResults.BuildResults
    }
    
    # Process release results
    if ($ScanResults.ReleaseResults) {
        $exportResults.ReleaseResults = $ScanResults.ReleaseResults
    }
    
    # Export to JSON file
    $exportFilePath = Join-Path -Path $resultFolder -ChildPath "DizzyScanResults.json"
    
    try {
        $exportResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportFilePath -Force
        Write-Host "Scan results exported to: $exportFilePath" -ForegroundColor Green
        return $exportFilePath
    }
    catch {
        Write-Error "Failed to export scan results: $_"
        return $null
    }
}

# Export functions
#Export-ModuleMember -Function Start-DizzyScan, New-DizzySecurityReport, Export-DizzyScanResults
