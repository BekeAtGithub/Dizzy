# Dizzy - Azure DevOps Analyzer
# Main dashboard HTML generator - Part 1

# Script variables
$script:dashboardHtmlPath = ""
$script:outputFolder = ""

# Function to initialize the HTML output folder
function Initialize-HtmlOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,
        
        [Parameter(Mandatory = $false)]
        [string]$DashboardName = "Dizzy-Dashboard"
    )
    
    # Create output folder if it doesn't exist
    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
        Write-Host "Created output folder: $OutputFolder" -ForegroundColor Green
    }
    
    # Set global variables
    $script:outputFolder = $OutputFolder
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:dashboardHtmlPath = Join-Path -Path $OutputFolder -ChildPath "$DashboardName-$timestamp.html"
    
    # Return the dashboard path
    return $script:dashboardHtmlPath
}

# Add this to Dashboard-HTML.ps1 to replace the existing Get-DashboardHtmlHeader function
function Get-DashboardHtmlHeader {
    # Create HTML header
    $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dizzy - Azure DevOps Analyzer Dashboard</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 0; color: #333; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        header { background-color: #0078d4; color: white; padding: 20px; margin-bottom: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { margin: 0; font-size: 2em; }
        h2 { color: #0078d4; margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
        h3 { color: #0078d4; }
        .summary-section { background-color: white; border-radius: 5px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .scan-info { display: flex; flex-wrap: wrap; }
        .scan-info-item { flex: 1; min-width: 200px; margin: 5px; }
        .dashboard-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; margin-bottom: 20px; }
        .panel { background-color: white; border-radius: 5px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .panel-full { grid-column: span 2; }
        .stat-value { font-size: 2em; font-weight: bold; color: #0078d4; }
        .stat-label { font-size: 0.9em; color: #666; }
        .stat-container { display: flex; flex-wrap: wrap; }
        .stat-item { flex: 1; min-width: 120px; margin: 10px; text-align: center; }
        .quick-links { margin-top: 20px; }
        .quick-link-button { display: inline-block; background-color: #0078d4; color: white; padding: 10px 15px; margin: 5px; text-decoration: none; border-radius: 5px; transition: background-color 0.3s; }
        .quick-link-button:hover { background-color: #005a9e; }
        .warning { background-color: #fff4e5; border-left: 4px solid #ff8c00; padding: 10px 15px; margin: 10px 0; }
        .error { background-color: #fde7e9; border-left: 4px solid #d13438; padding: 10px 15px; margin: 10px 0; }
        .success { background-color: #dff6dd; border-left: 4px solid #107c10; padding: 10px 15px; margin: 10px 0; }
        .info { background-color: #f0f8ff; border-left: 4px solid #0078d4; padding: 10px 15px; margin: 10px 0; }
        .status-badge { display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; }
        .status-high { background-color: #fde7e9; color: #d13438; }
        .status-medium { background-color: #fff4e5; color: #ff8c00; }
        .status-low { background-color: #dff6dd; color: #107c10; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th { background-color: #f0f0f0; text-align: left; padding: 10px; }
        td { padding: 10px; border-bottom: 1px solid #eee; }
        tr:hover { background-color: #f9f9f9; }
        .timestamp { font-style: italic; color: #666; margin-top: 10px; font-size: 0.9em; }
        .footer { text-align: center; margin-top: 40px; padding: 20px; color: #666; font-size: 0.9em; }
        #filters { margin: 20px 0; }
        .filter-button { background-color: #f0f0f0; border: none; padding: 8px 15px; margin-right: 5px; border-radius: 5px; cursor: pointer; }
        .filter-button.active { background-color: #0078d4; color: white; }
        .hidden { display: none; }
    </style>
    <script>
        // JavaScript functions
        function filterByComponent(component) {
            var panels = document.querySelectorAll('.component-panel');
            var buttons = document.querySelectorAll('.filter-button');
            
            // Update active button
            buttons.forEach(function(btn) {
                if (btn.getAttribute('data-component') === component) {
                    btn.classList.add('active');
                } else {
                    btn.classList.remove('active');
                }
            });
            
            // Show/hide panels
            panels.forEach(function(panel) {
                if (component === 'all' || panel.getAttribute('data-component') === component) {
                    panel.classList.remove('hidden');
                } else {
                    panel.classList.add('hidden');
                }
            });
        }
        
        function toggleDetails(id) {
            var element = document.getElementById(id);
            if (element.style.display === 'none' || element.style.display === '') {
                element.style.display = 'block';
            } else {
                element.style.display = 'none';
            }
        }
    </script>
</head>
<body>
    <header>
        <div class="container">
            <h1>Dizzy - Azure DevOps Analyzer</h1>
            <p>Security and performance analysis dashboard for Azure DevOps projects</p>
        </div>
    </header>
    
    <div class="container">
"@

    return $htmlHeader
}
# Helper function to create HTML header and CSS styles
# Helper function to create HTML header and CSS styles
function New-DashboardSummaryHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScanInfo,
        
        [Parameter(Mandatory = $false)]
        [object]$RepoResults,
        
        [Parameter(Mandatory = $false)]
        [object]$PipelineResults,
        
        [Parameter(Mandatory = $false)]
        [object]$BuildResults,
        
        [Parameter(Mandatory = $false)]
        [object]$ReleaseResults
    )
    
    # Get HTML header
    $htmlContent = Get-DashboardHtmlHeader
    
    # Add Scan Summary Section
    $htmlContent += @"
        <div class="summary-section">
            <h2>Scan Summary</h2>
            <div class="scan-info">
                <div class="scan-info-item">
                    <strong>Organization:</strong> $($ScanInfo.OrganizationUrl)<br/>
                    <strong>Project:</strong> $($ScanInfo.Project)<br/>
                    $(if ($ScanInfo.Repository) { "<strong>Repository:</strong> $($ScanInfo.Repository)<br/>" })
                    $(if ($ScanInfo.PipelineId) { "<strong>Pipeline ID:</strong> $($ScanInfo.PipelineId)<br/>" })
                </div>
                <div class="scan-info-item">
                    <strong>Scan Date:</strong> $($ScanInfo.ScanDate)<br/>
                    <strong>Scan Duration:</strong> $($ScanInfo.ScanDuration) minutes<br/>
                    <strong>Scan Depth:</strong> $($ScanInfo.ScanDepth)<br/>
                    <strong>History Period:</strong> $($ScanInfo.HistoryDays) days
                </div>
            </div>
        </div>
        
        <div id="filters">
            <button class="filter-button active" data-component="all" onclick="filterByComponent('all')">All Components</button>
            <button class="filter-button" data-component="repo" onclick="filterByComponent('repo')">Repositories</button>
            <button class="filter-button" data-component="pipeline" onclick="filterByComponent('pipeline')">Pipelines</button>
            $(if ($BuildResults) { "<button class=`"filter-button`" data-component=`"build`" onclick=`"filterByComponent('build')`">Builds</button>" })
            $(if ($ReleaseResults) { "<button class=`"filter-button`" data-component=`"release`" onclick=`"filterByComponent('release')`">Releases</button>" })
        </div>
        
        <div class="dashboard-grid">
"@

    # Add Overview Panel
    $htmlContent += @"
            <div class="panel component-panel" data-component="all">
                <h3>Security Overview</h3>
                <div class="stat-container">
"@

    # Calculate security stats
    $securityStats = @{
        "High" = 0
        "Medium" = 0
        "Low" = 0
        "Total" = 0
    }
    
    # Count findings from repo scans
    if ($RepoResults) {
        foreach ($repo in $RepoResults) {
            if ($repo.Findings) {
                foreach ($finding in $repo.Findings) {
                    $securityStats.Total++
                    $securityStats.High++  # Consider all repo findings as high severity
                }
            }
        }
    }
    
    # Count issues from pipeline analysis
    if ($PipelineResults) {
        foreach ($pipeline in $PipelineResults) {
            if ($pipeline.Findings) {
                foreach ($finding in $pipeline.Findings) {
                    $securityStats.Total++
                    
                    switch ($finding.Severity) {
                        "High" { $securityStats.High++ }
                        "Medium" { $securityStats.Medium++ }
                        "Low" { $securityStats.Low++ }
                        default { $securityStats.Low++ }
                    }
                }
            }
        }
    }
    
    # Count issues from release security analysis
    if ($ReleaseResults) {
        foreach ($release in $ReleaseResults) {
            if ($release.SecurityAnalysis -and $release.SecurityAnalysis.SecurityIssues) {
                foreach ($issue in $release.SecurityAnalysis.SecurityIssues) {
                    $securityStats.Total++
                    
                    switch ($issue.Severity) {
                        "High" { $securityStats.High++ }
                        "Medium" { $securityStats.Medium++ }
                        "Low" { $securityStats.Low++ }
                        default { $securityStats.Low++ }
                    }
                }
            }
        }
    }
    
    # Add security stats to HTML
    $htmlContent += @"
                    <div class="stat-item">
                        <div class="stat-value">$($securityStats.Total)</div>
                        <div class="stat-label">Total Issues</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">$($securityStats.High)</div>
                        <div class="stat-label">High Severity</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">$($securityStats.Medium)</div>
                        <div class="stat-label">Medium Severity</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">$($securityStats.Low)</div>
                        <div class="stat-label">Low Severity</div>
                    </div>
                </div>
            </div>
"@

    # Add debugging for repository count
    $repoCount = 0
    if ($null -ne $RepoResults) {
        $repoCount = @($RepoResults).Count
        Write-Host "DEBUG: Repository data received in dashboard HTML: $repoCount items" -ForegroundColor Magenta
        if ($repoCount -gt 0) {
            Write-Host "DEBUG: First repository: $($RepoResults[0].RepositoryName)" -ForegroundColor Magenta
        }
    }
    else {
        Write-Host "DEBUG: Repository data is NULL in dashboard HTML" -ForegroundColor Red
    }

    # Add Components Stats Panel with explicit conversion to ensure counts
    $htmlContent += @"
            <div class="panel component-panel" data-component="all">
                <h3>Components Overview</h3>
                <div class="stat-container">
                    <div class='stat-item'>
                        <div class='stat-value'>$repoCount</div>
                        <div class='stat-label'>Repositories</div>
                    </div>
                    <div class='stat-item'>
                        <div class='stat-value'>$(if ($PipelineResults) { @($PipelineResults).Count } else { "0" })</div>
                        <div class='stat-label'>Pipelines</div>
                    </div>
                    <div class='stat-item'>
                        <div class='stat-value'>$(if ($BuildResults) { @($BuildResults).Count } else { "0" })</div>
                        <div class='stat-label'>Build Definitions</div>
                    </div>
                    <div class='stat-item'>
                        <div class='stat-value'>$(if ($ReleaseResults) { @($ReleaseResults).Count } else { "0" })</div>
                        <div class='stat-label'>Release Definitions</div>
                    </div>
                </div>
                
                <div class="quick-links">
                    <h4>Quick Links</h4>
                    <a href='#repositories' class='quick-link-button'>Repository Information</a>
                    <a href='#pipelines' class='quick-link-button'>Pipeline Analysis</a>
                    $(if ($BuildResults) { "<a href='#builds' class='quick-link-button'>Build Analysis</a>" })
                    $(if ($ReleaseResults) { "<a href='#releases' class='quick-link-button'>Release Analysis</a>" })
                </div>
            </div>
"@

    # Repository Findings Summary Panel
    if ($RepoResults) {
        $reposWithFindings = $RepoResults | Where-Object { $_.Findings -and $_.Findings.Count -gt 0 }
        $totalFindings = 0
        $reposWithFindings | ForEach-Object { $totalFindings += $_.Findings.Count }
        
        $htmlContent += @"
            <div class="panel component-panel" data-component="repo">
                <h3>Repository Scan Summary</h3>
                <div class="stat-container">
                    <div class="stat-item">
                        <div class="stat-value">$totalFindings</div>
                        <div class="stat-label">Secrets Found</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">$($reposWithFindings.Count)</div>
                        <div class="stat-label">Affected Repositories</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">$(@($RepoResults).Count)</div>
                        <div class="stat-label">Total Repositories</div>
                    </div>
                </div>
"@
        
        if ($reposWithFindings.Count -gt 0) {
            $htmlContent += @"
                <div class="warning">
                    <strong>Warning:</strong> Found $totalFindings potential secrets or sensitive data in $($reposWithFindings.Count) repositories.
                </div>
"@
        }
        else {
            $htmlContent += @"
                <div class="success">
                    <strong>Good:</strong> No secrets or sensitive data found in any repository.
                </div>
"@
        }
        
        $htmlContent += @"
            </div>
"@
    }
    
    # Pipeline Analysis Summary Panel
    if ($PipelineResults) {
        $pipelinesWithIssues = $PipelineResults | Where-Object { $_.Findings -and $_.Findings.Count -gt 0 }
        $totalIssues = 0
        $pipelinesWithIssues | ForEach-Object { $totalIssues += $_.Findings.Count }
        
        $htmlContent += @"
            <div class="panel component-panel" data-component="pipeline">
                <h3>Pipeline Analysis Summary</h3>
                <div class="stat-container">
                    <div class="stat-item">
                        <div class="stat-value">$totalIssues</div>
                        <div class="stat-label">Issues Found</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">$($pipelinesWithIssues.Count)</div>
                        <div class="stat-label">Affected Pipelines</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">$(@($PipelineResults).Count)</div>
                        <div class="stat-label">Total Pipelines</div>
                    </div>
                </div>
"@
        
        if ($pipelinesWithIssues.Count -gt 0) {
            $htmlContent += @"
                <div class="warning">
                    <strong>Warning:</strong> Found $totalIssues issues in $($pipelinesWithIssues.Count) pipelines.
                </div>
"@
        }
        else {
            $htmlContent += @"
                <div class="success">
                    <strong>Good:</strong> No issues found in any pipeline.
                </div>
"@
        }
        
        $htmlContent += @"
            </div>
"@
    }
    
    return $htmlContent
}

# Export the functions
#Export-ModuleMember -Function Initialize-HtmlOutput, New-DashboardSummaryHtml, Get-DashboardHtmlHeader
