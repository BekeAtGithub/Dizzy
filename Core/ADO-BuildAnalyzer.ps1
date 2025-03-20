# Dizzy - Azure DevOps Analyzer
# Build history and artifact analyzer module

# Import authentication module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$authModulePath = Join-Path -Path $scriptPath -ChildPath "ADO-Authentication.ps1"
. $authModulePath

# Create a global variable to store analysis results
$script:buildAnalysisResults = @()

# Function to get build definitions
function Get-BuildDefinitions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DefinitionName
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $definitionsUrl = $endpoints.Build.Definitions
    $definitions = Invoke-AzureDevOpsApi -Uri $definitionsUrl
    
    if ($null -eq $definitions -or $null -eq $definitions.value) {
        Write-Error "Failed to get build definitions."
        return $null
    }
    
    # Filter by name if specified
    if (-not [string]::IsNullOrWhiteSpace($DefinitionName)) {
        $definitions.value = $definitions.value | Where-Object { $_.name -eq $DefinitionName }
    }
    
    Write-Host "Found $($definitions.value.Count) build definitions" -ForegroundColor Cyan
    return $definitions.value
}

# Function to get build definition details
function Get-BuildDefinitionDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefinitionId
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $definitionUrl = $endpoints.Build.Definition -replace "{definitionId}", $DefinitionId
    $definition = Invoke-AzureDevOpsApi -Uri $definitionUrl
    
    if ($null -eq $definition) {
        Write-Error "Failed to get build definition details for ID $DefinitionId."
        return $null
    }
    
    return $definition
}

# Function to get recent builds
function Get-RecentBuilds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DefinitionId,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 20,
        
        [Parameter(Mandatory = $false)]
        [int]$DaysToLookBack = 30
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $minTime = [DateTime]::UtcNow.AddDays(-$DaysToLookBack).ToString("o")
    
    $buildsUrl = $endpoints.Build.Builds + "&minTime=$minTime"
    
    # Add definition filter if specified
    if (-not [string]::IsNullOrWhiteSpace($DefinitionId)) {
        $buildsUrl += "&definitions=$DefinitionId"
    }
    
    $builds = Invoke-AzureDevOpsApi -Uri $buildsUrl
    
    if ($null -eq $builds -or $null -eq $builds.value) {
        Write-Error "Failed to get recent builds."
        return $null
    }
    
    # Sort by finish time descending and limit results
    $recentBuilds = $builds.value | 
                   Sort-Object -Property finishTime -Descending | 
                   Select-Object -First $MaxResults
    
    Write-Host "Found $($recentBuilds.Count) recent builds" -ForegroundColor Cyan
    return $recentBuilds
}

# Function to get build artifacts
function Get-BuildArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuildId
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $artifactsUrl = $endpoints.Build.Artifacts -replace "{buildId}", $BuildId
    $artifacts = Invoke-AzureDevOpsApi -Uri $artifactsUrl
    
    if ($null -eq $artifacts -or $null -eq $artifacts.value) {
        Write-Verbose "No artifacts found for build ID $BuildId."
        return @()
    }
    
    Write-Verbose "Found $($artifacts.value.Count) artifacts for build ID $BuildId"
    return $artifacts.value
}

# Function to get build timeline (tasks and steps)
function Get-BuildTimeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuildId
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $timelineUrl = $endpoints.Build.Timeline -replace "{buildId}", $BuildId
    $timeline = Invoke-AzureDevOpsApi -Uri $timelineUrl
    
    if ($null -eq $timeline -or $null -eq $timeline.records) {
        Write-Verbose "No timeline records found for build ID $BuildId."
        return @()
    }
    
    Write-Verbose "Found $($timeline.records.Count) timeline records for build ID $BuildId"
    return $timeline.records
}

