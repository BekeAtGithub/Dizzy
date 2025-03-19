# Dizzy - Azure DevOps Analyzer
# Security findings HTML generator - Part 2 (Statistics functions)

# Function to calculate security statistics
function Get-SecurityStatistics {
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
    
    $stats = @{
        TotalFindings = 0
        HighSeverity = 0
        MediumSeverity = 0
        LowSeverity = 0
        RepoFindings = 0
        PipelineFindings = 0
        BuildFindings = 0
        ReleaseFindings = 0
        HighPercent = 0
        MediumPercent = 0
        LowPercent = 0
        HighDegrees = 0
        MediumDegrees = 0
    }
    
    # Count repo findings
    if ($RepoResults) {
        foreach ($repo in $RepoResults) {
            if ($repo.Findings) {
                $stats.RepoFindings += $repo.Findings.Count
                $stats.TotalFindings += $repo.Findings.Count
                $stats.HighSeverity += $repo.Findings.Count  # All repo findings are considered high severity
            }
        }
    }
    
    # Count pipeline findings
    if ($PipelineResults) {
        foreach ($pipeline in $PipelineResults) {
            if ($pipeline.Findings) {
                $stats.PipelineFindings += $pipeline.Findings.Count
                $stats.TotalFindings += $pipeline.Findings.Count
                
                foreach ($finding in $pipeline.Findings) {
                    switch ($finding.Severity) {
                        "High" { $stats.HighSeverity++ }
                        "Medium" { $stats.MediumSeverity++ }
                        "Low" { $stats.LowSeverity++ }
                        default { $stats.LowSeverity++ }
                    }
                }
            }
        }
    }
    
    # Count build findings
    if ($BuildResults) {
        foreach ($build in $BuildResults) {
            if ($build.SecurityAnalysis -and $build.SecurityAnalysis.SecurityIssues) {
                $stats.BuildFindings += $build.SecurityAnalysis.SecurityIssues.Count
                $stats.TotalFindings += $build.SecurityAnalysis.SecurityIssues.Count
                
                foreach ($issue in $build.SecurityAnalysis.SecurityIssues) {
                    switch ($issue.Severity) {
                        "High" { $stats.HighSeverity++ }
                        "Medium" { $stats.MediumSeverity++ }
                        "Low" { $stats.LowSeverity++ }
                        default { $stats.LowSeverity++ }
                    }
                }
            }
        }
    }
    
    # Count release findings
    if ($ReleaseResults) {
        foreach ($release in $ReleaseResults) {
            if ($release.SecurityAnalysis -and $release.SecurityAnalysis.SecurityIssues) {
                $stats.ReleaseFindings += $release.SecurityAnalysis.SecurityIssues.Count
                $stats.TotalFindings += $release.SecurityAnalysis.SecurityIssues.Count
                
                foreach ($issue in $release.SecurityAnalysis.SecurityIssues) {
                    switch ($issue.Severity) {
                        "High" { $stats.HighSeverity++ }
                        "Medium" { $stats.MediumSeverity++ }
                        "Low" { $stats.LowSeverity++ }
                        default { $stats.LowSeverity++ }
                    }
                }
            }
        }
    }
    
    # Calculate percentages for doughnut chart
    if ($stats.TotalFindings -gt 0) {
        $stats.HighPercent = [math]::Round(($stats.HighSeverity / $stats.TotalFindings) * 100)
        $stats.MediumPercent = [math]::Round(($stats.MediumSeverity / $stats.TotalFindings) * 100)
        $stats.LowPercent = [math]::Round(($stats.LowSeverity / $stats.TotalFindings) * 100)
        
        # Calculate conic gradient degrees
        $stats.HighDegrees = [math]::Round(($stats.HighSeverity / $stats.TotalFindings) * 360)
        $stats.MediumDegrees = [math]::Round(($stats.MediumSeverity / $stats.TotalFindings) * 360) + $stats.HighDegrees
    }
    
    return $stats
}

