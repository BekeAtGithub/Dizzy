# Dizzy - Azure DevOps Analyzer
# Core authentication module for Azure DevOps API access

# Function to load the saved configuration

# Near the beginning of ADO-Authentication.ps1, modify the path resolution:

# Get the script's directory
$scriptPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}

# Define paths to utility scripts
$utilPath = Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "Util"
$configModulePath = Join-Path -Path $utilPath -ChildPath "Config-Management.ps1"

# Source the Config-Management script
if (Test-Path $configModulePath) {
    . $configModulePath
    Write-Host "Successfully loaded Config-Management.ps1" -ForegroundColor Green
}
else {
    Write-Error "Critical module not found: Config-Management.ps1 at $configModulePath"
    exit
}
function Get-DizzyConfig {
    [CmdletBinding()]
    param()
    
    $configFolder = Join-Path -Path $env:USERPROFILE -ChildPath ".dizzy"
    $configFile = Join-Path -Path $configFolder -ChildPath "config.json"
    
    if (-not (Test-Path $configFile)) {
        Write-Error "Configuration file not found at $configFile. Please run Setup first."
        return $null
    }
    
    try {
        $config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Error "Failed to load configuration: $_"
        return $null
    }
}

# Function to get the stored PAT
function Get-DizzyPAT {
    [CmdletBinding()]
    param()
    
    $pat = [Environment]::GetEnvironmentVariable("DIZZY_PAT", "User")
    
    if ([string]::IsNullOrWhiteSpace($pat)) {
        Write-Error "Personal Access Token not found. Please run Setup first."
        return $null
    }
    
    return $pat
}

# Function to create authentication headers for Azure DevOps API
function Get-AzureDevOpsAuthHeader {
    [CmdletBinding()]
    param()
    
    $pat = Get-DizzyPAT
    
    if ($null -eq $pat) {
        return $null
    }
    
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
    $headers = @{
        Authorization = "Basic $base64AuthInfo"
        "Content-Type" = "application/json"
    }
    
    return $headers
}

# Function to test connection to Azure DevOps
# In ADO-Authentication.ps1, modify the Test-AzureDevOpsConnection function:

function Test-AzureDevOpsConnection {
    [CmdletBinding()]
    param()
    
    $config = Get-DizzyConfig
    $headers = Get-AzureDevOpsAuthHeader
    
    if ($null -eq $config -or $null -eq $headers) {
        return $false
    }
    
    try {
        # Test connection by getting project info
        $endpoints = Get-AzureDevOpsApiEndpoints
        $projectApiUrl = $endpoints.ProjectApi.Info
        
        Write-Host "Testing connection to: $projectApiUrl" -ForegroundColor Cyan
        
        $response = Invoke-RestMethod -Uri $projectApiUrl -Headers $headers -Method Get -ErrorAction Stop
        
        Write-Verbose "Successfully connected to Azure DevOps project: $($config.Project)"
        return $true
    }
    catch {
        Write-Error "Failed to connect to Azure DevOps: $_"
        return $false
    }
}

# Function to get Azure DevOps API endpoints
# File: ADO-Authentication.ps1
# Around line 120-170, modify this section:

