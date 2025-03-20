# Dizzy - Azure DevOps Analyzer
# Security findings HTML generator - Part 1 (Main functions and HTML header)

# Function to generate consolidated HTML for all security findings
function New-SecurityOverviewHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$RepoResults,
        
        [Parameter(Mandatory = $false)]
        [object]$PipelineResults,
        
        [Parameter(Mandatory = $false)]
        [object]$BuildResults,
        
        [Parameter(Mandatory = $false)]
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
    $htmlFilePath = Join-Path -Path $OutputFolder -ChildPath "Security-Overview-$timestamp.html"
    
    Write-Host "Generating security overview HTML report..." -ForegroundColor Cyan
    
    # Get HTML header and styling
    $htmlContent = Get-SecurityReportHeader
    
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
        <input type="text" id="searchBox" class="search-box" onkeyup="searchFindings()" placeholder="Search for findings, severities, or source components...">
        
        <div class="filter-container">
            <strong>Filter by Severity: </strong>
            <button class="filter-button active" data-severity="all" onclick="filterBySeverity('all')">All</button>
            <button class="filter-button" data-severity="high" onclick="filterBySeverity('high')">High</button>
            <button class="filter-button" data-severity="medium" onclick="filterBySeverity('medium')">Medium</button>
            <button class="filter-button" data-severity="low" onclick="filterBySeverity('low')">Low</button>
        </div>
        
        <div class="filter-container">
            <strong>Filter by Source: </strong>
            <button class="filter-button active" data-source="all" onclick="filterBySource('all')">All</button>
            <button class="filter-button" data-source="repo" onclick="filterBySource('repo')">Repositories</button>
            <button class="filter-button" data-source="pipeline" onclick="filterBySource('pipeline')">Pipelines</button>
            <button class="filter-button" data-source="build" onclick="filterBySource('build')">Builds</button>
            <button class="filter-button" data-source="release" onclick="filterBySource('release')">Releases</button>
        </div>
"@
    
    # Calculate security statistics
    $securityStats = Get-SecurityStatistics -RepoResults $RepoResults -PipelineResults $PipelineResults -BuildResults $BuildResults -ReleaseResults $ReleaseResults
    
    # Add summary section with security statistics
    $htmlContent += New-SecuritySummarySection -SecurityStats $securityStats
    
    # Add detailed findings sections
    if ($RepoResults -and ($securityStats.RepoFindings -gt 0)) {
        $htmlContent += New-RepositoryFindingsSection -RepoResults $RepoResults -RepoFindings $securityStats.RepoFindings
    }
    
    if ($PipelineResults -and ($securityStats.PipelineFindings -gt 0)) {
        $htmlContent += New-PipelineFindingsSection -PipelineResults $PipelineResults -PipelineFindings $securityStats.PipelineFindings
    }
    
    if ($BuildResults -and ($securityStats.BuildFindings -gt 0)) {
        $htmlContent += New-BuildFindingsSection -BuildResults $BuildResults -BuildFindings $securityStats.BuildFindings
    }
    
    if ($ReleaseResults -and ($securityStats.ReleaseFindings -gt 0)) {
        $htmlContent += New-ReleaseFindingsSection -ReleaseResults $ReleaseResults -ReleaseFindings $securityStats.ReleaseFindings
    }
    
    # Add footer and close HTML tags
    $htmlContent += @"
        <div class="footer">
            <p>Dizzy - Azure DevOps Analyzer | Security Overview | Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
    </div>
</body>
</html>
"@
    
    # Save the HTML content to file
    $htmlContent | Out-File -FilePath $htmlFilePath -Force
    
    Write-Host "Security overview HTML report created at: $htmlFilePath" -ForegroundColor Green
    
    return $htmlFilePath
}

