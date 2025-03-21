# Dizzy - Azure DevOps Analyzer
# Main dashboard HTML generator - Part 2 (Detailed Sections)

# Import the first part of the dashboard generator
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$dashboardPart1Path = Join-Path -Path $scriptPath -ChildPath "Dashboard-HTML.ps1"
. $dashboardPart1Path

# Function to generate repository details HTML
# Modified New-RepositoryDetailsHtml function for Dashboard-HTML-Details.ps1
function New-RepositoryDetailsHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$RepoResults
    )
    
    # Debug repository data
    if ($null -eq $RepoResults) {
        Write-Host "Repository data is NULL in details HTML" -ForegroundColor Red
        $RepoResults = @()
    }
    
    Write-Host "Processing $(@($RepoResults).Count) repositories for HTML details" -ForegroundColor Cyan
    
    $htmlContent = @"
    <h2 id="repositories">Repository Information</h2>
    <div class="panel panel-full component-panel" data-component="repo">
"@
    
    # Check if we have any repository data
    if (@($RepoResults).Count -eq 0) {
        $htmlContent += @"
        <div class="info">
            <strong>No repositories found:</strong> No repository information is available.
            <p>This could be due to API access issues or because there are no repositories in this project.</p>
        </div>
"@
    } else {
        # First, let's add a summary table of all repositories
        $htmlContent += @"
        <h3>All Repositories</h3>
        <table>
            <tr>
                <th>Repository Name</th>
                <th>Default Branch</th>
                <th>Total Files</th>
                <th>Scanned Files</th>
                <th>Findings</th>
                <th>Details</th>
            </tr>
"@
        
        foreach ($repo in $RepoResults) {
            $findingsCount = if ($repo.Findings) { @($repo.Findings).Count } else { 0 }
            $detailsId = "repo-details-$($repo.RepositoryId)".Replace('-','')
            
            $htmlContent += @"
            <tr>
                <td>$($repo.RepositoryName)</td>
                <td>$($repo.DefaultBranch)</td>
                <td>$($repo.TotalFilesCount)</td>
                <td>$($repo.ScannedFilesCount)</td>
                <td>$findingsCount</td>
                <td><button onclick="toggleDetails('$detailsId')">Show/Hide</button></td>
            </tr>
            <tr>
                <td colspan="6">
                    <div id="$detailsId" style="display: none;">
                        <p><strong>Repository URL:</strong> <a href="$($repo.Url)" target="_blank">$($repo.Url)</a></p>
                        <p><strong>Scan Date:</strong> $($repo.ScanDate)</p>
"@
            
            if ($findingsCount -gt 0) {
                $htmlContent += @"
                        <h4>Security Findings</h4>
                        <table>
                            <tr>
                                <th>File Path</th>
                                <th>Line</th>
                                <th>Type</th>
                                <th>Context</th>
                            </tr>
"@
                
                foreach ($finding in $repo.Findings) {
                    $htmlContent += @"
                            <tr>
                                <td>$($finding.FilePath)</td>
                                <td>$($finding.LineNumber)</td>
                                <td><span class="status-badge status-high">$($finding.PatternName)</span></td>
                                <td><code>$($finding.Context)</code></td>
                            </tr>
"@
                }
                
                $htmlContent += @"
                        </table>
"@
            } else {
                $htmlContent += @"
                        <div class="success">
                            <strong>No findings:</strong> No secrets or sensitive data were found in this repository.
                        </div>
"@
            }
            
            $htmlContent += @"
                    </div>
                </td>
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

    return $htmlContent
}

# Function to generate pipeline details HTML
# Modified New-PipelineDetailsHtml function for Dashboard-HTML-Details.ps1
function New-PipelineDetailsHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$PipelineResults
    )
    
    $htmlContent = @"
    <h2 id="pipelines">Pipeline Analysis</h2>
    <div class="panel panel-full component-panel" data-component="pipeline">
"@
    
    # Add summary table for all pipelines
    $htmlContent += @"
        <h3>All Pipelines</h3>
        <table>
            <tr>
                <th>Pipeline Name</th>
                <th>Type</th>
                <th>Created Date</th>
                <th>Issues</th>
                <th>Details</th>
            </tr>