# Function to generate the summary section HTML
function New-SecuritySummarySection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SecurityStats
    )
    
    $htmlContent = @"
        <div class="summary-section">
            <h2>Security Findings Summary</h2>
            
            <div class="doughnut-chart">
                <div class="doughnut" style="background: conic-gradient(#d13438 0deg $($SecurityStats.HighDegrees)deg, #ff8c00 $($SecurityStats.HighDegrees)deg $($SecurityStats.MediumDegrees)deg, #107c10 $($SecurityStats.MediumDegrees)deg 360deg);">
                    <div class="doughnut-hole">$($SecurityStats.TotalFindings)</div>
                </div>
                <div class="legend">
                    <div class="legend-item">
                        <div class="legend-color high-color"></div>
                        <div>High: $($SecurityStats.HighSeverity) ($($SecurityStats.HighPercent)%)</div>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color medium-color"></div>
                        <div>Medium: $($SecurityStats.MediumSeverity) ($($SecurityStats.MediumPercent)%)</div>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color low-color"></div>
                        <div>Low: $($SecurityStats.LowSeverity) ($($SecurityStats.LowPercent)%)</div>
                    </div>
                </div>
            </div>
            
            <div class="stat-container">
                <div class="stat-item">
                    <div class="stat-value">$($SecurityStats.RepoFindings)</div>
                    <div class="stat-label">Repository Findings</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$($SecurityStats.PipelineFindings)</div>
                    <div class="stat-label">Pipeline Findings</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$($SecurityStats.BuildFindings)</div>
                    <div class="stat-label">Build Findings</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$($SecurityStats.ReleaseFindings)</div>
                    <div class="stat-label">Release Findings</div>
                </div>
            </div>
"@
    
    # Add status message based on findings
    if ($SecurityStats.TotalFindings -gt 0) {
        if ($SecurityStats.HighSeverity -gt 0) {
            $htmlContent += @"
            <div class="error">
                <strong>Critical Security Issues:</strong> Found $($SecurityStats.HighSeverity) high severity security issues that require immediate attention.
                <p>These issues may include exposed credentials, hardcoded secrets, or critical security misconfigurations that pose significant risk.</p>
            </div>
"@
        }
        
        if ($SecurityStats.MediumSeverity -gt 0) {
            $htmlContent += @"
            <div class="warning">
                <strong>Security Concerns:</strong> Found $($SecurityStats.MediumSeverity) medium severity issues that should be addressed soon.
                <p>These issues may pose security risks or represent significant deviations from best practices.</p>
            </div>
"@
        }
        
        # Add recommendations based on findings
        $htmlContent += @"
            <h3>Security Recommendations</h3>
"@
        
        if ($SecurityStats.RepoFindings -gt 0) {
            $htmlContent += @"
            <div class="recommendation">
                <h4>Repository Security</h4>
                <ul>
                    <li>Remove all hardcoded secrets, API keys, and credentials from source code</li>
                    <li>Use Azure Key Vault or similar secret management solutions</li>
                    <li>Implement branch protection rules to prevent direct commits to main branches</li>
                    <li>Consider using pre-commit hooks to scan for secrets before they're committed</li>
                </ul>
            </div>
"@
        }
        
        if ($SecurityStats.PipelineFindings -gt 0) {
            $htmlContent += @"
            <div class="recommendation">
                <h4>Pipeline Security</h4>
                <ul>
                    <li>Replace hardcoded secrets with secure pipeline variables</li>
                    <li>Avoid using plain text secrets in pipeline definitions</li>
                    <li>Set timeout limits for pipelines to prevent runaway jobs</li>
                    <li>Use latest agent pools and runtime versions</li>
                </ul>
            </div>
"@
        }
        
        if ($SecurityStats.BuildFindings -gt 0 -or $SecurityStats.ReleaseFindings -gt 0) {
            $htmlContent += @"
            <div class="recommendation">
                <h4>Build and Release Security</h4>
                <ul>
                    <li>Implement approval checks for production deployments</li>
                    <li>Avoid reusing credentials across environments</li>
                    <li>Implement quality gates and automated security scans</li>
                    <li>Restrict access to deployment credentials and service connections</li>
                </ul>
            </div>
"@
        }
    }
    else {
        $htmlContent += @"
            <div class="success">
                <strong>Great job!</strong> No security issues were found in your Azure DevOps environment.
                <p>Continue to monitor for new issues as your projects evolve.</p>
            </div>
"@
    }
    
    $htmlContent += @"
            <p class="timestamp">Analysis completed on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
"@
    
    return $htmlContent
}

# Export functions
Export-ModuleMember -Function Get-SecurityStatistics, New-SecuritySummarySection