# Function to analyze build failures
function Analyze-BuildFailures {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Builds
    )
    
    $failureAnalysis = @{
        TotalBuilds = $Builds.Count
        FailedBuilds = 0
        SuccessfulBuilds = 0
        PartiallySuccessfulBuilds = 0
        CanceledBuilds = 0
        AverageQueueTime = 0
        AverageDuration = 0
        MostCommonFailures = @()
        RecentFailureRate = 0
    }
    
    $buildDurations = @()
    $queueDurations = @()
    $failureReasons = @{}
    
    foreach ($build in $Builds) {
        # Count by result
        switch ($build.result) {
            "succeeded" { $failureAnalysis.SuccessfulBuilds++ }
            "partiallySucceeded" { $failureAnalysis.PartiallySuccessfulBuilds++ }
            "failed" { $failureAnalysis.FailedBuilds++ }
            "canceled" { $failureAnalysis.CanceledBuilds++ }
        }
        
        # Calculate duration if available
        if ($build.startTime -and $build.finishTime) {
            $startTime = [DateTime]$build.startTime
            $finishTime = [DateTime]$build.finishTime
            $duration = ($finishTime - $startTime).TotalMinutes
            $buildDurations += $duration
        }
        
        # Calculate queue time if available
        if ($build.queueTime -and $build.startTime) {
            $queueTime = [DateTime]$build.queueTime
            $startTime = [DateTime]$build.startTime
            $queueDuration = ($startTime - $queueTime).TotalMinutes
            $queueDurations += $queueDuration
        }
        
        # Collect failure reasons
        if ($build.result -eq "failed" -and $build.id) {
            # Get timeline to find failure details
            $timeline = Get-BuildTimeline -BuildId $build.id
            
            $failedTasks = $timeline | Where-Object { $_.result -eq "failed" }
            
            foreach ($failedTask in $failedTasks) {
                $failureDetail = if ($failedTask.issues) { 
                    $failedTask.issues | ForEach-Object { $_.message } | Select-Object -First 1 
                } else {
                    $failedTask.name
                }
                
                if (-not [string]::IsNullOrEmpty($failureDetail)) {
                    if ($failureReasons.ContainsKey($failureDetail)) {
                        $failureReasons[$failureDetail]++
                    } else {
                        $failureReasons[$failureDetail] = 1
                    }
                }
            }
        }
    }
    
    # Calculate average durations
    if ($buildDurations.Count -gt 0) {
        $failureAnalysis.AverageDuration = ($buildDurations | Measure-Object -Average).Average
    }
    
    if ($queueDurations.Count -gt 0) {
        $failureAnalysis.AverageQueueTime = ($queueDurations | Measure-Object -Average).Average
    }
    
    # Calculate failure rate
    if ($failureAnalysis.TotalBuilds -gt 0) {
        $failureAnalysis.RecentFailureRate = [math]::Round(($failureAnalysis.FailedBuilds / $failureAnalysis.TotalBuilds) * 100, 2)
    }
    
    # Get most common failure reasons
    $failureAnalysis.MostCommonFailures = $failureReasons.GetEnumerator() | 
                                         Sort-Object -Property Value -Descending | 
                                         Select-Object -First 5 | 
                                         ForEach-Object {
                                             [PSCustomObject]@{
                                                 Reason = $_.Key
                                                 Count = $_.Value
                                             }
                                         }
    
    return $failureAnalysis
}

# Function to analyze build artifacts
function Analyze-BuildArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Builds
    )
    
    $artifactAnalysis = @{
        TotalBuildsWithArtifacts = 0
        TotalArtifacts = 0
        ArtifactTypes = @{}
        LargestArtifactSize = 0
        LargestArtifactName = ""
        AverageSizePerBuild = 0
    }
    
    $totalSize = 0
    $buildCount = 0
    
    foreach ($build in $Builds) {
        if ($build.id) {
            $artifacts = Get-BuildArtifacts -BuildId $build.id
            
            if ($artifacts.Count -gt 0) {
                $artifactAnalysis.TotalBuildsWithArtifacts++
                $artifactAnalysis.TotalArtifacts += $artifacts.Count
                $buildCount++
                
                foreach ($artifact in $artifacts) {
                    # Track artifact types
                    $type = $artifact.resource.type
                    if ($artifactAnalysis.ArtifactTypes.ContainsKey($type)) {
                        $artifactAnalysis.ArtifactTypes[$type]++
                    } else {
                        $artifactAnalysis.ArtifactTypes[$type] = 1
                    }
                    
                    # Track artifact sizes
                    if ($artifact.resource.properties -and $artifact.resource.properties.artifactsize) {
                        $size = [long]$artifact.resource.properties.artifactsize
                        $totalSize += $size
                        
                        if ($size -gt $artifactAnalysis.LargestArtifactSize) {
                            $artifactAnalysis.LargestArtifactSize = $size
                            $artifactAnalysis.LargestArtifactName = $artifact.name
                        }
                    }
                }
            }
        }
    }
    
    # Calculate average size
    if ($buildCount -gt 0) {
        $artifactAnalysis.AverageSizePerBuild = $totalSize / $buildCount
    }
    
    # Convert artifact types to array
    $artifactAnalysis.ArtifactTypes = $artifactAnalysis.ArtifactTypes.GetEnumerator() | 
                                     ForEach-Object {
                                         [PSCustomObject]@{
                                             Type = $_.Key
                                             Count = $_.Value
                                         }
                                     }
    
    return $artifactAnalysis
}