"@
    
    foreach ($pipeline in $PipelineResults) {
        $issuesCount = if ($pipeline.Findings) { $pipeline.Findings.Count } else { 0 }
        $detailsId = "pipeline-details-$($pipeline.PipelineId.Replace('-',''))"
        
        $htmlContent += @"
            <tr>
                <td>$($pipeline.PipelineName)</td>
                <td>$($pipeline.PipelineType)</td>
                <td>$($pipeline.CreatedDate)</td>
                <td>$issuesCount</td>
                <td><button onclick="toggleDetails('$detailsId')">Show/Hide</button></td>
            </tr>
            <tr>
                <td colspan="5">
                    <div id="$detailsId" style="display: none;">
                        <p><strong>Pipeline URL:</strong> <a href="$($pipeline.Url)" target="_blank">View in Azure DevOps</a></p>
                        <p><strong>Scan Date:</strong> $($pipeline.ScanDate)</p>
"@
        
        # Add recent runs if available
        if ($pipeline.Runs -and $pipeline.Runs.Count -gt 0) {
            $htmlContent += @"
                        <h4>Recent Runs</h4>
                        <table>
                            <tr>
                                <th>Run ID</th>
                                <th>Name</th>
                                <th>State</th>
                                <th>Result</th>
                                <th>Created Date</th>
                            </tr>
"@
            
            foreach ($run in $pipeline.Runs) {
                $htmlContent += @"
                            <tr>
                                <td>$($run.id)</td>
                                <td>$($run.name)</td>
                                <td>$($run.state)</td>
                                <td>$($run.result)</td>
                                <td>$($run.createdDate)</td>
                            </tr>
"@
            }
            
            $htmlContent += @"
                        </table>
"@
        }
        
        # Show findings if any
        if ($issuesCount -gt 0) {
            $htmlContent += @"
                        <h4>Security Issues</h4>
                        <table>
                            <tr>
                                <th>Line</th>
                                <th>Issue Type</th>
                                <th>Severity</th>
                                <th>Description</th>
                            </tr>
"@
            
            foreach ($finding in $pipeline.Findings) {
                $severityClass = switch ($finding.Severity) {
                    "High" { "status-high" }
                    "Medium" { "status-medium" }
                    "Low" { "status-low" }
                    default { "status-low" }
                }
                
                $htmlContent += @"
                            <tr>
                                <td>$($finding.LineNumber)</td>
                                <td>$($finding.IssueType)</td>
                                <td><span class="status-badge $severityClass">$($finding.Severity)</span></td>
                                <td>$($finding.Description)<br/><code>$($finding.Context)</code></td>
                            </tr>
"@
            }
            
            $htmlContent += @"
                        </table>
"@
        } else {
            $htmlContent += @"
                        <div class="success">
                            <strong>No issues:</strong> No issues were found in this pipeline.
                        </div>
"@
        }
        
        $htmlContent += @"
                    </div>
                </td>
            </tr>
"@
    }
    
    $htmlContent += @"
        </table>
    </div>
"@

    return $htmlContent
}

# Function to generate build details HTML
function New-BuildDetailsHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$BuildResults
    )
    
    $htmlContent = @"
    <h2 id="builds">Build Analysis</h2>
    <div class="panel panel-full component-panel" data-component="build">
