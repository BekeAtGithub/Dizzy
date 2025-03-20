# Dizzy - Azure DevOps Analyzer
# Pipeline analyzer module for detecting security issues and best practices

# Import authentication module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$authModulePath = Join-Path -Path $scriptPath -ChildPath "ADO-Authentication.ps1"
. $authModulePath

# Create a global variable to store scan results
$script:pipelineAnalysisResults = @()

# Patterns to check in pipeline definitions
$pipelinePatterns = @{
    # Security Issues
    "Hardcoded Password" = @{
        # Using here-strings for complex regex patterns
        Pattern = @'
(?i)password\s*[:=]\s*['""][^'"]+['""]
'@
        Severity = "High"
        Description = "Hardcoded password detected. Use secure variables instead."
    }
    "Hardcoded Token" = @{
        Pattern = @'
(?i)(token|api[._-]*key)\s*[:=]\s*['""][^'"]+['""]
'@
        Severity = "High"
        Description = "Hardcoded token or API key detected. Use secure variables instead."
    }
    "Plain Text Secret Variable" = @{
        Pattern = @'
(?i)variables:\s*\n\s*[^#\n]*?(password|secret|token|key).*?:\s*[^\n]+\n
'@
        Severity = "High"
        Description = "Plain text secret variable found. Use secret variables with the 'secure: true' attribute."
    }
    "Insecure Command Execution" = @{
        Pattern = @'
(?i)exec\s*:\s*.*?(sh|bash|cmd|powershell)\s.*?-.*?(c|command|e|expression)
'@
        Severity = "Medium"
        Description = "Potentially unsafe command execution with shell interpreters. Review for injection risks."
    }
    
    # Best Practices
    "Missing Timeout" = @{
        Pattern = @'
(?i)jobs:\s*\n(?:.*?\n)*?(?!\s*timeoutInMinutes)
'@
        Severity = "Low"
        Description = "Pipeline or job is missing a timeout setting. Add 'timeoutInMinutes' to prevent runaway jobs."
    }
    "Outdated Agent Pool" = @{
        Pattern = @'
(?i)pool:\s*\n\s*vmImage:\s*'?(vs2017-win2016|ubuntu-16\.04|macOS-10\.14)'?
'@
        Severity = "Low"
        Description = "Using outdated agent pool. Consider upgrading to the latest version."
    }
    "Missing Pipeline Trigger" = @{
        Pattern = @'
(?i)(?!trigger:)(?!pr:)(?!schedules:).*?steps:
'@
        Severity = "Low"
        Description = "Pipeline is missing explicit trigger configuration."
    }
    "Self Hosted Agent" = @{
        Pattern = @'
(?i)pool:\s*\n\s*name:\s*'[^']+
'@
        Severity = "Info"
        Description = "Using self-hosted agent pool. Ensure it's properly secured and patched."
    }
    "Using Scripts Task" = @{
        Pattern = @'
(?i)task:\s*'?Scripts'?
'@
        Severity = "Info"
        Description = "Using the Scripts task which executes scripts. Ensure input validation."
    }
}

# Function to get all pipelines or a specific pipeline
function Get-AzureDevOpsPipelines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PipelineId
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    # Get all pipelines first
    $pipelinesUrl = $endpoints.Pipeline.Pipelines
    $pipelines = Invoke-AzureDevOpsApi -Uri $pipelinesUrl
    
    if ($null -eq $pipelines -or $null -eq $pipelines.value) {
        Write-Error "Failed to get pipelines."
        return $null
    }
    
    # Filter by ID if specified
    if (-not [string]::IsNullOrWhiteSpace($PipelineId)) {
        $pipelines.value = $pipelines.value | Where-Object { $_.id -eq $PipelineId }
    }
    
    Write-Host "Found $($pipelines.value.Count) pipelines" -ForegroundColor Cyan
    return $pipelines.value
}

# Function to get pipeline definition
function Get-PipelineDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PipelineId
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $pipelineUrl = $endpoints.Pipeline.Pipeline -replace "{pipelineId}", $PipelineId
    $pipeline = Invoke-AzureDevOpsApi -Uri $pipelineUrl
    
    if ($null -eq $pipeline) {
        Write-Error "Failed to get pipeline definition for pipeline ID $PipelineId."
        return $null
    }
    
    # Get pipeline YAML content
    if ($pipeline._links.yaml) {
        $yamlUrl = $pipeline._links.yaml.href
        $yaml = Invoke-AzureDevOpsApi -Uri $yamlUrl
        $pipeline | Add-Member -NotePropertyName "yamlContent" -NotePropertyValue $yaml
    }
    
    return $pipeline
}

# Function to get pipeline runs
function Get-PipelineRuns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PipelineId,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 10
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $runsUrl = $endpoints.Pipeline.Runs -replace "{pipelineId}", $PipelineId
    $runs = Invoke-AzureDevOpsApi -Uri $runsUrl
    
    if ($null -eq $runs -or $null -eq $runs.value) {
        Write-Error "Failed to get pipeline runs for pipeline ID $PipelineId."
        return $null
    }
    
    # Limit the number of runs
    if ($runs.value.Count -gt $MaxResults) {
        $runs.value = $runs.value | Select-Object -First $MaxResults
    }
    
    Write-Host "Found $($runs.value.Count) runs for pipeline ID $PipelineId" -ForegroundColor Cyan
    return $runs.value
}

