# Dizzy - Azure DevOps Analyzer
# Build analysis results HTML generator

# Function to generate HTML for build analysis results
function New-BuildAnalysisHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$BuildResults,
        
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
    $htmlFilePath = Join-Path -Path $OutputFolder -ChildPath "Builds-Analysis-$timestamp.html"
    
    Write-Host "Generating build analysis HTML report..." -ForegroundColor Cyan
    
    # Create HTML header and styles
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dizzy - Build Analysis Results</title>
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
        .build-section { background-color: white; border-radius: 5px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stat-container { display: flex; flex-wrap: wrap; }
        .stat-item { flex: 1; min-width: 120px; margin: 10px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; color: #0078d4; }
        .stat-label { font-size: 0.9em; color: #666; }
        .warning { background-color: #fff4e5; border-left: 4px solid #ff8c00; padding: 10px 15px; margin: 10px 0; }
        .error { background-color: #fde7e9; border-left: 4px solid #d13438; padding: 10px 15px; margin: 10px 0; }
        .success { background-color: #dff6dd; border-left: 4px solid #107c10; padding: 10px 15px; margin: 10px 0; }
        .timestamp { font-style: italic; color: #666; margin-top: 10px; font-size: 0.9em; }
        .back-link { margin-bottom: 20px; }
        .back-link a { color: #0078d4; text-decoration: none; }
        .back-link a:hover { text-decoration: underline; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th { background-color: #f0f0f0; text-align: left; padding: 10px; }
        td { padding: 10px; border-bottom: 1px solid #eee; }
        tr:hover { background-color: #f9f9f9; }
        .badge { display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; }
        .badge-count { background-color: #0078d4; color: white; }
        .badge-success { background-color: #107c10; color: white; }
        .badge-warning { background-color: #ff8c00; color: white; }
        .badge-danger { background-color: #d13438; color: white; }
        .severity-badge { display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; }
        .severity-high { background-color: #fde7e9; color: #d13438; }
        .severity-medium { background-color: #fff4e5; color: #ff8c00; }
        .severity-low { background-color: #dff6dd; color: #107c10; }
        .search-box { width: 100%; padding: 10px; margin-bottom: 20px; border: 1px solid #ddd; border-radius: 4px; }
        .footer { text-align: center; margin-top: 40px; padding: 20px; color: #666; font-size: 0.9em; }
        .progress-container { height: 20px; width: 100%; background-color: #f1f1f1; border-radius: 10px; margin: 10px 0; }
        .progress-bar { height: 20px; border-radius: 10px; text-align: center; line-height: 20px; color: white; font-size: 0.8em; }
        .progress-bar-success { background-color: #107c10; }
        .progress-bar-warning { background-color: #ff8c00; }
        .progress-bar-danger { background-color: #d13438; }
        .build-details { display: none; background-color: #f9f9f9; padding: 15px; border-radius: 5px; margin-top: 10px; }
        .chart-container { height: 300px; margin: 20px 0; }
        .two-column { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .metrics-panel { padding: 15px; background-color: #f9f9f9; border-radius: 5px; margin-bottom: 10px; }
    </style>
    <script>
        function toggleDetails(id) {
            var element = document.getElementById(id);
            if (element.style.display === 'none' || element.style.display === '') {
                element.style.display = 'block';
            } else {
                element.style.display = 'none';
            }
        }
        
        function searchBuilds() {
            var input = document.getElementById('searchBox');
            var filter = input.value.toUpperCase();
            var sections = document.getElementsByClassName('build-section');
            
            for (var i = 0; i < sections.length; i++) {
                var section = sections[i];
                var header = section.getElementsByTagName('h3')[0];
                var headerText = header.textContent || header.innerText;
                
                if (headerText.toUpperCase().indexOf(filter) > -1) {
                    section.style.display = "";
                } else {
                    var textContent = section.textContent || section.innerText;
                    if (textContent.toUpperCase().indexOf(filter) > -1) {
                        section.style.display = "";
                    } else {
                        section.style.display = "none";
                    }
                }
            }
        }
    </script>
</head>
<body>
    <header>
        <div class="container">
            <h1>Build Analysis Results</h1>
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
        <input type="text" id="searchBox" class="search-box" onkeyup="searchBuilds()" placeholder="Search build definitions...">
"@
    
    # Calculate summary statistics
    $totalBuilds = $BuildResults.Count
    $totalSuccessRate = 0
    $totalFailureRate = 0
    $buildsWithData = 0
    $totalSecurityIssues = 0
    
    foreach ($build in $BuildResults) {
        if ($build.FailureAnalysis -and $build.FailureAnalysis.TotalBuilds -gt 0) {
            $totalFailureRate += $build.FailureAnalysis.RecentFailureRate
            $buildsWithData++
        }
        
        if ($build.SecurityAnalysis -and $build.SecurityAnalysis.SecurityIssues) {
            $totalSecurityIssues += $build.SecurityAnalysis.SecurityIssues.Count
        }
    }
    
    $avgFailureRate = 0
    if ($buildsWithData -gt 0) {
        $avgFailureRate = [math]::Round($totalFailureRate / $buildsWithData, 1)
        $avgSuccessRate = 100 - $avgFailureRate
    }
    else {
        $avgSuccessRate = "N/A"
    }
    
    # Add summary section
    $htmlContent += @"
        <div class="summary-section">
            <h2>Build Analysis Summary</h2>
            <div class="stat-container">
                <div class="stat-item">
                    <div class="stat-value">$totalBuilds</div>
                    <div class="stat-label">Build Definitions</div>
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
"@
    
    # Add status message based on statistics
    if ($avgFailureRate -gt 20) {
        $htmlContent += @"
            <div class="error">
                <strong>High failure rate:</strong> The average build failure rate of $avgFailureRate% is concerning and should be investigated.
                <p>Consistently failing builds can lead to delays, reduced productivity, and potential integration issues.</p>
            </div>
"@
    }
    elseif ($avgFailureRate -gt 10) {
        $htmlContent += @"
            <div class="warning">
                <strong>Moderate failure rate:</strong> The average build failure rate of $avgFailureRate% could be improved.
                <p>Review the most common failure reasons and address the root causes to improve build reliability.</p>
            </div>
"@
    }
    else {
        $htmlContent += @"
            <div class="success">
                <strong>Good build success rate:</strong> The average build failure rate is only $avgFailureRate%.
                <p>Your build pipelines are performing well. Continue monitoring to maintain this high level of reliability.</p>
            </div>
"@
    }
    
    if ($totalSecurityIssues -gt 0) {
        $htmlContent += @"
            <div class="warning">
                <strong>Security concerns:</strong> Found $totalSecurityIssues security issues in build definitions.
                <p>Review the security issues identified in each build and address them to improve your overall security posture.</p>
            </div>
"@
    }
    
    $htmlContent += @"
            <p class="timestamp">Analysis completed on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
"@
    
    # Add detailed build sections
    foreach ($build in $BuildResults) {
        $detailsId = "build-details-$($build.DefinitionId)"
        
        # Get failure rate and success rate
        $failureRate = "N/A"
        $failureRateValue = 0
        $successRateValue = 0
        $barColor = "progress-bar-success"
        
        if ($build.FailureAnalysis -and $build.FailureAnalysis.TotalBuilds -gt 0) {
            $failureRate = "$($build.FailureAnalysis.RecentFailureRate)%"
            $failureRateValue = $build.FailureAnalysis.RecentFailureRate
            $successRateValue = 100 - $failureRateValue
            
            if ($failureRateValue -gt 20) {
                $barColor = "progress-bar-danger"
            }
            elseif ($failureRateValue -gt 10) {
                $barColor = "progress-bar-warning"
            }
        }
        
        # Count security issues
        $securityIssuesCount = 0
        if ($build.SecurityAnalysis -and $build.SecurityAnalysis.SecurityIssues) {
            $securityIssuesCount = $build.SecurityAnalysis.SecurityIssues.Count
        }
        
        $htmlContent += @"
        <div class="build-section">
            <h3>$($build.DefinitionName)</h3>
            <p>
                <strong>Type:</strong> $($build.DefType)<br>
                <strong>Created:</strong> $($build.CreatedDate)<br>
                <strong>URL:</strong> <a href="$($build.Url)" target="_blank">View in Azure DevOps</a>
            </p>
            
            <div class="two-column">
                <div>
                    <h4>Build Performance</h4>
                    <div class="metrics-panel">
                        <p><strong>Success Rate:</strong></p>
                        <div class="progress-container">
                            <div class="progress-bar $barColor" style="width: $($successRateValue)%">$($successRateValue)%</div>
                        </div>
"@
        
        if ($build.FailureAnalysis -and $build.FailureAnalysis.TotalBuilds -gt 0) {
            $htmlContent += @"
                        <p><strong>Total Builds:</strong> $($build.FailureAnalysis.TotalBuilds)</p>
                        <p><strong>Successful Builds:</strong> $($build.FailureAnalysis.SuccessfulBuilds)</p>
                        <p><strong>Failed Builds:</strong> $($build.FailureAnalysis.FailedBuilds)</p>
                        <p><strong>Average Duration:</strong> $([math]::Round($build.FailureAnalysis.AverageDuration, 2)) minutes</p>
"@
        }
        else {
            $htmlContent += @"
                        <p>No build history available for analysis.</p>
"@
        }
        
        $htmlContent += @"
                    </div>
                </div>
                
                <div>
                    <h4>Security Analysis</h4>
                    <div class="metrics-panel">
"@
        
        if ($build.SecurityAnalysis) {
            $htmlContent += @"
                        <p><strong>Secret Variables:</strong> $($build.SecurityAnalysis.SecretVariablesCount)</p>
                        <p><strong>Default Branch:</strong> $($build.SecurityAnalysis.DefaultBranch)</p>
                        <p><strong>Uses Default Agent Pool:</strong> $($build.SecurityAnalysis.UsesDefaultAgentPool)</p>
                        <p><strong>Security Issues:</strong> $securityIssuesCount</p>
"@
            
            if ($securityIssuesCount -gt 0) {
                $htmlContent += @"
                        <button onclick="toggleDetails('$detailsId-security')">Show/Hide Security Issues</button>
"@
            }
        }
        else {
            $htmlContent += @"
                        <p>No security analysis available.</p>
"@
        }
        
        $htmlContent += @"
                    </div>
                </div>
            </div>
"@
        
        # Security issues details section
        if ($build.SecurityAnalysis -and $build.SecurityAnalysis.SecurityIssues -and $build.SecurityAnalysis.SecurityIssues.Count -gt 0) {
            $htmlContent += @"
            <div id="$detailsId-security" class="build-details">
                <h4>Security Issues</h4>
                <table>
                    <tr>
                        <th>Issue</th>
                        <th>Severity</th>
                        <th>Description</th>
                    </tr>
"@
            
            foreach ($issue in $build.SecurityAnalysis.SecurityIssues) {
                $severityClass = switch ($issue.Severity) {
                    "High" { "severity-high" }
                    "Medium" { "severity-medium" }
                    "Low" { "severity-low" }
                    default { "severity-low" }
                }
                
                $htmlContent += @"
                    <tr>
                        <td>$($issue.Issue)</td>
                        <td><span class="severity-badge $severityClass">$($issue.Severity)</span></td>
                        <td>$($issue.Description)</td>
                    </tr>
"@
            }
            
            $htmlContent += @"
                </table>
            </div>
"@
        }
        
        # Common failures section
        if ($build.FailureAnalysis -and $build.FailureAnalysis.MostCommonFailures -and $build.FailureAnalysis.MostCommonFailures.Count -gt 0) {
            $htmlContent += @"
            <button onclick="toggleDetails('$detailsId-failures')">Show/Hide Common Failures</button>
            <div id="$detailsId-failures" class="build-details">
                <h4>Most Common Failures</h4>
                <ul>
"@
            
            foreach ($failure in $build.FailureAnalysis.MostCommonFailures) {
                $htmlContent += @"
                    <li>$($failure.Reason) (Count: $($failure.Count))</li>
"@
            }
            
            $htmlContent += @"
                </ul>
            </div>
"@
        }
        
        # Recent builds section
        if ($build.RecentBuilds -and $build.RecentBuilds.Count -gt 0) {
            $htmlContent += @"
            <button onclick="toggleDetails('$detailsId-builds')">Show/Hide Recent Builds</button>
            <div id="$detailsId-builds" class="build-details">
                <h4>Recent Builds</h4>
                <table>
                    <tr>
                        <th>Build Number</th>
                        <th>Status</th>
                        <th>Result</th>
                        <th>Branch</th>
                        <th>Start Time</th>
                    </tr>
"@
            
            foreach ($recentBuild in $build.RecentBuilds) {
                $resultBadge = ""
                
                switch ($recentBuild.result) {
                    "succeeded" { $resultBadge = '<span class="badge badge-success">Succeeded</span>' }
                    "partiallySucceeded" { $resultBadge = '<span class="badge badge-warning">Partially Succeeded</span>' }
                    "failed" { $resultBadge = '<span class="badge badge-danger">Failed</span>' }
                    default { $resultBadge = $recentBuild.result }
                }
                
                $htmlContent += @"
                    <tr>
                        <td>$($recentBuild.buildNumber)</td>
                        <td>$($recentBuild.status)</td>
                        <td>$resultBadge</td>
                        <td>$($recentBuild.sourceBranch)</td>
                        <td>$($recentBuild.startTime)</td>
                    </tr>
"@
            }
            
            $htmlContent += @"
                </table>
            </div>
"@
        }
        
        $htmlContent += @"
        </div>
"@
    }
    
    # Add footer and close HTML tags
    $htmlContent += @"
        <div class="footer">
            <p>Dizzy - Azure DevOps Analyzer | Build Analysis Results | Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
    </div>
</body>
</html>
"@
    
    # Save the HTML content to file
    $htmlContent | Out-File -FilePath $htmlFilePath -Force
    
    Write-Host "Build analysis HTML report created at: $htmlFilePath" -ForegroundColor Green
    
    return $htmlFilePath
}

# Export function
Export-ModuleMember -Function New-BuildAnalysisHtml