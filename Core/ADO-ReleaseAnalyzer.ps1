# Dizzy - Azure DevOps Analyzer
# Release definition and history analyzer module

# Import authentication module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$authModulePath = Join-Path -Path $scriptPath -ChildPath "ADO-Authentication.ps1"
. $authModulePath

# Create a global variable to store analysis results
$script:releaseAnalysisResults = @()

# Function to get release definitions
function Get-ReleaseDefinitions {
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
    
    $definitionsUrl = $endpoints.Release.Definitions
    $definitions = Invoke-AzureDevOpsApi -Uri $definitionsUrl
    
    if ($null -eq $definitions -or $null -eq $definitions.value) {
        Write-Error "Failed to get release definitions."
        return $null
    }
    
    # Filter by name if specified
    if (-not [string]::IsNullOrWhiteSpace($DefinitionName)) {
        $definitions.value = $definitions.value | Where-Object { $_.name -eq $DefinitionName }
    }
    
    Write-Host "Found $($definitions.value.Count) release definitions" -ForegroundColor Cyan
    return $definitions.value
}

# Function to get release definition details
function Get-ReleaseDefinitionDetails {
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
    
    $definitionUrl = $endpoints.Release.Definition -replace "{definitionId}", $DefinitionId
    $definition = Invoke-AzureDevOpsApi -Uri $definitionUrl
    
    if ($null -eq $definition) {
        Write-Error "Failed to get release definition details for ID $DefinitionId."
        return $null
    }
    
    return $definition
}

# Function to get recent releases
function Get-RecentReleases {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DefinitionId,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 20
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $releasesUrl = $endpoints.Release.Releases
    
    # Add definition filter if specified
    if (-not [string]::IsNullOrWhiteSpace($DefinitionId)) {
        $releasesUrl += "&definitionId=$DefinitionId"
    }
    
    $releases = Invoke-AzureDevOpsApi -Uri $releasesUrl
    
    if ($null -eq $releases -or $null -eq $releases.value) {
        Write-Error "Failed to get recent releases."
        return $null
    }
    
    # Sort by creation time descending and limit results
    $recentReleases = $releases.value | 
                     Sort-Object -Property createdOn -Descending | 
                     Select-Object -First $MaxResults
    
    Write-Host "Found $($recentReleases.Count) recent releases" -ForegroundColor Cyan
    return $recentReleases
}

# Function to get release details
function Get-ReleaseDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReleaseId
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $releaseUrl = $endpoints.Release.Release -replace "{releaseId}", $ReleaseId
    $release = Invoke-AzureDevOpsApi -Uri $releaseUrl
    
    if ($null -eq $release) {
        Write-Error "Failed to get release details for ID $ReleaseId."
        return $null
    }
    
    return $release
}

