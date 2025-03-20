# Dizzy - Azure DevOps Analyzer
# Release analysis results HTML generator

# Function to generate HTML for release analysis results
function New-ReleaseAnalysisHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ReleaseResults,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,
        
        [Parameter(Mandatory = $false)]
        [string]$DashboardPath
    )
    
    # Create the output folder if it doesn't exist
    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
    }
    
    # Get timestamp for file naming
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $htmlFilePath = Join-Path -Path $OutputFolder -ChildPath "Releases-Analysis-$timestamp.html"
    
    Write-Host "Generating release analysis HTML report..." -ForegroundColor Cyan
    
    # Create HTML header and styles
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dizzy - Release Analysis Results</title>
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
        .release-section { background-color: white; border-radius: 5px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .release-header { display: flex; justify-content: space-between; align-items: center; }
        .stat-container { display: flex; flex-wrap: wrap; }
        .stat-item { flex: 1; min-width: 120px; margin: 10px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; color: #0078d4; }
        .stat-label { font-size: 0.9em; color: #666; }
        .warning { background-color: #fff4e5; border-left: 4px solid #ff8c00; padding: 10px 15px; margin: 10px 0; }
        .error { background-color: #fde7e9; border-left: 4px solid #d13438; padding: 10px 15px; margin: 10px 0; }
        .success { background-color: #dff6dd; border-left: 4px solid #107c10; padding: 10px 15px; margin: 10px 0; }
        .back-link { margin-bottom: 20px; }
        .back-link a { color: #0078d4; text-decoration: none; }
        .back-link a:hover { text-decoration: underline; }
        .timestamp { font-style: italic; color: #666; margin-top: 10px; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th { background-color: #f0f0f0; text-align: left; padding: 10px; }
        td { padding: 10px; border-bottom: 1px solid #eee; }
        tr:hover { background-color: #f9f9f9; }
        .severity-badge { display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; }
        .severity-high { background-color: #fde7e9; color: #d13438; }
        .severity-medium { background-color: #fff4e5; color: #ff8c00; }
        .severity-low { background-color: #dff6dd; color: #107c10; }
        .badge { display: inline-block; margin-left: 10px; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; }
        .badge-count { background-color: #0078d4; color: white; }
        .env-badge { display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 0.8em; background-color: #f0f0f0; margin-right: 5px; }
        .collapsible { background-color: #f1f1f1; color: #444; cursor: pointer; padding: 18px; width: 100%; border: none; text-align: left; outline: none; font-size: 15px; margin-bottom: 1px; }
        .active, .collapsible:hover { background-color: #e0e0e0; }
        .collapsible:after { content: '\\002B'; color: #777; font-weight: bold; float: right; margin-left: 5px; }
        .active:after { content: "\\2212"; }
        .content { padding: 0 18px; max-height: 0; overflow: hidden; transition: max-height 0.2s ease-out; background-color: white; }
        .footer { text-align: center; margin-top: 40px; padding: 20px; color: #666; font-size: 0.9em; }
        .search-box { width: 100%; padding: 10px; margin-bottom: 20px; border: 1px solid #ddd; border-radius: 4px; }
        .filter-container { margin: 20px 0; }
        .filter-button { background-color: #f0f0f0; border: none; padding: 8px 15px; margin-right: 5px; border-radius: 5px; cursor: pointer; }
        .filter-button.active { background-color: #0078d4; color: white; }
        .environment-list { margin: 10px 0; }
        .progress-container { height: 20px; width: 100%; background-color: #f1f1f1; border-radius: 10px; margin: 10px 0; }
        .progress-bar { height: 20px; border-radius: 10px; text-align: center; line-height: 20px; color: white; font-size: 0.8em; }
        .progress-bar-success { background-color: #107c10; }
        .progress-bar-warning { background-color: #ff8c00; }
        .progress-bar-danger { background-color: #d13438; }
        .two-column { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .metrics-panel { padding: 15px; background-color: #f9f9f9; border-radius: 5px; margin-bottom: 10px; }
    </style>
    <script>
        function toggleCollapsible(index) {
            var coll = document.getElementsByClassName("collapsible");
            var content = coll[index].nextElementSibling;
            if (content.style.maxHeight) {
                content.style.maxHeight = null;
                coll[index].classList.remove("active");
            } else {
                content.style.maxHeight = content.scrollHeight + "px";
                coll[index].classList.add("active");
            }
        }
        
        function searchReleases() {
            var input = document.getElementById('searchBox');
            var filter = input.value.toUpperCase();
            var releaseSections = document.getElementsByClassName('release-section');
            
            for (var i = 0; i < releaseSections.length; i++) {
                var releaseSection = releaseSections[i];
                var releaseNameElement = releaseSection.getElementsByTagName('h3')[0];
                var releaseName = releaseNameElement.textContent || releaseNameElement.innerText;
                
                if (releaseName.toUpperCase().indexOf(filter) > -1) {
                    releaseSection.style.display = "";
                } else {
                    var textContent = releaseSection.textContent || releaseSection.innerText;
                    if (textContent.toUpperCase().indexOf(filter) > -1) {
                        releaseSection.style.display = "";
                    } else {
                        releaseSection.style.display = "none";
                    }
                }
            }
        }
        
        function filterBySeverity(severity) {
            var buttons = document.getElementsByClassName('filter-button');
            for (var i = 0; i < buttons.length; i++) {
                if (buttons[i].getAttribute('data-severity') === severity || (severity === 'all' && buttons[i].getAttribute('data-severity') === 'all')) {
                    buttons[i].classList.add('active');
                } else {
                    buttons[i].classList.remove('active');
                }
            }
            
            var issues = document.getElementsByClassName('security-issue');
            for (var i = 0; i < issues.length; i++) {
                var issueSeverity = issues[i].getAttribute('data-severity');
                if (severity === 'all' || issueSeverity === severity) {
                    issues[i].style.display = "";
                } else {
                    issues[i].style.display = "none";
                }
            }
        }
    </script>
</head>
<body>
    <header>
        <div class="container">
            <h1>Release Analysis Results</h1>
            <p>Dizzy - Azure DevOps Analyzer</p>
        </div>
    </header>
    
    <div class="container">
"@

    # Add link back to dashboard if provided
    if (-not [string]::IsNullOrEmpty($DashboardPath)) {
        $dashboardFilename = Split-Path -Path $DashboardPath -Leaf
        $htmlContent += @"
        <div class="back-link">
            <a href="$dashboardFilename">← Back to Dashboard</a>
        </div>
"@
    }
    
    # Add search functionality
    $htmlContent += @"
        <input type="text" id="searchBox" class="search-box" onkeyup="searchReleases()" placeholder="Search releases...">
        
        <div class="filter-container">
            <button class="filter-button active" data-severity="all" onclick="filterBySeverity('all')">All Issues</button>
            <button class="filter-button" data-severity="high" onclick="filterBySeverity('high')">High Severity</button>
            <button class="filter-button" data-severity="medium" onclick="filterBySeverity('medium')">Medium Severity</button>
            <button class="filter-button" data-severity="low" onclick="filterBySeverity('low')">Low Severity</button>
        </div>
"@
    
    # Add summary section
    $totalReleases = $ReleaseResults.Count
    
    # Count releases with security issues
    $releasesWithIssues = 0
    $totalSecurityIssues = 0
    $highIssues = 0
    $mediumIssues = 0
    $lowIssues = 0
    
    foreach ($release in $ReleaseResults) {
        if ($release.SecurityAnalysis -and $release.SecurityAnalysis.SecurityIssues -and $release.SecurityAnalysis.SecurityIssues.Count -gt 0) {
            $releasesWithIssues++
            $totalSecurityIssues += $release.SecurityAnalysis.SecurityIssues.Count
            
            foreach ($issue in $release.SecurityAnalysis.SecurityIssues) {
                switch ($issue.Severity) {
                    "High" { $highIssues++ }
                    "Medium" { $mediumIssues++ }
                    "Low" { $lowIssues++ }
                    default { $lowIssues++ }
                }
            }
        }
    }
    
    # Count total environments and calculate average success rate
    $totalEnvironments = 0
    $successRateSum = 0
    $releasesWithPerformanceData = 0
    
    foreach ($release in $ReleaseResults) {
        $totalEnvironments += $release.EnvironmentCount
        
        if ($release.PerformanceAnalysis -and $release.PerformanceAnalysis.RecentSuccessRate -ne 0) {
            $successRateSum += $release.PerformanceAnalysis.RecentSuccessRate
            $releasesWithPerformanceData++
        }
    }
    
    $avgSuccessRate = 0
    if ($releasesWithPerformanceData -gt 0) {
        $avgSuccessRate = [math]::Round($successRateSum / $releasesWithPerformanceData, 1)
    }
    
    $htmlContent += @"
        <div class="summary-section">
            <h2>Analysis Summary</h2>
            <div class="stat-container">
                <div class="stat-item">
                    <div class="stat-value">$totalReleases</div>
                    <div class="stat-label">Release Definitions</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$totalEnvironments</div>
                    <div class="stat-label">Environments</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$avgSuccessRate%</div>
                    <div class="stat-label">Avg Success Rate</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$totalSecurityIssues</div>
                    <div class="stat-label">Security Issues</div>
                </div>
            </div>
            
            <div class="stat-container">
                <div class="stat-item">
                    <div class="stat-value">$highIssues</div>
                    <div class="stat-label">High Severity</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$mediumIssues</div>
                    <div class="stat-label">Medium Severity</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$lowIssues</div>
                    <div class="stat-label">Low Severity</div>
                </div>
            </div>
"@
    
    # Add status message based on findings
    if ($totalSecurityIssues -gt 0) {
        if ($highIssues -gt 0) {
            $htmlContent += @"
            <div class="error">
                <strong>Warning:</strong> Found $highIssues high severity issues that require immediate attention.
                <p>These issues may include production environments without approvals, exposed credentials, or critical security misconfigurations.</p>
            </div>
"@
        }
        
        if ($mediumIssues -gt 0) {
            $htmlContent += @"
            <div class="warning">
                <strong>Attention:</strong> Found $mediumIssues medium severity issues that should be addressed.
                <p>These issues may include reused credentials across environments, best practice violations, or security concerns.</p>
            </div>
"@
        }
    }
    
    if ($avgSuccessRate -lt 80) {
        $htmlContent += @"
            <div class="warning">
                <strong>Performance Concern:</strong> The average release success rate is only $avgSuccessRate%, which is below the recommended 80% threshold.
                <p>This may indicate reliability issues with your deployment pipelines. Review the environments with the lowest success rates.</p>
            </div>
"@
    }
    
    $htmlContent += @"
            <p class="timestamp">Analysis completed on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
"@
    
    # Add detailed release sections
    $collapsibleIndex = 0
    foreach ($release in $ReleaseResults) {
        $securityIssuesCount = 0
        if ($release.SecurityAnalysis -and $release.SecurityAnalysis.SecurityIssues) {
            $securityIssuesCount = $release.SecurityAnalysis.SecurityIssues.Count
        }
        
        $successRate = "N/A"
        if ($release.PerformanceAnalysis -and $release.PerformanceAnalysis.TotalReleases -gt 0) {
            $successRate = "$($release.PerformanceAnalysis.RecentSuccessRate)%"
        }
        
        $htmlContent += @"
        <div class="release-section">
            <div class="release-header">
                <h3>$($release.DefinitionName)</h3>
                <span class="badge badge-count">$securityIssuesCount issues</span>
            </div>
            <p>
                <strong>Release ID:</strong> $($release.DefinitionId)<br>
                <strong>Created By:</strong> $($release.CreatedBy)<br>
                <strong>Created Date:</strong> $($release.CreatedDate)<br>
                <strong>Success Rate:</strong> $successRate<br>
                <strong>URL:</strong> <a href="$($release.Url)" target="_blank">View in Azure DevOps</a>
            </p>
            
            <div class="two-column">
                <div>
                    <h4>Environment Configuration</h4>
"@
        
        # Environment details
        if ($release.EnvironmentCount -gt 0) {
            $htmlContent += @"
                    <div class="environment-list">
"@
            
            if ($release.SecurityAnalysis) {
                # Has approval checks
                $htmlContent += @"
                        <p><strong>Pre-Deployment Approvals:</strong> $(if ($release.SecurityAnalysis.HasApprovalChecks) { "Yes" } else { "No" })</p>
                        <p><strong>Quality Gates:</strong> $(if ($release.SecurityAnalysis.HasGates) { "Yes" } else { "No" })</p>
                        <p><strong>Auto-Deploy Enabled:</strong> $(if ($release.SecurityAnalysis.AutoDeployEnabled) { "Yes" } else { "No" })</p>
"@
            }
            
            $htmlContent += @"
                    </div>
"@
        }
        else {
            $htmlContent += @"
                    <p>No environment information available.</p>
"@
        }
        
        $htmlContent += @"
                </div>
                
                <div>
                    <h4>Performance Metrics</h4>
"@
        
        # Performance metrics
        if ($release.PerformanceAnalysis -and $release.PerformanceAnalysis.TotalReleases -gt 0) {
            $successRateValue = $release.PerformanceAnalysis.RecentSuccessRate
            $barColor = "progress-bar-success"
            
            if ($successRateValue -lt 60) {
                $barColor = "progress-bar-danger"
            }
            elseif ($successRateValue -lt 80) {
                $barColor = "progress-bar-warning"
            }
            
            $htmlContent += @"
                    <div class="metrics-panel">
                        <p><strong>Success Rate:</strong></p>
                        <div class="progress-container">
                            <div class="progress-bar $barColor" style="width: $($successRateValue)%">$($successRateValue)%</div>
                        </div>
                        <p><strong>Total Releases:</strong> $($release.PerformanceAnalysis.TotalReleases)</p>
                        <p><strong>Successful Releases:</strong> $($release.PerformanceAnalysis.SuccessfulReleases)</p>
                        <p><strong>Failed Releases:</strong> $($release.PerformanceAnalysis.FailedReleases)</p>
                    </div>
"@
        }
        else {
            $htmlContent += @"
                    <p>No performance data available.</p>
"@
        }
        
        $htmlContent += @"
                </div>
            </div>
"@
        
        # Security Issues
        if ($release.SecurityAnalysis -and $release.SecurityAnalysis.SecurityIssues -and $release.SecurityAnalysis.SecurityIssues.Count -gt 0) {
            $htmlContent += @"
            <h4>Security Issues</h4>
            <table>
                <tr>
                    <th>Issue</th>
                    <th>Severity</th>
                    <th>Description</th>
                </tr>
"@
            
            foreach ($issue in $release.SecurityAnalysis.SecurityIssues) {
                $severityClass = switch ($issue.Severity) {
                    "High" { "severity-high" }
                    "Medium" { "severity-medium" }
                    "Low" { "severity-low" }
                    default { "severity-low" }
                }
                
                $severityLower = ($issue.Severity).ToLower()
                
                $htmlContent += @"
                <tr class="security-issue" data-severity="$severityLower">
                    <td>$($issue.Issue)</td>
                    <td><span class="severity-badge $severityClass">$($issue.Severity)</span></td>
                    <td>$($issue.Description)$(if ($issue.Environments) { "<br><strong>Affected Environments:</strong> $($issue.Environments)" })</td>
                </tr>
"@
            }
            
            $htmlContent += @"
            </table>
"@
        }
        
        # Environment Performance Data
        if ($release.PerformanceAnalysis -and $release.PerformanceAnalysis.EnvironmentStats -and $release.PerformanceAnalysis.EnvironmentStats.Count -gt 0) {
            $htmlContent += @"
            <h4>Environment Performance</h4>
            <table>
                <tr>
                    <th>Environment</th>
                    <th>Success Rate</th>
                    <th>Total Deployments</th>
                    <th>Successful</th>
                    <th>Failed</th>
                    <th>Avg Duration (min)</th>
                </tr>
"@
            
            foreach ($envName in $release.PerformanceAnalysis.EnvironmentStats.Keys) {
                $env = $release.PerformanceAnalysis.EnvironmentStats[$envName]
                
                $htmlContent += @"
                <tr>
                    <td>$envName</td>
                    <td>$($env.SuccessRate)%</td>
                    <td>$($env.TotalDeployments)</td>
                    <td>$($env.SuccessfulDeployments)</td>
                    <td>$($env.FailedDeployments)</td>
                    <td>$([math]::Round($env.AverageDuration, 1))</td>
                </tr>
"@
            }
            
            $htmlContent += @"
            </table>
"@
        }
        
        $htmlContent += @"
        </div>
"@
        $collapsibleIndex++
    }
    
    # Add footer and close HTML tags
    $htmlContent += @"
        <div class="footer">
            <p>Dizzy - Azure DevOps Analyzer | Release Analysis Results | Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
    </div>
</body>
</html>
"@
    
    # Save the HTML content to file
    $htmlContent | Out-File -FilePath $htmlFilePath -Force
    
    Write-Host "Release analysis HTML report created at: $htmlFilePath" -ForegroundColor Green
    
    return $htmlFilePath
}

# Export function
#Export-ModuleMember -Function New-ReleaseAnalysisHtml
