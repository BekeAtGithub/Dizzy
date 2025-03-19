# Dizzy - Azure DevOps Analyzer
# Pipeline analysis results HTML generator

# Function to generate HTML for pipeline analysis results
function New-PipelineAnalysisHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$PipelineResults,
        
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
    $htmlFilePath = Join-Path -Path $OutputFolder -ChildPath "Pipelines-Analysis-$timestamp.html"
    
    Write-Host "Generating pipeline analysis HTML report..." -ForegroundColor Cyan
    
    # Create HTML header and styles
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dizzy - Pipeline Analysis Results</title>
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
        .pipeline-section { background-color: white; border-radius: 5px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .pipeline-header { display: flex; justify-content: space-between; align-items: center; }
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
        .code-context { font-family: monospace; background-color: #f6f8fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .badge { display: inline-block; margin-left: 10px; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; }
        .badge-count { background-color: #0078d4; color: white; }
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
        
        function searchIssues() {
            var input = document.getElementById('searchBox');
            var filter = input.value.toUpperCase();
            var pipelineSections = document.getElementsByClassName('pipeline-section');
            
            for (var i = 0; i < pipelineSections.length; i++) {
                var pipelineSection = pipelineSections[i];
                var pipelineNameElement = pipelineSection.getElementsByTagName('h3')[0];
                var pipelineName = pipelineNameElement.textContent || pipelineNameElement.innerText;
                var tables = pipelineSection.getElementsByTagName('table');
                var findings = 0;
                
                if (tables.length > 0) {
                    var rows = tables[0].getElementsByTagName('tr');
                    for (var j = 1; j < rows.length; j++) { // Skip header row
                        var row = rows[j];
                        var showRow = false;
                        
                        // Check if any cell contains the search term
                        var cells = row.getElementsByTagName('td');
                        for (var k = 0; k < cells.length; k++) {
                            var cellText = cells[k].textContent || cells[k].innerText;
                            if (cellText.toUpperCase().indexOf(filter) > -1) {
                                showRow = true;
                                break;
                            }
                        }
                        
                        if (showRow) {
                            row.style.display = "";
                            findings++;
                        } else {
                            row.style.display = "none";
                        }
                    }
                }
                
                // Show/hide pipeline section based on whether it has any matching findings
                if (pipelineName.toUpperCase().indexOf(filter) > -1 || findings > 0) {
                    pipelineSection.style.display = "";
                } else {
                    pipelineSection.style.display = "none";
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
            
            var rows = document.getElementsByTagName('tr');
            for (var i = 0; i < rows.length; i++) {
                var severityCell = rows[i].querySelector('.severity-badge');
                if (severityCell) {
                    var rowSeverity = severityCell.getAttribute('data-severity');
                    if (severity === 'all' || rowSeverity === severity) {
                        rows[i].style.display = "";
                    } else {
                        rows[i].style.display = "none";
                    }
                }
            }
        }
    </script>
</head>
<body>
    <header>
        <div class="container">
            <h1>Pipeline Analysis Results</h1>
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
        <input type="text" id="searchBox" class="search-box" onkeyup="searchIssues()" placeholder="Search for issues, severities, or content...">
        
        <div class="filter-container">
            <button class="filter-button active" data-severity="all" onclick="filterBySeverity('all')">All Severities</button>
            <button class="filter-button" data-severity="high" onclick="filterBySeverity('high')">High</button>
            <button class="filter-button" data-severity="medium" onclick="filterBySeverity('medium')">Medium</button>
            <button class="filter-button" data-severity="low" onclick="filterBySeverity('low')">Low</button>
        </div>
"@
    
    # Add summary section
    $totalPipelines = $PipelineResults.Count
    $pipelinesWithIssues = ($PipelineResults | Where-Object { $_.Findings -and $_.Findings.Count -gt 0 }).Count
    $totalIssues = 0
    $highIssues = 0
    $mediumIssues = 0
    $lowIssues = 0
    
    foreach ($pipeline in $PipelineResults) {
        if ($pipeline.Findings) {
            $totalIssues += $pipeline.Findings.Count
            
            foreach ($issue in $pipeline.Findings) {
                switch ($issue.Severity) {
                    "High" { $highIssues++ }
                    "Medium" { $mediumIssues++ }
                    "Low" { $lowIssues++ }
                }
            }
        }
    }
    
    $htmlContent += @"
        <div class="summary-section">
            <h2>Analysis Summary</h2>
            <div class="stat-container">
                <div class="stat-item">
                    <div class="stat-value">$totalPipelines</div>
                    <div class="stat-label">Pipelines Analyzed</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$pipelinesWithIssues</div>
                    <div class="stat-label">Pipelines with Issues</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$totalIssues</div>
                    <div class="stat-label">Total Issues</div>
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
    if ($totalIssues -gt 0) {
        if ($highIssues -gt 0) {
            $htmlContent += @"
            <div class="error">
                <strong>Warning:</strong> Found $highIssues high severity issues that require immediate attention.
                <p>High severity issues may include hardcoded credentials, security vulnerabilities, or other critical problems.</p>
            </div>
"@
        }
        
        if ($mediumIssues -gt 0) {
            $htmlContent += @"
            <div class="warning">
                <strong>Attention:</strong> Found $mediumIssues medium severity issues that should be addressed.
                <p>Medium severity issues may include insecure configurations, best practice violations, or potential security risks.</p>
            </div>
"@
        }
    }
    else {
        $htmlContent += @"
            <div class="success">
                <strong>All Clear:</strong> No issues found in pipeline definitions.
            </div>
"@
    }
    
    $htmlContent += @"
            <p class="timestamp">Analysis completed on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
"@
    
    # Add section for each pipeline with issues
    $collapsibleIndex = 0
    foreach ($pipeline in $PipelineResults) {
        # Only show pipelines with issues
        if ($pipeline.Findings -and $pipeline.Findings.Count -gt 0) {
            $htmlContent += @"
        <div class="pipeline-section">
            <div class="pipeline-header">
                <h3>$($pipeline.PipelineName)</h3>
                <span class="badge badge-count">$($pipeline.Findings.Count) issues</span>
            </div>
            <p>
                <strong>Pipeline Type:</strong> $($pipeline.PipelineType)<br>
                <strong>Created Date:</strong> $($pipeline.CreatedDate)<br>
                <strong>URL:</strong> <a href="$($pipeline.Url)" target="_blank">$($pipeline.Url)</a>
            </p>
            
            <table>
                <tr>
                    <th>Line</th>
                    <th>Issue Type</th>
                    <th>Severity</th>
                    <th>Description</th>
                    <th>Context</th>
                </tr>
"@
            
            foreach ($issue in $pipeline.Findings) {
                $severityClass = switch ($issue.Severity) {
                    "High" { "severity-high" }
                    "Medium" { "severity-medium" }
                    "Low" { "severity-low" }
                    default { "severity-low" }
                }
                
                $htmlContent += @"
                <tr>
                    <td>$($issue.LineNumber)</td>
                    <td>$($issue.IssueType)</td>
                    <td><span class="severity-badge $severityClass" data-severity="$(($issue.Severity).ToLower())">$($issue.Severity)</span></td>
                    <td>$($issue.Description)</td>
                    <td><div class="code-context">$($issue.Context)</div></td>
                </tr>
"@
            }
            
            $htmlContent += @"
            </table>
        </div>
"@
            $collapsibleIndex++
        }
    }
    
    # Add section for pipelines without issues if any exist
    $pipelinesWithoutIssues = $PipelineResults | Where-Object { -not $_.Findings -or $_.Findings.Count -eq 0 }
    if ($pipelinesWithoutIssues.Count -gt 0) {
        $htmlContent += @"
        <div class="pipeline-section">
            <h3>Pipelines Without Issues</h3>
            <p>These $($pipelinesWithoutIssues.Count) pipelines were analyzed and no issues were found:</p>
            <ul>
"@
        
        foreach ($pipeline in $pipelinesWithoutIssues) {
            $htmlContent += @"
                <li>$($pipeline.PipelineName)</li>
"@
        }
        
        $htmlContent += @"
            </ul>
        </div>
"@
    }
    
    # Add footer and close HTML tags
    $htmlContent += @"
        <div class="footer">
            <p>Dizzy - Azure DevOps Analyzer | Pipeline Analysis Results | Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
    </div>
</body>
</html>
"@
    
    # Save the HTML content to file
    $htmlContent | Out-File -FilePath $htmlFilePath -Force
    
    Write-Host "Pipeline analysis HTML report created at: $htmlFilePath" -ForegroundColor Green
    
    return $htmlFilePath
}

# Export function
Export-ModuleMember -Function New-PipelineAnalysisHtml