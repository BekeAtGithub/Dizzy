# Dizzy - Azure DevOps Analyzer
# Main dashboard coordinator for analysis and HTML generation

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$corePath = $scriptPath
$htmlPath = Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "HTML"

# Import authentication module
$authModulePath = Join-Path -Path $corePath -ChildPath "ADO-Authentication.ps1"
. $authModulePath

# Import analysis modules
$repoScannerPath = Join-Path -Path $corePath -ChildPath "ADO-RepositoryScanner.ps1"
$pipelineAnalyzerPath = Join-Path -Path $corePath -ChildPath "ADO-PipelineAnalyzer.ps1"
$buildAnalyzerPath = Join-Path -Path $corePath -ChildPath "ADO-BuildAnalyzer.ps1"
$releaseAnalyzerPath = Join-Path -Path $corePath -ChildPath "ADO-ReleaseAnalyzer.ps1"

# Import HTML generation modules
$dashboardHtmlPath = Join-Path -Path $htmlPath -ChildPath "Dashboard-HTML.ps1"
$dashboardDetailsHtmlPath = Join-Path -Path $htmlPath -ChildPath "Dashboard-HTML-Details.ps1"

# Import modules if they exist
$modulesToCheck = @(
    @{ Path = $repoScannerPath; Name = "Repository Scanner"; Required = $false },
    @{ Path = $pipelineAnalyzerPath; Name = "Pipeline Analyzer"; Required = $false },
    @{ Path = $buildAnalyzerPath; Name = "Build Analyzer"; Required = $false },
    @{ Path = $releaseAnalyzerPath; Name = "Release Analyzer"; Required = $false },
    @{ Path = $dashboardHtmlPath; Name = "Dashboard HTML Generator"; Required = $true },
    @{ Path = $dashboardDetailsHtmlPath; Name = "Dashboard Details HTML Generator"; Required = $true }
)

foreach ($module in $modulesToCheck) {
    if (Test-Path $module.Path) {
        . $module.Path
        Write-Host "Imported module: $($module.Name)" -ForegroundColor Green
    }
    else {
        if ($module.Required) {
            Write-Error "Required module not found: $($module.Name) at $($module.Path)"
            exit
        }
        else {
            Write-Warning "Optional module not found: $($module.Name) at $($module.Path)"
        }
    }
}