"@
    
    if ($BuildResults.Count -gt 0) {
        $htmlContent += @"
        <table>
            <tr>
                <th>Definition Name</th>
                <th>Failure Rate</th>
                <th>Security Issues</th>
                <th>Details</th>
            </tr>
"@
        
        foreach ($build in $BuildResults) {
            $failureRate = "N/A"
            if ($build.FailureAnalysis -and $build.FailureAnalysis.TotalBuilds -gt 0) {
                $failureRate = "$($build.FailureAnalysis.RecentFailureRate)%"
            }
            
            $securityIssuesCount = 0
            if ($build.SecurityAnalysis -and $build.SecurityAnalysis.SecurityIssues) {
                $securityIssuesCount = $build.SecurityAnalysis.SecurityIssues.Count
            }
            
            $detailsId = "build-details-$($build.DefinitionId)"
            
            $htmlContent += @"
            <tr>
                <td>$($build.DefinitionName)</td>
                <td>$failureRate</td>
                <td>$securityIssuesCount</td>
                <td><button onclick="toggleDetails('$detailsId')">Show/Hide</button></td>
            </tr>
            <tr>
                <td colspan="4">
                    <div id="$detailsId" style="display: none;">
                        <h4>Build Information</h4>
                        <p>
                            <strong>Definition ID:</strong> $($build.DefinitionId)<br/>
                            <strong>Created Date:</strong> $($build.CreatedDate)<br/>
                            <strong>URL:</strong> <a href="$($build.Url)" target="_blank">View in Azure DevOps</a>
                        </p>
                        
                        <h4>Recent Builds</h4>
"@
            
            if ($build.RecentBuilds -and $build.RecentBuilds.Count -gt 0) {
                $htmlContent += @"
                        <table>
                            <tr>
                                <th>Number</th>
                                <th>Status</th>
                                <th>Result</th>
                                <th>Start Time</th>
                                <th>Duration</th>
                            </tr>
"@
                
                foreach ($recentBuild in $build.RecentBuilds) {
                    # Calculate duration if available
                    $duration = "N/A"
                    if ($recentBuild.startTime -and $recentBuild.finishTime) {
                        $startTime = [DateTime]$recentBuild.startTime
                        $finishTime = [DateTime]$recentBuild.finishTime
                        $durationMinutes = [math]::Round(($finishTime - $startTime).TotalMinutes, 1)
                        $duration = "$durationMinutes min"
                    }
                    
                    $htmlContent += @"
                            <tr>
                                <td>$($recentBuild.buildNumber)</td>
                                <td>$($recentBuild.status)</td>
                                <td>$($recentBuild.result)</td>
                                <td>$($recentBuild.startTime)</td>
                                <td>$duration</td>
                            </tr>
"@
                }
                
                $htmlContent += @"
                        </table>
"@
            }
            else {
                $htmlContent += @"
                        <p>No recent build data available.</p>
"@
            }
            
            # Security Analysis section
            if ($build.SecurityAnalysis -and $build.SecurityAnalysis.SecurityIssues -and $build.SecurityAnalysis.SecurityIssues.Count -gt 0) {
                $htmlContent += @"
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
                        "High" { "status-high" }
                        "Medium" { "status-medium" }
                        "Low" { "status-low" }
                        default { "status-low" }
                    }
                    
                    $htmlContent += @"
                            <tr>
                                <td>$($issue.Issue)</td>
                                <td><span class="status-badge $severityClass">$($issue.Severity)</span></td>
                                <td>$($issue.Description)</td>
                            </tr>
"@
                }
                
                $htmlContent += @"
                        </table>
"@
            }
            
            $htmlContent += @"
                    </div>
                </td>
            </tr>
"@
        }
        
        $htmlContent += @"
        </table>
"@
    }
    else {
        $htmlContent += @"
        <div class="info">
            <strong>No build definitions:</strong> No build definitions were found or analyzed.
        </div>
"@
    }
    
    $htmlContent += @"
    </div>
"@

    return $htmlContent
}

# Function to generate release details HTML
function New-ReleaseDetailsHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ReleaseResults
    )
    
    $htmlContent = @"
    <h2 id="releases">Release Analysis</h2>
    <div class="panel panel-full component-panel" data-component="release">
"@
    
    if ($ReleaseResults.Count -gt 0) {
        $htmlContent += @"
        <table>
            <tr>
                <th>Definition Name</th>
                <th>Success Rate</th>
                <th>Environments</th>
                <th>Security Issues</th>
                <th>Details</th>
            </tr>
"@
        
        foreach ($release in $ReleaseResults) {
            $successRate = "N/A"
            if ($release.PerformanceAnalysis -and $release.PerformanceAnalysis.TotalReleases -gt 0) {
                $successRate = "$($release.PerformanceAnalysis.RecentSuccessRate)%"
            }
            
            $securityIssuesCount = 0
            if ($release.SecurityAnalysis -and $release.SecurityAnalysis.SecurityIssues) {
                $securityIssuesCount = $release.SecurityAnalysis.SecurityIssues.Count
            }
            
            $detailsId = "release-details-$($release.DefinitionId)"
            
            $htmlContent += @"
            <tr>
                <td>$($release.DefinitionName)</td>
                <td>$successRate</td>
                <td>$($release.EnvironmentCount)</td>
                <td>$securityIssuesCount</td>
                <td><button onclick="toggleDetails('$detailsId')">Show/Hide</button></td>
            </tr>
            <tr>
                <td colspan="5">
                    <div id="$detailsId" style="display: none;">
                        <h4>Release Information</h4>
                        <p>
                            <strong>Definition ID:</strong> $($release.DefinitionId)<br/>
                            <strong>Created By:</strong> $($release.CreatedBy)<br/>
                            <strong>Created Date:</strong> $($release.CreatedDate)<br/>
                            <strong>URL:</strong> <a href="$($release.Url)" target="_blank">View in Azure DevOps</a>
                        </p>
"@
            
            # Environment statistics if available
            if ($release.PerformanceAnalysis -and $release.PerformanceAnalysis.EnvironmentStats -and $release.PerformanceAnalysis.EnvironmentStats.Count -gt 0) {
                $htmlContent += @"
                        <h4>Environment Performance</h4>
                        <table>
                            <tr>
                                <th>Environment</th>
                                <th>Success Rate</th>
                                <th>Deployments</th>
                                <th>Avg Duration</th>
                            </tr>
"@
                
                foreach ($envName in $release.PerformanceAnalysis.EnvironmentStats.Keys) {
                    $env = $release.PerformanceAnalysis.EnvironmentStats[$envName]
                    
                    $htmlContent += @"
                            <tr>
                                <td>$envName</td>
                                <td>$($env.SuccessRate)%</td>
                                <td>$($env.TotalDeployments)</td>
                                <td>$([math]::Round($env.AverageDuration, 1)) min</td>
                            </tr>
"@
                }
                
                $htmlContent += @"
                        </table>
"@
            }
            
            # Security issues if available
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
                        "High" { "status-high" }
                        "Medium" { "status-medium" }
                        "Low" { "status-low" }
                        default { "status-low" }
                    }
                    
                    $htmlContent += @"
                            <tr>
                                <td>$($issue.Issue)</td>
                                <td><span class="status-badge $severityClass">$($issue.Severity)</span></td>
                                <td>$($issue.Description)</td>
                            </tr>
"@
                }
                
                $htmlContent += @"
                        </table>