function Get-AzureDevOpsApiEndpoints {
    [CmdletBinding()]
    param()
    
    $config = Get-DizzyConfig
    
    if ($null -eq $config) {
        Write-Error "Failed to get configuration."
        return $null
    }
    
    $organization = $config.OrganizationUrl
    $project = $config.Project
    
    # Check organization URL format
    if ($organization -match "dev\.azure\.com") {
        # New format: https://dev.azure.com/orgname
        $baseUrl = "$organization/$project"
    } else {
        # Old format: https://orgname.visualstudio.com
        $baseUrl = "$organization/$project"
    }
    
    return @{
        Organization = $organization
        Project = $project
        # Git repositories endpoints
        Git = @{
            Repositories = "$baseUrl/_apis/git/repositories?api-version=6.0"
            Repository = "$baseUrl/_apis/git/repositories/{repositoryId}?api-version=6.0"
            Items = "$baseUrl/_apis/git/repositories/{repositoryId}/items?recursionLevel=Full&api-version=6.0"
            Commits = "$baseUrl/_apis/git/repositories/{repositoryId}/commits?api-version=6.0"
            PullRequests = "$baseUrl/_apis/git/repositories/{repositoryId}/pullrequests?api-version=6.0"
        }
        # Build endpoints
        Build = @{
            Definitions = "$baseUrl/_apis/build/definitions?api-version=6.0"
            Definition = "$baseUrl/_apis/build/definitions/{definitionId}?api-version=6.0"
            Builds = "$baseUrl/_apis/build/builds?api-version=6.0"
            Build = "$baseUrl/_apis/build/builds/{buildId}?api-version=6.0"
            Artifacts = "$baseUrl/_apis/build/builds/{buildId}/artifacts?api-version=6.0"
            Timeline = "$baseUrl/_apis/build/builds/{buildId}/timeline?api-version=6.0"
            Logs = "$baseUrl/_apis/build/builds/{buildId}/logs?api-version=6.0"
        }
        # Release endpoints
        Release = @{
            Definitions = "$baseUrl/_apis/release/definitions?api-version=6.0"
            Definition = "$baseUrl/_apis/release/definitions/{definitionId}?api-version=6.0"
            Releases = "$baseUrl/_apis/release/releases?api-version=6.0"
            Release = "$baseUrl/_apis/release/releases/{releaseId}?api-version=6.0"
        }
        # Pipeline endpoints
        Pipeline = @{
            Pipelines = "$baseUrl/_apis/pipelines?api-version=6.0"
            Pipeline = "$baseUrl/_apis/pipelines/{pipelineId}?api-version=6.0"
            Runs = "$baseUrl/_apis/pipelines/{pipelineId}/runs?api-version=6.0"
            Run = "$baseUrl/_apis/pipelines/{pipelineId}/runs/{runId}?api-version=6.0"
        }
        # Security
        Security = @{
            Permissions = "$organization/_apis/security/permissions?api-version=6.0"
            AccessControlLists = "$organization/_apis/accesscontrollists?api-version=6.0"
        }
        # Project - Renamed to avoid conflict with the variable
        ProjectApi = @{
            Info = "$baseUrl/_apis/projects?api-version=6.0"
            Teams = "$baseUrl/_apis/teams?api-version=6.0"
            Properties = "$baseUrl/_apis/projects/{projectId}/properties?api-version=6.0"
            Services = "$baseUrl/_apis/servicehooks/services?api-version=6.0"
        }
    }
}

# Function to make API call to Azure DevOps
function Invoke-AzureDevOpsApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter(Mandatory = $false)]
        [string]$Method = "GET",
        
        [Parameter(Mandatory = $false)]
        [object]$Body = $null,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeResponseHeaders
    )
    
    $headers = Get-AzureDevOpsAuthHeader
    
    if ($null -eq $headers) {
        return $null
    }
    
    try {
        $params = @{
            Uri = $Uri
            Headers = $headers
            Method = $Method
            ErrorAction = "Stop"
        }
        
        if ($null -ne $Body) {
            if ($Body -is [string]) {
                $params.Body = $Body
            }
            else {
                $params.Body = $Body | ConvertTo-Json -Depth 10
            }
        }
        
        if ($IncludeResponseHeaders) {
            $response = Invoke-WebRequest @params
            $result = $response.Content | ConvertFrom-Json
            return @{
                Content = $result
                Headers = $response.Headers
            }
        }
        else {
            $result = Invoke-RestMethod @params
            return $result
        }
    }
    catch {
        Write-Error "API call to $Uri failed: $_"
        return $null
    }
}

# Function to handle pagination for Azure DevOps API
function Get-AzureDevOpsApiPaginated {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 1000
    )
    
    $results = @()
    $currentCount = 0
    $continuationToken = $null
    
    do {
        $currentUri = $Uri
        
        # Add continuation token if we have it
        if ($null -ne $continuationToken) {
            $currentUri += if ($currentUri -like "*?*") { "&" } else { "?" }
            $currentUri += "continuationToken=$continuationToken"
        }
        
        # Add top parameter to limit results per page
        $currentUri += if ($currentUri -like "*?*") { "&" } else { "?" }
        $currentUri += "top=100"
        
        $response = Invoke-AzureDevOpsApi -Uri $currentUri -IncludeResponseHeaders
        
        if ($null -eq $response) {
            break
        }
        
        # Add results to our collection
        if ($response.Content.value) {
            $results += $response.Content.value
            $currentCount += $response.Content.value.Count
        }
        elseif ($response.Content.count -gt 0) {
            $results += $response.Content
            $currentCount += $response.Content.Count
        }
        
        # Check if we need to stop based on max results
        if ($currentCount -ge $MaxResults) {
            break
        }
        
        # Get continuation token for next page if it exists
        if ($response.Headers.ContainsKey("x-ms-continuationtoken")) {
            $continuationToken = $response.Headers["x-ms-continuationtoken"]
        }
        else {
            $continuationToken = $null
        }
    } while ($null -ne $continuationToken)
    
    return $results
}

# Export functions
#Export-ModuleMember -Function Get-DizzyConfig, Get-DizzyPAT, Get-AzureDevOpsAuthHeader, 
#                             Test-AzureDevOpsConnection, Get-AzureDevOpsApiEndpoints,
#                             Invoke-AzureDevOpsApi, Get-AzureDevOpsApiPaginated