# Function to analyze release security
function Analyze-ReleaseSecurity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition
    )
    
    $securityAnalysis = @{
        HasSecretVariables = $false
        SecretVariablesCount = 0
        HasApprovalChecks = $false
        HasGates = $false
        AutoDeployEnabled = $false
        EnvironmentsCount = 0
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
    
    # Check environments
    if ($Definition.environments) {
        $securityAnalysis.EnvironmentsCount = $Definition.environments.Count
        
        # Check for approval checks
        $envWithApprovals = $Definition.environments | Where-Object {
            $_.preDeployApprovals.PSObject.Properties.Name -contains "approvals" -and
            $_.preDeployApprovals.approvals.Count -gt 0
        }
        
        $securityAnalysis.HasApprovalChecks = ($envWithApprovals.Count -gt 0)
        
        # Check for gates
        $envWithGates = $Definition.environments | Where-Object {
            $_.preDeploymentGates.PSObject.Properties.Name -contains "gates" -and
            $_.preDeploymentGates.gates.Count -gt 0
        }
        
        $securityAnalysis.HasGates = ($envWithGates.Count -gt 0)
        
        # Check auto-deploy settings
        $envWithAutoDeploy = $Definition.environments | Where-Object {
            ($_.conditions.Count -gt 0) -and
            ($_.conditions | Where-Object { $_.name -eq "ReleaseStarted" -and $_.value -eq "true" }).Count -gt 0
        }
        
        $securityAnalysis.AutoDeployEnabled = ($envWithAutoDeploy.Count -gt 0)
        
        # Look for production environments without approvals
        $prodEnvWithoutApprovals = $Definition.environments | Where-Object {
            ($_.name -like "*prod*" -or $_.name -like "*production*") -and
            (-not (
                $_.preDeployApprovals.PSObject.Properties.Name -contains "approvals" -and
                $_.preDeployApprovals.approvals.Count -gt 0
            ))
        }
        
        if ($prodEnvWithoutApprovals.Count -gt 0) {
            $securityAnalysis.SecurityIssues += [PSCustomObject]@{
                Issue = "Production environment without approvals"
                Description = "Production environment found without pre-deployment approval checks."
                Severity = "High"
                Environments = ($prodEnvWithoutApprovals | ForEach-Object { $_.name }) -join ", "
            }
        }
        
        # Check for environments using the same credentials across stages
        $envCredentialCount = @{}
        
        foreach ($env in $Definition.environments) {
            foreach ($deployPhase in $env.deployPhases) {
                if ($deployPhase.deploymentInput.PSObject.Properties.Name -contains "queueId") {
                    $queueId = $deployPhase.deploymentInput.queueId
                    
                    if ($envCredentialCount.ContainsKey($queueId)) {
                        $envCredentialCount[$queueId] += 1
                    } else {
                        $envCredentialCount[$queueId] = 1
                    }
                }
            }
        }
        
        $reusedCredentials = $envCredentialCount.GetEnumerator() | Where-Object { $_.Value -gt 1 }
        
        if ($reusedCredentials.Count -gt 0) {
            $securityAnalysis.SecurityIssues += [PSCustomObject]@{
                Issue = "Reused credentials across environments"
                Description = "Same service connection or agent pool used across multiple environments."
                Severity = "Medium"
                Count = $reusedCredentials.Count
            }
        }
    }
    
    # Check for use of deployment groups
    $usesDeploymentGroups = $Definition.environments | Where-Object {
        $_.deployPhases | Where-Object { $_.phaseType -eq "machineGroupBasedDeployment" }
    }
    
    if ($usesDeploymentGroups.Count -gt 0) {
        $securityAnalysis.SecurityIssues += [PSCustomObject]@{
            Issue = "Uses deployment groups"
            Description = "Release uses deployment groups. Ensure target machines are properly secured."
            Severity = "Medium"
            Environments = ($usesDeploymentGroups | ForEach-Object { $_.name }) -join ", "
        }
    }
    
    return $securityAnalysis
}

# Function to analyze release history performance
function Analyze-ReleasePerformance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Releases
    )
    
    $performanceAnalysis = @{
        TotalReleases = $Releases.Count
        SuccessfulReleases = 0
        FailedReleases = 0
        InProgressReleases = 0
        AverageDuration = 0
        EnvironmentStats = @{}
        RecentSuccessRate = 0
    }
    
    $releaseDurations = @()
    $environmentStats = @{}
    
    foreach ($release in $Releases) {
        # Get detailed release info
        $releaseDetails = Get-ReleaseDetails -ReleaseId $release.id
        
        if ($null -eq $releaseDetails) {
            continue
        }
        
        # Count by status
        switch ($releaseDetails.status) {
            "succeeded" { $performanceAnalysis.SuccessfulReleases++ }
            "partiallySucceeded" { $performanceAnalysis.SuccessfulReleases++ }
            "failed" { $performanceAnalysis.FailedReleases++ }
            "inProgress" { $performanceAnalysis.InProgressReleases++ }
        }
        
        # Calculate duration if available
        if ($releaseDetails.createdOn -and $releaseDetails.modifiedOn) {
            $createdTime = [DateTime]$releaseDetails.createdOn
            $modifiedTime = [DateTime]$releaseDetails.modifiedOn
            $duration = ($modifiedTime - $createdTime).TotalMinutes
            $releaseDurations += $duration
        }
        
        # Analyze environments
        if ($releaseDetails.environments) {
            foreach ($env in $releaseDetails.environments) {
                if (-not $environmentStats.ContainsKey($env.name)) {
                    $environmentStats[$env.name] = @{
                        TotalDeployments = 0
                        SuccessfulDeployments = 0
                        FailedDeployments = 0
                        AverageDuration = 0
                        DeploymentDurations = @()
                    }
                }
                
                $environmentStats[$env.name].TotalDeployments++
                
                if ($env.status -eq "succeeded" -or $env.status -eq "partiallySucceeded") {
                    $environmentStats[$env.name].SuccessfulDeployments++
                }
                elseif ($env.status -eq "failed") {
                    $environmentStats[$env.name].FailedDeployments++
                }
                
                # Calculate environment deployment duration
                if ($env.deploySteps -and $env.deploySteps.Count -gt 0) {
                    $firstStep = $env.deploySteps | Sort-Object -Property queuedOn | Select-Object -First 1
                    $lastStep = $env.deploySteps | Sort-Object -Property completedOn -Descending | Select-Object -First 1
                    
                    if ($firstStep.queuedOn -and $lastStep.completedOn) {
                        $startTime = [DateTime]$firstStep.queuedOn
                        $endTime = [DateTime]$lastStep.completedOn
                        $envDuration = ($endTime - $startTime).TotalMinutes
                        $environmentStats[$env.name].DeploymentDurations += $envDuration
                    }
                }
            }
        }
    }
    
    # Calculate average release duration
    if ($releaseDurations.Count -gt 0) {
        $performanceAnalysis.AverageDuration = ($releaseDurations | Measure-Object -Average).Average
    }
    
    # Calculate success rate
    if ($performanceAnalysis.TotalReleases -gt 0) {
        $performanceAnalysis.RecentSuccessRate = [math]::Round(
            ($performanceAnalysis.SuccessfulReleases / $performanceAnalysis.TotalReleases) * 100, 2
        )
    }
    
    # Process environment stats
    foreach ($envName in $environmentStats.Keys) {
        $envStat = $environmentStats[$envName]
        
        # Calculate average duration
        if ($envStat.DeploymentDurations.Count -gt 0) {
            $envStat.AverageDuration = ($envStat.DeploymentDurations | Measure-Object -Average).Average
        }
        
        # Remove raw durations array to keep output cleaner
        $envStat.Remove("DeploymentDurations")
        
        # Add success rate
        if ($envStat.TotalDeployments -gt 0) {
            $envStat.SuccessRate = [math]::Round(
                ($envStat.SuccessfulDeployments / $envStat.TotalDeployments) * 100, 2
            )
        }
        else {
            $envStat.SuccessRate = 0
        }
    }
    
    $performanceAnalysis.EnvironmentStats = $environmentStats
    
    return $performanceAnalysis
}