# Function to run all analysis types
function Start-AllAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryName = "",
        
        [Parameter(Mandatory = $false)]
        [string]$PipelineId = "",
        
        [Parameter(Mandatory = $false)]
        [string]$ScanDepth = "Medium",
        
        [Parameter(Mandatory = $false)]
        [int]$DaysToLookBack = 30,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxFilesPerRepo = 1000,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeRepoScan = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludePipelineScan = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeBuildScan = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeReleaseScan = $true
    )
    
    Write-Host "Starting comprehensive Azure DevOps analysis..." -ForegroundColor Cyan
    
    # Test connection first
    if (-not (Test-AzureDevOpsConnection)) {
        Write-Error "Failed to connect to Azure DevOps. Please check your configuration."
        return $null
    }
    
    $config = Get-DizzyConfig
    if ($null -eq $config) {
        Write-Error "Failed to get configuration. Please run setup first."
        return $null
    }
    
    $startTime = Get-Date
    $results = @{
        ScanInfo = @{
            OrganizationUrl = $config.OrganizationUrl
            Project = $config.Project
            Repository = $RepositoryName
            PipelineId = $PipelineId
            ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ScanDuration = 0
            ScanDepth = $ScanDepth
            HistoryDays = $DaysToLookBack
        }
        RepositoryResults = $null
        PipelineResults = $null
        BuildResults = $null
        ReleaseResults = $null
    }
    
    # Run Repository Scanner if available and enabled
    if ((Get-Command -Name Start-RepositoryScan -ErrorAction SilentlyContinue) -and $IncludeRepoScan) {
        Write-Host "Starting repository scan..." -ForegroundColor Yellow
        try {
            $repoResults = Start-RepositoryScan -RepositoryName $RepositoryName -ScanDepth $ScanDepth -MaxFilesPerRepo $MaxFilesPerRepo
            if ($repoResults) {
                $results.RepositoryResults = $repoResults
                Write-Host "Repository scan completed successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Error during repository scan: $_"
        }
    }
    
    # Run Pipeline Analyzer if available and enabled
    if ((Get-Command -Name Start-PipelineAnalysis -ErrorAction SilentlyContinue) -and $IncludePipelineScan) {
        Write-Host "Starting pipeline analysis..." -ForegroundColor Yellow
        try {
            $pipelineResults = Start-PipelineAnalysis -PipelineId $PipelineId -IncludeRuns
            if ($pipelineResults) {
                $results.PipelineResults = $pipelineResults
                Write-Host "Pipeline analysis completed successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Error during pipeline analysis: $_"
        }
    }
    
    # Run Build Analyzer if available and enabled
    if ((Get-Command -Name Start-BuildAnalysis -ErrorAction SilentlyContinue) -and $IncludeBuildScan) {
        Write-Host "Starting build analysis..." -ForegroundColor Yellow
        try {
            $buildResults = Start-BuildAnalysis -DaysToLookBack $DaysToLookBack
            if ($buildResults) {
                $results.BuildResults = $buildResults
                Write-Host "Build analysis completed successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Error during build analysis: $_"
        }
    }
    
    # Run Release Analyzer if available and enabled
    if ((Get-Command -Name Start-ReleaseAnalysis -ErrorAction SilentlyContinue) -and $IncludeReleaseScan) {
        Write-Host "Starting release analysis..." -ForegroundColor Yellow
        try {
            $releaseResults = Start-ReleaseAnalysis
            if ($releaseResults) {
                $results.ReleaseResults = $releaseResults
                Write-Host "Release analysis completed successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Error during release analysis: $_"
        }
    }
    
    # Calculate scan duration
    $endTime = Get-Date
    $scanDuration = ($endTime - $startTime).TotalMinutes
    $results.ScanInfo.ScanDuration = [math]::Round($scanDuration, 2)
    
    Write-Host "All analysis completed in $($results.ScanInfo.ScanDuration) minutes." -ForegroundColor Green
    
    return $results
}

# Function to generate dashboard
function New-AnalysisDashboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$AnalysisResults,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputFolder = ""
    )
    
    Write-Host "Generating analysis dashboard..." -ForegroundColor Cyan
    
    # Check if New-DashboardHtml function exists
    if (-not (Get-Command -Name New-DashboardHtml -ErrorAction SilentlyContinue)) {
        Write-Error "Dashboard HTML generator not found. Make sure HTML modules are loaded."
        return $null
    }
    
    # Determine output folder
    if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
        $OutputFolder = Join-Path -Path $env:USERPROFILE -ChildPath "Dizzy-Results"
    }
    
    # Initialize HTML output
    $outputPath = Initialize-HtmlOutput -OutputFolder $OutputFolder -DashboardName "Dizzy-Dashboard"
    
    # Generate dashboard HTML
    $dashboardPath = New-DashboardHtml -ScanInfo $AnalysisResults.ScanInfo `
                                      -RepoResults $AnalysisResults.RepositoryResults `
                                      -PipelineResults $AnalysisResults.PipelineResults `
                                      -BuildResults $AnalysisResults.BuildResults `
                                      -ReleaseResults $AnalysisResults.ReleaseResults `
                                      -OutputPath $outputPath
    
    if (Test-Path $dashboardPath) {
        Write-Host "Dashboard generated successfully at: $dashboardPath" -ForegroundColor Green
        
        # Try to open the dashboard in the default browser
        try {
            Start-Process $dashboardPath
        }
        catch {
            Write-Warning "Could not open dashboard in browser: $_"
        }
    }
    else {
        Write-Error "Failed to generate dashboard at: $dashboardPath"
    }
    
    return $dashboardPath
}

# Main function to run everything
function Start-DizzyAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryName = "",
        
        [Parameter(Mandatory = $false)]
        [string]$PipelineId = "",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Light", "Medium", "Deep")]
        [string]$ScanDepth = "Medium",
        
        [Parameter(Mandatory = $false)]
        [int]$DaysToLookBack = 30,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxFilesPerRepo = 1000,
        
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
    
    # Show banner
    Write-Host @"
    
    ╔═══════════════════════════════════════════════════════════╗
    ║                   DIZZY ANALYZER                         ║
    ║           Azure DevOps Security & Performance            ║
    ╚═══════════════════════════════════════════════════════════╝
    
"@ -ForegroundColor Cyan
    
    # Welcome message with scan details
    Write-Host "Starting Dizzy analysis with the following parameters:" -ForegroundColor Cyan
    Write-Host "  - Scan Depth: $ScanDepth" -ForegroundColor White
    Write-Host "  - History Period: $DaysToLookBack days" -ForegroundColor White
    
    if (-not [string]::IsNullOrWhiteSpace($RepositoryName)) {
        Write-Host "  - Repository Filter: $RepositoryName" -ForegroundColor White
    }
    
    if (-not [string]::IsNullOrWhiteSpace($PipelineId)) {
        Write-Host "  - Pipeline ID Filter: $PipelineId" -ForegroundColor White
    }
    
    Write-Host "  - Scan Components:" -ForegroundColor White
    Write-Host "      - Repositories: $(-not $SkipRepoScan)" -ForegroundColor White
    Write-Host "      - Pipelines: $(-not $SkipPipelineScan)" -ForegroundColor White
    Write-Host "      - Builds: $(-not $SkipBuildScan)" -ForegroundColor White
    Write-Host "      - Releases: $(-not $SkipReleaseScan)" -ForegroundColor White
    
    Write-Host
    Write-Host "Verifying connection to Azure DevOps..."
    
    # Check configuration and connection
    $config = Get-DizzyConfig
    if ($null -eq $config) {
        Write-Error "Configuration not found. Please run setup first."
        return
    }
    
    if (-not (Test-AzureDevOpsConnection)) {
        Write-Error "Failed to connect to Azure DevOps. Please check your configuration."
        return
    }
    
    Write-Host "Connected to $($config.OrganizationUrl)/$($config.Project)" -ForegroundColor Green
    
    # Run the analysis
    $analysisResults = Start-AllAnalysis -RepositoryName $RepositoryName `
                                       -PipelineId $PipelineId `
                                       -ScanDepth $ScanDepth `
                                       -DaysToLookBack $DaysToLookBack `
                                       -MaxFilesPerRepo $MaxFilesPerRepo `
                                       -IncludeRepoScan:(-not $SkipRepoScan) `
                                       -IncludePipelineScan:(-not $SkipPipelineScan) `
                                       -IncludeBuildScan:(-not $SkipBuildScan) `
                                       -IncludeReleaseScan:(-not $SkipReleaseScan)
    
    if ($null -eq $analysisResults) {
        Write-Error "Analysis failed to complete."
        return
    }
    
    # Generate dashboard
    $dashboardPath = New-AnalysisDashboard -AnalysisResults $analysisResults -OutputFolder $OutputFolder
    
    if ($null -eq $dashboardPath) {
        Write-Error "Failed to generate dashboard."
        return
    }
    
    # Summary of findings
    Write-Host
    Write-Host "Analysis Summary:" -ForegroundColor Cyan
    
    # Repository findings
    if ($analysisResults.RepositoryResults) {
        $reposWithFindings = $analysisResults.RepositoryResults | Where-Object { $_.Findings -and $_.Findings.Count -gt 0 }
        $totalFindings = 0
        $reposWithFindings | ForEach-Object { $totalFindings += $_.Findings.Count }
        
        if ($totalFindings -gt 0) {
            Write-Host "  - Found $totalFindings secrets/sensitive data in $($reposWithFindings.Count) repositories." -ForegroundColor Red
        }
        else {
            Write-Host "  - No secrets or sensitive data found in repositories." -ForegroundColor Green
        }
    }
    
    # Pipeline findings
    if ($analysisResults.PipelineResults) {
        $pipelinesWithIssues = $analysisResults.PipelineResults | Where-Object { $_.Findings -and $_.Findings.Count -gt 0 }
        $totalIssues = 0
        $pipelinesWithIssues | ForEach-Object { $totalIssues += $_.Findings.Count }
        
        if ($totalIssues -gt 0) {
            Write-Host "  - Found $totalIssues issues in $($pipelinesWithIssues.Count) pipelines." -ForegroundColor Yellow
        }
        else {
            Write-Host "  - No issues found in pipelines." -ForegroundColor Green
        }
    }
    
    # Build findings
    if ($analysisResults.BuildResults) {
        $buildSecurityIssues = 0
        foreach ($build in $analysisResults.BuildResults) {
            if ($build.SecurityAnalysis -and $build.SecurityAnalysis.SecurityIssues) {
                $buildSecurityIssues += $build.SecurityAnalysis.SecurityIssues.Count
            }
        }
        
        if ($buildSecurityIssues -gt 0) {
            Write-Host "  - Found $buildSecurityIssues security issues in build definitions." -ForegroundColor Yellow
        }
        else {
            Write-Host "  - No security issues found in build definitions." -ForegroundColor Green
        }
    }
    
    # Release findings
    if ($analysisResults.ReleaseResults) {
        $releaseSecurityIssues = 0
        foreach ($release in $analysisResults.ReleaseResults) {
            if ($release.SecurityAnalysis -and $release.SecurityAnalysis.SecurityIssues) {
                $releaseSecurityIssues += $release.SecurityAnalysis.SecurityIssues.Count
            }
        }
        
        if ($releaseSecurityIssues -gt 0) {
            Write-Host "  - Found $releaseSecurityIssues security issues in release definitions." -ForegroundColor Yellow
        }
        else {
            Write-Host "  - No security issues found in release definitions." -ForegroundColor Green
        }
    }
    
    Write-Host
    Write-Host "Dashboard generated at: $dashboardPath" -ForegroundColor Green
    Write-Host "Analysis completed in $($analysisResults.ScanInfo.ScanDuration) minutes." -ForegroundColor Green
    
    # Open dashboard if requested
    if (-not $NoOpenDashboard) {
        Write-Host "Opening dashboard in default browser..." -ForegroundColor Cyan
        Start-Process $dashboardPath
    }
}

# Export functions
Export-ModuleMember -Function Start-DizzyAnalysis, Start-AllAnalysis, New-AnalysisDashboard