# Function to analyze build security
function Analyze-BuildSecurity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition
    )
    
    $securityAnalysis = @{
        HasSecretVariables = $false
        SecretVariablesCount = 0
        AllowsScriptAccess = $false
        UsesDefaultAgentPool = $false
        DefaultBranch = ""
        HasScheduledTriggers = $false
        TriggersCount = 0
        SecurityIssues = @()
    }
    
    # Check for secret variables
    if ($Definition.variables) {
        $secretVars = $Definition.variables.PSObject.Properties | Where-Object { 
            $_.Value.PSObject.Properties.Name -contains "isSecret" -and $_.Value.isSecret -eq $true 
        }
        
        $securityAnalysis.HasSecretVariables = ($secretVars.Count -gt 0)
        $securityAnalysis.SecretVariablesCount = $secretVars.Count
    }
    
    # Check default branch for repository
    if ($Definition.repository) {
        $securityAnalysis.DefaultBranch = $Definition.repository.defaultBranch
    }
    
    # Check for script access
    if ($Definition.authorizationRestrictions) {
        $securityAnalysis.AllowsScriptAccess = $true
    }
    
    # Check agent pool
    if ($Definition.queue) {
        $securityAnalysis.UsesDefaultAgentPool = ($Definition.queue.pool.isHosted -eq $true)
    }
    
    # Check triggers
    if ($Definition.triggers) {
        $securityAnalysis.HasScheduledTriggers = ($Definition.triggers.Count -gt 0)
        $securityAnalysis.TriggersCount = $Definition.triggers.Count
    }
    
    # Look for potential security issues
    if (-not $securityAnalysis.UsesDefaultAgentPool) {
        $securityAnalysis.SecurityIssues += [PSCustomObject]@{
            Issue = "Custom agent pool"
            Description = "Build uses a custom agent pool. Ensure it's properly secured and patched."
            Severity = "Medium"
        }
    }
    
    if ($securityAnalysis.AllowsScriptAccess) {
        $securityAnalysis.SecurityIssues += [PSCustomObject]@{
            Issue = "Script access enabled"
            Description = "Build allows script access. Review the security implications."
            Severity = "Medium"
        }
    }
    
    if ($Definition.processParameters) {
        $passcodeParams = $Definition.processParameters | Where-Object { $_.Value -match "password|secret|key|token" }
        
        if ($passcodeParams.Count -gt 0) {
            $securityAnalysis.SecurityIssues += [PSCustomObject]@{
                Issue = "Sensitive parameter names"
                Description = "Build has parameters with sensitive names. Ensure they are properly secured."
                Severity = "High"
            }
        }
    }
    
    return $securityAnalysis
}

# Function to analyze a single build definition and its recent builds
function Analyze-BuildDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxBuilds = 20,
        
        [Parameter(Mandatory = $false)]
        [int]$DaysToLookBack = 30
    )
    
    Write-Host "Analyzing build definition: $($Definition.name) (ID: $($Definition.id))" -ForegroundColor Green
    
    # Get detailed definition
    $definitionDetails = Get-BuildDefinitionDetails -DefinitionId $Definition.id
    
    if ($null -eq $definitionDetails) {
        Write-Warning "Could not get details for build definition $($Definition.name)"
        return
    }
    
    # Get recent builds
    $recentBuilds = Get-RecentBuilds -DefinitionId $Definition.id -MaxResults $MaxBuilds -DaysToLookBack $DaysToLookBack
    
    $buildAnalysis = @{
        DefinitionId = $Definition.id
        DefinitionName = $Definition.name
        DefType = $Definition.type
        CreatedDate = $Definition.createdDate
        Url = $Definition.url
        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        RecentBuilds = $recentBuilds | Select-Object id, buildNumber, status, result, startTime, finishTime, sourceBranch
        FailureAnalysis = if ($recentBuilds.Count -gt 0) { Analyze-BuildFailures -Builds $recentBuilds } else { $null }
        ArtifactAnalysis = if ($recentBuilds.Count -gt 0) { Analyze-BuildArtifacts -Builds $recentBuilds } else { $null }
        SecurityAnalysis = Analyze-BuildSecurity -Definition $definitionDetails
    }
    
    return $buildAnalysis
}

# Main function to analyze all build definitions or a specific one
function Start-BuildAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DefinitionName,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxBuilds = 20,
        
        [Parameter(Mandatory = $false)]
        [int]$DaysToLookBack = 30
    )
    
    Write-Host "Starting build analysis..." -ForegroundColor Cyan
    
    # Test connection first
    if (-not (Test-AzureDevOpsConnection)) {
        Write-Error "Failed to connect to Azure DevOps. Please check your configuration."
        return
    }
    
    # Get all build definitions or a specific one
    $definitions = Get-BuildDefinitions -DefinitionName $DefinitionName
    
    if ($null -eq $definitions -or $definitions.Count -eq 0) {
        Write-Error "No build definitions found to analyze."
        return
    }
    
    # Clear previous results
    $script:buildAnalysisResults = @()
    
    # Analyze each build definition
    foreach ($definition in $definitions) {
        $definitionResults = Analyze-BuildDefinition -Definition $definition -MaxBuilds $MaxBuilds -DaysToLookBack $DaysToLookBack
        
        if ($null -ne $definitionResults) {
            $script:buildAnalysisResults += $definitionResults
        }
    }
    
    Write-Host "Build analysis completed. Analyzed $($definitions.Count) build definitions." -ForegroundColor Green
    
    # Return results
    return $script:buildAnalysisResults
}

# Function to get the current analysis results
function Get-BuildAnalysisResults {
    return $script:buildAnalysisResults
}

# Export functions
#Export-ModuleMember -Function Start-BuildAnalysis, Get-BuildAnalysisResults
