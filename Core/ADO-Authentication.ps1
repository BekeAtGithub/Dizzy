# Dizzy - Azure DevOps Analyzer
# Core authentication module for Azure DevOps API access

# Function to load the saved configuration
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
        $projectApiUrl = "$($config.OrganizationUrl)/$($config.Project)/_apis/projects?api-version=6.0"
        
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
function Get-AzureDevOpsApiEndpoints {
    [CmdletBinding()]
    param()
    
    $config = Get-DizzyConfig
    
    if ($null -eq $config) {
        return $null
    }
    
    $organization = $config.OrganizationUrl
    $project = $config.Project
    
    return @{
        Organization = $organization
        Project = $project
        # Git repositories endpoints
        Git = @{
            Repositories = "$organization/$project/_apis/git/repositories?api-version=6.0"
            Repository = "$organization/$project/_apis/git/repositories/{repositoryId}?api-version=6.0"
            Items = "$organization/$project/_apis/git/repositories/{repositoryId}/items?recursionLevel=Full&api-version=6.0"
            Commits = "$organization/$project/_apis/git/repositories/{repositoryId}/commits?api-version=6.0"
            PullRequests = "$organization/$project/_apis/git/repositories/{repositoryId}/pullrequests?api-version=6.0"
        }
        # Build endpoints
        Build = @{
            Definitions = "$organization/$project/_apis/build/definitions?api-version=6.0"
            Definition = "$organization/$project/_apis/build/definitions/{definitionId}?api-version=6.0"
            Builds = "$organization/$project/_apis/build/builds?api-version=6.0"
            Build = "$organization/$project/_apis/build/builds/{buildId}?api-version=6.0"
            Artifacts = "$organization/$project/_apis/build/builds/{buildId}/artifacts?api-version=6.0"
            Timeline = "$organization/$project/_apis/build/builds/{buildId}/timeline?api-version=6.0"
            Logs = "$organization/$project/_apis/build/builds/{buildId}/logs?api-version=6.0"
        }
        # Release endpoints
        Release = @{
            Definitions = "$organization/$project/_apis/release/definitions?api-version=6.0"
            Definition = "$organization/$project/_apis/release/definitions/{definitionId}?api-version=6.0"
            Releases = "$organization/$project/_apis/release/releases?api-version=6.0"
            Release = "$organization/$project/_apis/release/releases/{releaseId}?api-version=6.0"
        }
        # Pipeline endpoints
        Pipeline = @{
            Pipelines = "$organization/$project/_apis/pipelines?api-version=6.0"
            Pipeline = "$organization/$project/_apis/pipelines/{pipelineId}?api-version=6.0"
            Runs = "$organization/$project/_apis/pipelines/{pipelineId}/runs?api-version=6.0"
            Run = "$organization/$project/_apis/pipelines/{pipelineId}/runs/{runId}?api-version=6.0"
        }
        # Security
        Security = @{
            Permissions = "$organization/_apis/security/permissions?api-version=6.0"
            AccessControlLists = "$organization/_apis/accesscontrollists?api-version=6.0"
        }
        # Project
        Project = @{
            Info = "$organization/$project/_apis/projects?api-version=6.0"
            Teams = "$organization/$project/_apis/teams?api-version=6.0"
            Properties = "$organization/$project/_apis/projects/{projectId}/properties?api-version=6.0"
            Services = "$organization/$project/_apis/servicehooks/services?api-version=6.0"
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
Export-ModuleMember -Function Get-DizzyConfig, Get-DizzyPAT, Get-AzureDevOpsAuthHeader, 
                             Test-AzureDevOpsConnection, Get-AzureDevOpsApiEndpoints,
                             Invoke-AzureDevOpsApi, Get-AzureDevOpsApiPaginated