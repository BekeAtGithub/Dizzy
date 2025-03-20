# Dizzy - Azure DevOps Analyzer
# Security findings HTML generator - Part 3 (Detailed sections)

# Function to generate repository findings section
function New-RepositoryFindingsSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$RepoResults,
        
        [Parameter(Mandatory = $true)]
        [int]$RepoFindings
    )
    
    $htmlContent = @"
        <div id="repoFindings" class="findings-section" data-source="repo">
            <h2>Repository Findings <span class="badge badge-count">$RepoFindings</span></h2>
            <p>The following sensitive data and secrets were found in your code repositories:</p>
            
            <table data-section="repoFindings">
                <tr>
                    <th>Repository</th>
                    <th>File</th>
                    <th>Line</th>
                    <th>Type</th>
                    <th>Context</th>
                </tr>
"@
    
    foreach ($repo in $RepoResults) {
        if ($repo.Findings -and $repo.Findings.Count -gt 0) {
            foreach ($finding in $repo.Findings) {
                $htmlContent += @"
                <tr>
                    <td><span class="source-badge source-repo">Repo</span> $($repo.RepositoryName)</td>
                    <td>$($finding.FilePath)</td>
                    <td>$($finding.LineNumber)</td>
                    <td><span class="severity-badge severity-high" data-severity="high">$($finding.PatternName)</span></td>
                    <td><div class="code-context">$($finding.Context)</div></td>
                </tr>
"@
            }
        }
    }
    
    $htmlContent += @"
            </table>
        </div>
"@
    
    return $htmlContent
}

# Function to generate pipeline findings section
function New-PipelineFindingsSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$PipelineResults,
        
        [Parameter(Mandatory = $true)]
        [int]$PipelineFindings
    )
    
    $htmlContent = @"
        <div id="pipelineFindings" class="findings-section" data-source="pipeline">
            <h2>Pipeline Findings <span class="badge badge-count">$PipelineFindings</span></h2>
            <p>The following security issues were found in your pipeline definitions:</p>
            
            <table data-section="pipelineFindings">
                <tr>
                    <th>Pipeline</th>
                    <th>Line</th>
                    <th>Issue Type</th>
                    <th>Severity</th>
                    <th>Description</th>
                </tr>
"@
    
    foreach ($pipeline in $PipelineResults) {
        if ($pipeline.Findings -and $pipeline.Findings.Count -gt 0) {
            foreach ($finding in $pipeline.Findings) {
                $severityClass = switch ($finding.Severity) {
                    "High" { "severity-high" }
                    "Medium" { "severity-medium" }
                    "Low" { "severity-low" }
                    default { "severity-low" }
                }
                
                $severityLower = ($finding.Severity).ToLower()
                
                $htmlContent += @"
                <tr>
                    <td><span class="source-badge source-pipeline">Pipeline</span> $($pipeline.PipelineName)</td>
                    <td>$($finding.LineNumber)</td>
                    <td>$($finding.IssueType)</td>
                    <td><span class="severity-badge $severityClass" data-severity="$severityLower">$($finding.Severity)</span></td>
                    <td>$($finding.Description)</td>
                </tr>
"@
            }
        }
    }
    
    $htmlContent += @"
            </table>
        </div>
"@
    
    return $htmlContent
}

# Function to generate build findings section
function New-BuildFindingsSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$BuildResults,
        
        [Parameter(Mandatory = $true)]
        [int]$BuildFindings
    )
    
    $htmlContent = @"
        <div id="buildFindings" class="findings-section" data-source="build">
            <h2>Build Security Issues <span class="badge badge-count">$BuildFindings</span></h2>
            <p>The following security issues were found in your build definitions:</p>
            
            <table data-section="buildFindings">
                <tr>
                    <th>Build Definition</th>
                    <th>Issue</th>
                    <th>Severity</th>
                    <th>Description</th>
                </tr>
"@
    
    foreach ($build in $BuildResults) {
        if ($build.SecurityAnalysis -and $build.SecurityAnalysis.SecurityIssues -and $build.SecurityAnalysis.SecurityIssues.Count -gt 0) {
            foreach ($issue in $build.SecurityAnalysis.SecurityIssues) {
                $severityClass = switch ($issue.Severity) {
                    "High" { "severity-high" }
                    "Medium" { "severity-medium" }
                    "Low" { "severity-low" }
                    default { "severity-low" }
                }
                
                $severityLower = ($issue.Severity).ToLower()
                
                $htmlContent += @"
                <tr>
                    <td><span class="source-badge source-build">Build</span> $($build.DefinitionName)</td>
                    <td>$($issue.Issue)</td>
                    <td><span class="severity-badge $severityClass" data-severity="$severityLower">$($issue.Severity)</span></td>
                    <td>$($issue.Description)</td>
                </tr>
"@
            }
        }
    }
    
    $htmlContent += @"
            </table>
        </div>
"@
    
    return $htmlContent
}

# Function to generate release findings section
function New-ReleaseFindingsSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ReleaseResults,
        
        [Parameter(Mandatory = $true)]
        [int]$ReleaseFindings
    )
    
    $htmlContent = @"
        <div id="releaseFindings" class="findings-section" data-source="release">
            <h2>Release Security Issues <span class="badge badge-count">$ReleaseFindings</span></h2>
            <p>The following security issues were found in your release definitions:</p>
            
            <table data-section="releaseFindings">
                <tr>
                    <th>Release Definition</th>
                    <th>Issue</th>
                    <th>Severity</th>
                    <th>Description</th>
                </tr>
"@
    
    foreach ($release in $ReleaseResults) {
        if ($release.SecurityAnalysis -and $release.SecurityAnalysis.SecurityIssues -and $release.SecurityAnalysis.SecurityIssues.Count -gt 0) {
            foreach ($issue in $release.SecurityAnalysis.SecurityIssues) {
                $severityClass = switch ($issue.Severity) {
                    "High" { "severity-high" }
                    "Medium" { "severity-medium" }
                    "Low" { "severity-low" }
                    default { "severity-low" }
                }
                
                $severityLower = ($issue.Severity).ToLower()
                
                $htmlContent += @"
                <tr>
                    <td><span class="source-badge source-release">Release</span> $($release.DefinitionName)</td>
                    <td>$($issue.Issue)</td>
                    <td><span class="severity-badge $severityClass" data-severity="$severityLower">$($issue.Severity)</span></td>
                    <td>$($issue.Description)$(if ($issue.Environments) { "<br><strong>Affected Environments:</strong> $($issue.Environments)" })</td>
                </tr>
"@
            }
        }
    }
    
    $htmlContent += @"
            </table>
        </div>
"@
    
    return $htmlContent
}

# Export functions
#Export-ModuleMember -Function New-RepositoryFindingsSection, New-PipelineFindingsSection, New-BuildFindingsSection, New-ReleaseFindingsSection