"@
            }
            
            $htmlContent += @"
                    </div>
                </td>
            </tr>
"@
        }
        
        $htmlContent += @"
        </table>
"@
    }
    else {
        $htmlContent += @"
        <div class="info">
            <strong>No release definitions:</strong> No release definitions were found or analyzed.
        </div>
"@
    }
    
    $htmlContent += @"
    </div>
"@

    return $htmlContent
}

# Function to combine all the detailed HTML sections and add footer
# Modify the New-CompleteDetailsHtml function in Dashboard-HTML-Details.ps1 to ensure
# repo and pipeline sections are always included, even when no results are available.
# Here's the section to modify:

function New-CompleteDetailsHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$RepoResults,
        
        [Parameter(Mandatory = $false)]
        [object]$PipelineResults,
        
        [Parameter(Mandatory = $false)]
        [object]$BuildResults,
        
        [Parameter(Mandatory = $false)]
        [object]$ReleaseResults
    )
    
    $htmlContent = ""
    
    # Close the dashboard grid from part 1
    $htmlContent += @"
        </div>
"@
    
    # Always include repository section, even if no results available
    # This ensures the section is always displayed
    $htmlContent += New-RepositoryDetailsHtml -RepoResults $(if ($RepoResults) { $RepoResults } else { @() })
    
    # Always include pipeline section, even if no results available
    $htmlContent += New-PipelineDetailsHtml -PipelineResults $(if ($PipelineResults) { $PipelineResults } else { @() })
    
    # Add build details if available
    if ($BuildResults) {
        $htmlContent += New-BuildDetailsHtml -BuildResults $BuildResults
    }
    
    # Add release details if available
    if ($ReleaseResults) {
        $htmlContent += New-ReleaseDetailsHtml -ReleaseResults $ReleaseResults
    }
    
    
    # Add footer and close HTML tags
    $htmlContent += @"
        <div class="footer">
            <p>Dizzy - Azure DevOps Analyzer | Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
    </div>
</body>
</html>
"@
    
    return $htmlContent
}

# Main function to create complete dashboard HTML
function New-DashboardHtml {
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
        [object]$ReleaseResults,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    # Get summary HTML from part 1
    $summaryHtml = New-DashboardSummaryHtml -ScanInfo $ScanInfo -RepoResults $RepoResults -PipelineResults $PipelineResults -BuildResults $BuildResults -ReleaseResults $ReleaseResults
    
    # Get details HTML from part 2
    $detailsHtml = New-CompleteDetailsHtml -RepoResults $RepoResults -PipelineResults $PipelineResults -BuildResults $BuildResults -ReleaseResults $ReleaseResults
    
    # Combine HTML parts
    $fullHtml = $summaryHtml + $detailsHtml
    
    # Save HTML to file
    $fullHtml | Out-File -FilePath $OutputPath -Force
    
    Write-Host "Dashboard HTML created at: $OutputPath" -ForegroundColor Green
    
    return $OutputPath
}

# Export functions
#Export-ModuleMember -Function New-DashboardHtml, New-CompleteDetailsHtml
