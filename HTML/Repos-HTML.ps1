# Dizzy - Azure DevOps Analyzer
# Repository scan results HTML generator

# Function to generate HTML for repository scan results
function New-RepositoryScanHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$RepositoryResults,
        
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
    $htmlFilePath = Join-Path -Path $OutputFolder -ChildPath "Repositories-Scan-$timestamp.html"
    
    Write-Host "Generating repository scan HTML report..." -ForegroundColor Cyan
    
    # Create HTML header and styles
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dizzy - Repository Scan Results</title>
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
        .repo-section { background-color: white; border-radius: 5px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .repo-header { display: flex; justify-content: space-between; align-items: center; }
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
        .finding-type { display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; background-color: #fde7e9; color: #d13438; }
        .finding-context { font-family: monospace; background-color: #f6f8fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .badge { display: inline-block; margin-left: 10px; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; }
        .badge-count { background-color: #0078d4; color: white; }
        .collapsible { background-color: #f1f1f1; color: #444; cursor: pointer; padding: 18px; width: 100%; border: none; text-align: left; outline: none; font-size: 15px; margin-bottom: 1px; }
        .active, .collapsible:hover { background-color: #e0e0e0; }
        .collapsible:after { content: '\\002B'; color: #777; font-weight: bold; float: right; margin-left: 5px; }
        .active:after { content: "\\2212"; }
        .content { padding: 0 18px; max-height: 0; overflow: hidden; transition: max-height 0.2s ease-out; background-color: white; }
        .footer { text-align: center; margin-top: 40px; padding: 20px; color: #666; font-size: 0.9em; }
        .search-box { width: 100%; padding: 10px; margin-bottom: 20px; border: 1px solid #ddd; border-radius: 4px; }
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
        
        function searchFindings() {
            var input = document.getElementById('searchBox');
            var filter = input.value.toUpperCase();
            var repoSections = document.getElementsByClassName('repo-section');
            
            for (var i = 0; i < repoSections.length; i++) {
                var repoSection = repoSections[i];
                var repoNameElement = repoSection.getElementsByTagName('h3')[0];
                var repoName = repoNameElement.textContent || repoNameElement.innerText;
                var tables = repoSection.getElementsByTagName('table');
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
                
                // Show/hide repository section based on whether it has any matching findings
                if (repoName.toUpperCase().indexOf(filter) > -1 || findings > 0) {
                    repoSection.style.display = "";
                } else {
                    repoSection.style.display = "none";
                }
            }
        }
    </script>
</head>
<body>
    <header>
        <div class="container">
            <h1>Repository Scan Results</h1>
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
        <input type="text" id="searchBox" class="search-box" onkeyup="searchFindings()" placeholder="Search for file paths, types, or content...">
"@
    
    # Add summary section
    $totalRepos = $RepositoryResults.Count
    $reposWithFindings = ($RepositoryResults | Where-Object { $_.Findings -and $_.Findings.Count -gt 0 }).Count
    $totalFindings = 0
    $RepositoryResults | ForEach-Object { if ($_.Findings) { $totalFindings += $_.Findings.Count } }
    
    $htmlContent += @"
        <div class="summary-section">
            <h2>Scan Summary</h2>
            <div class="stat-container">
                <div class="stat-item">
                    <div class="stat-value">$totalRepos</div>
                    <div class="stat-label">Repositories Scanned</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$reposWithFindings</div>
                    <div class="stat-label">Repositories with Findings</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">$totalFindings</div>
                    <div class="stat-label">Total Findings</div>
                </div>
            </div>
"@
    
    # Add status message based on findings
    if ($totalFindings -gt 0) {
        $htmlContent += @"
            <div class="error">
                <strong>Warning:</strong> Found $totalFindings potential secrets or sensitive data in $reposWithFindings $(if ($reposWithFindings -eq 1) { "repository" } else { "repositories" }).
                <p>The findings may include API keys, passwords, tokens, or other sensitive information. Please review each finding and take appropriate action.</p>
            </div>
"@
    }
    else {
        $htmlContent += @"
            <div class="success">
                <strong>All Clear:</strong> No secrets or sensitive data were found in any repository.
            </div>
"@
    }
    
    $htmlContent += @"
            <p class="timestamp">Scan completed on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
"@
    
    # Add section for each repository
    $collapsibleIndex = 0
    foreach ($repo in $RepositoryResults) {
        $htmlContent += @"
        <div class="repo-section">
            <div class="repo-header">
                <h3>$($repo.RepositoryName)</h3>
                <span class="badge badge-count">$(if ($repo.Findings) { $repo.Findings.Count } else { 0 }) findings</span>
            </div>
            <p>
                <strong>Default Branch:</strong> $($repo.DefaultBranch)<br>
                <strong>URL:</strong> <a href="$($repo.Url)" target="_blank">$($repo.Url)</a><br>
                <strong>Scan Date:</strong> $($repo.ScanDate)<br>
                <strong>Scanned Files:</strong> $($repo.ScannedFilesCount) of $($repo.TotalFilesCount)
            </p>
"@
        
        # Add findings if any
        if ($repo.Findings -and $repo.Findings.Count -gt 0) {
            # Group findings by file path for collapsible sections
            $fileGroups = $repo.Findings | Group-Object -Property FilePath
            
            foreach ($fileGroup in $fileGroups) {
                $htmlContent += @"
            <button class="collapsible" onclick="toggleCollapsible($collapsibleIndex)">
                $($fileGroup.Name) <span class="badge badge-count">$($fileGroup.Count) findings</span>
            </button>
            <div class="content">
                <table>
                    <tr>
                        <th>Line</th>
                        <th>Type</th>
                        <th>Context</th>
                    </tr>
"@
                
                foreach ($finding in $fileGroup.Group) {
                    $htmlContent += @"
                    <tr>
                        <td>$($finding.LineNumber)</td>
                        <td><span class="finding-type">$($finding.PatternName)</span></td>
                        <td><div class="finding-context">$($finding.Context)</div></td>
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
        else {
            $htmlContent += @"
            <div class="success">
                <strong>No findings:</strong> No secrets or sensitive data were found in this repository.
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
            <p>Dizzy - Azure DevOps Analyzer | Repository Scan Results | Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
    </div>
    
    <script>
        // Initialize all collapsible sections
        var coll = document.getElementsByClassName("collapsible");
        for (var i = 0; i < coll.length; i++) {
            coll[i].addEventListener("click", function() {
                this.classList.toggle("active");
                var content = this.nextElementSibling;
                if (content.style.maxHeight) {
                    content.style.maxHeight = null;
                } else {
                    content.style.maxHeight = content.scrollHeight + "px";
                }
            });
        }
    </script>
</body>
</html>
"@
    
    # Save the HTML content to file
    $htmlContent | Out-File -FilePath $htmlFilePath -Force
    
    Write-Host "Repository scan HTML report created at: $htmlFilePath" -ForegroundColor Green
    
    return $htmlFilePath
}

# Export function
#Export-ModuleMember -Function New-RepositoryScanHtml