# Function to scan pipeline YAML for issues
function Find-PipelineIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $true)]
        [string]$PipelineName
    )
    
    $findings = @()
    
    foreach ($pattern in $pipelinePatterns.GetEnumerator()) {
        $matches = [regex]::Matches($Content, $pattern.Value.Pattern)
        
        foreach ($match in $matches) {
            # Extract some context around the match
            $startIndex = [Math]::Max(0, $match.Index - 20)
            $length = [Math]::Min(40 + $match.Length, $Content.Length - $startIndex)
            $context = $Content.Substring($startIndex, $length)
            
            # Mask secrets in the context for security
            if ($pattern.Value.Severity -eq "High") {
                # Fixed replacement pattern using single quotes
                $context = $context -replace '["''][^\s"'']+["'']', "'***'"
            }
            
            $lineNumber = ($Content.Substring(0, $match.Index).Split("`n")).Count
            
            $findings += [PSCustomObject]@{
                PipelineName = $PipelineName
                LineNumber = $lineNumber
                IssueType = $pattern.Key
                Severity = $pattern.Value.Severity
                Description = $pattern.Value.Description
                Context = $context.Trim()
            }
        }
    }
    
    return $findings
}

# Function to scan a single pipeline
function Analyze-Pipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Pipeline,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeRuns,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRuns = 5
    )
    
    Write-Host "Analyzing pipeline: $($Pipeline.name) (ID: $($Pipeline.id))" -ForegroundColor Green
    
    # Get detailed pipeline definition
    $pipelineDefinition = Get-PipelineDefinition -PipelineId $Pipeline.id
    
    if ($null -eq $pipelineDefinition) {
        Write-Warning "Could not get definition for pipeline $($Pipeline.name)"
        return
    }
    
    $pipelineAnalysis = @{
        PipelineId = $Pipeline.id
        PipelineName = $Pipeline.name
        PipelineType = if ($pipelineDefinition.configuration.type) { $pipelineDefinition.configuration.type } else { "Unknown" }
        CreatedDate = if ($Pipeline.createdDate) { $Pipeline.createdDate } else { "Unknown" }
        Url = if ($Pipeline._links.web.href) { $Pipeline._links.web.href } else { "Unknown" }
        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Findings = @()
        Runs = @()
    }
    
    # Check if we have YAML content to scan
    if ($pipelineDefinition.yamlContent) {
        $findings = Find-PipelineIssues -Content $pipelineDefinition.yamlContent -PipelineName $Pipeline.name
        
        if ($findings.Count -gt 0) {
            Write-Host "Found $($findings.Count) issues in pipeline $($Pipeline.name)" -ForegroundColor Yellow
            $pipelineAnalysis.Findings += $findings
        }
    }
    else {
        Write-Warning "No YAML content found for pipeline $($Pipeline.name). Only YAML pipelines can be scanned."
    }
    
    # Get pipeline runs if requested
    if ($IncludeRuns) {
        $runs = Get-PipelineRuns -PipelineId $Pipeline.id -MaxResults $MaxRuns
        
        if ($null -ne $runs) {
            $pipelineAnalysis.Runs = $runs | Select-Object id, name, state, result, createdDate, finishedDate, url
        }
    }
    
    if ($pipelineAnalysis.Findings.Count -gt 0) {
        Write-Host "Found a total of $($pipelineAnalysis.Findings.Count) issues in pipeline $($Pipeline.name)" -ForegroundColor Red
    }
    else {
        Write-Host "No issues found in pipeline $($Pipeline.name)" -ForegroundColor Green
    }
    
    return $pipelineAnalysis
}

# Main function to analyze all pipelines or a specific one
function Start-PipelineAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PipelineId,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeRuns,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRuns = 5
    )
    
    Write-Host "Starting pipeline analysis..." -ForegroundColor Cyan
    
    # Test connection first
    if (-not (Test-AzureDevOpsConnection)) {
        Write-Error "Failed to connect to Azure DevOps. Please check your configuration."
        return
    }
    
    # Get all pipelines or a specific one
    $pipelines = Get-AzureDevOpsPipelines -PipelineId $PipelineId
    
    if ($null -eq $pipelines -or $pipelines.Count -eq 0) {
        Write-Error "No pipelines found to analyze."
        return
    }
    
    # Clear previous results
    $script:pipelineAnalysisResults = @()
    
    # Analyze each pipeline
    foreach ($pipeline in $pipelines) {
        $pipelineResults = Analyze-Pipeline -Pipeline $pipeline -IncludeRuns:$IncludeRuns -MaxRuns $MaxRuns
        
        if ($null -ne $pipelineResults) {
            $script:pipelineAnalysisResults += $pipelineResults
        }
    }
    
    Write-Host "Pipeline analysis completed. Analyzed $($pipelines.Count) pipelines." -ForegroundColor Green
    
    # Return results
    return $script:pipelineAnalysisResults
}

# Function to get the current analysis results
function Get-PipelineAnalysisResults {
    return $script:pipelineAnalysisResults
}

# Export functions - commented out to prevent error when not running as a module
# Export-ModuleMember -Function Start-PipelineAnalysis, Get-PipelineAnalysisResults