# Function to analyze a single release definition and its recent releases
function Analyze-ReleaseDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxReleases = 20
    )
    
    Write-Host "Analyzing release definition: $($Definition.name) (ID: $($Definition.id))" -ForegroundColor Green
    
    # Get detailed definition
    $definitionDetails = Get-ReleaseDefinitionDetails -DefinitionId $Definition.id
    
    if ($null -eq $definitionDetails) {
        Write-Warning "Could not get details for release definition $($Definition.name)"
        return
    }
    
    # Get recent releases
    $recentReleases = Get-RecentReleases -DefinitionId $Definition.id -MaxResults $MaxReleases
    
    $releaseAnalysis = @{
        DefinitionId = $Definition.id
        DefinitionName = $Definition.name
        CreatedBy = $Definition.createdBy.displayName
        CreatedDate = $Definition.createdOn
        ModifiedDate = $Definition.modifiedOn
        Url = $Definition._links.web.href
        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        RecentReleases = if ($recentReleases) { 
            $recentReleases | Select-Object id, name, status, createdOn, modifiedOn, releaseDefinitionReference
        } else { 
            @() 
        }
        EnvironmentCount = ($definitionDetails.environments | Measure-Object).Count
        ArtifactCount = ($definitionDetails.artifacts | Measure-Object).Count
        SecurityAnalysis = Analyze-ReleaseSecurity -Definition $definitionDetails
        PerformanceAnalysis = if ($recentReleases.Count -gt 0) { 
            Analyze-ReleasePerformance -Releases $recentReleases 
        } else { 
            $null 
        }
    }
    
    return $releaseAnalysis
}

# Main function to analyze all release definitions or a specific one
function Start-ReleaseAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DefinitionName,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxReleases = 20
    )
    
    Write-Host "Starting release analysis..." -ForegroundColor Cyan
    
    # Test connection first
    if (-not (Test-AzureDevOpsConnection)) {
        Write-Error "Failed to connect to Azure DevOps. Please check your configuration."
        return
    }
    
    # Get all release definitions or a specific one
    $definitions = Get-ReleaseDefinitions -DefinitionName $DefinitionName
    
    if ($null -eq $definitions -or $definitions.Count -eq 0) {
        Write-Error "No release definitions found to analyze."
        return
    }
    
    # Clear previous results
    $script:releaseAnalysisResults = @()
    
    # Analyze each release definition
    foreach ($definition in $definitions) {
        $definitionResults = Analyze-ReleaseDefinition -Definition $definition -MaxReleases $MaxReleases
        
        if ($null -ne $definitionResults) {
            $script:releaseAnalysisResults += $definitionResults
        }
    }
    
    Write-Host "Release analysis completed. Analyzed $($definitions.Count) release definitions." -ForegroundColor Green
    
    # Return results
    return $script:releaseAnalysisResults
}

# Function to get the current analysis results
function Get-ReleaseAnalysisResults {
    return $script:releaseAnalysisResults
}

# Export functions
#Export-ModuleMember -Function Start-ReleaseAnalysis, Get-ReleaseAnalysisResults