# Function to get HTML header and styling
function Get-SecurityReportHeader {
    $headerHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dizzy - Security Findings Overview</title>
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
        .findings-section { background-color: white; border-radius: 5px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .finding-header { display: flex; justify-content: space-between; align-items: center; }
        .stat-container { display: flex; flex-wrap: wrap; }
        .stat-item { flex: 1; min-width: 120px; margin: 10px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; color: #0078d4; }
        .stat-label { font-size: 0.9em; color: #666; }
        .warning { background-color: #fff4e5; border-left: 4px solid #ff8c00; padding: 10px 15px; margin: 10px 0; }
        .error { background-color: #fde7e9; border-left: 4px solid #d13438; padding: 10px 15px; margin: 10px 0; }
        .success { background-color: #dff6dd; border-left: 4px solid #107c10; padding: 10px 15px; margin: 10px 0; }
        .info { background-color: #f0f8ff; border-left: 4px solid #0078d4; padding: 10px 15px; margin: 10px 0; }
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
        .source-badge { display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 0.8em; margin-right: 5px; }
        .source-repo { background-color: #d4e7fa; color: #0078d4; }
        .source-pipeline { background-color: #dcf7f4; color: #067b6f; }
        .source-build { background-color: #f3e9f2; color: #62358f; }
        .source-release { background-color: #ffecc1; color: #986f0b; }
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
        .chart-container { height: 300px; margin: 20px 0; }
        .recommendation { background-color: #f0f8ff; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .recommendation h4 { margin-top: 0; color: #0078d4; }
        .doughnut-chart { display: flex; align-items: center; justify-content: center; margin: 20px 0; }
        .doughnut { width: 200px; height: 200px; border-radius: 50%; background: conic-gradient(#d13438 0deg, #ff8c00 0deg, #107c10 0deg); margin-right: 30px; position: relative; }
        .doughnut-hole { width: 120px; height: 120px; border-radius: 50%; background: white; position: absolute; top: 40px; left: 40px; display: flex; align-items: center; justify-content: center; font-size: 1.5em; font-weight: bold; color: #333; }
        .legend { display: flex; flex-direction: column; }
        .legend-item { display: flex; align-items: center; margin-bottom: 10px; }
        .legend-color { width: 20px; height: 20px; margin-right: 10px; border-radius: 3px; }
        .high-color { background-color: #d13438; }
        .medium-color { background-color: #ff8c00; }
        .low-color { background-color: #107c10; }
    </style>
    <script>
        function searchFindings() {
            var input = document.getElementById('searchBox');
            var filter = input.value.toUpperCase();
            var tables = document.getElementsByTagName('table');
            
            for (var t = 0; t < tables.length; t++) {
                var table = tables[t];
                var rows = table.getElementsByTagName('tr');
                var tableHasMatches = false;
                
                // Skip header row
                for (var i = 1; i < rows.length; i++) {
                    var row = rows[i];
                    var cells = row.getElementsByTagName('td');
                    var rowHasMatch = false;
                    
                    for (var j = 0; j < cells.length; j++) {
                        var cell = cells[j];
                        if (cell) {
                            var txtValue = cell.textContent || cell.innerText;
                            if (txtValue.toUpperCase().indexOf(filter) > -1) {
                                rowHasMatch = true;
                                tableHasMatches = true;
                                break;
                            }
                        }
                    }
                    
                    if (rowHasMatch) {
                        row.style.display = "";
                    } else {
                        row.style.display = "none";
                    }
                }
                
                // Show/hide section based on matches
                var sectionId = table.getAttribute('data-section');
                if (sectionId) {
                    var section = document.getElementById(sectionId);
                    if (section) {
                        if (filter === "") {
                            section.style.display = ""; // Show all sections when filter is cleared
                        } else {
                            section.style.display = tableHasMatches ? "" : "none";
                        }
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
            
            var rows = document.getElementsByTagName('tr');
            for (var i = 1; i < rows.length; i++) { // Skip header row
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
        
        function filterBySource(source) {
            var buttons = document.getElementsByClassName('filter-button');
            for (var i = 0; i < buttons.length; i++) {
                if (buttons[i].getAttribute('data-source') === source || (source === 'all' && buttons[i].getAttribute('data-source') === 'all')) {
                    buttons[i].classList.add('active');
                } else {
                    buttons[i].classList.remove('active');
                }
            }
            
            var sections = document.getElementsByClassName('findings-section');
            for (var i = 0; i < sections.length; i++) {
                var sectionSource = sections[i].getAttribute('data-source');
                if (source === 'all' || sectionSource === source) {
                    sections[i].style.display = "";
                } else {
                    sections[i].style.display = "none";
                }
            }
        }
    </script>
</head>
<body>
    <header>
        <div class="container">
            <h1>Security Findings Overview</h1>
            <p>Dizzy - Azure DevOps Analyzer</p>
        </div>
    </header>
    
    <div class="container">
"@

    return $headerHtml
}

# Import the additional security HTML generator functions from part 2
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$securityHtmlPart2Path = Join-Path -Path $scriptPath -ChildPath "Security-HTML-Stats.ps1"
$securityHtmlPart3Path = Join-Path -Path $scriptPath -ChildPath "Security-HTML-Sections.ps1"

if (Test-Path $securityHtmlPart2Path) {
    . $securityHtmlPart2Path
}
else {
    Write-Warning "Could not find Security-HTML-Stats.ps1 at $securityHtmlPart2Path"
}

if (Test-Path $securityHtmlPart3Path) {
    . $securityHtmlPart3Path
}
else {
    Write-Warning "Could not find Security-HTML-Sections.ps1 at $securityHtmlPart3Path"
}

# Export function
#Export-ModuleMember -Function New-SecurityOverviewHtml, Get-SecurityReportHeader
