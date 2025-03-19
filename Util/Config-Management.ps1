# Dizzy - Azure DevOps Analyzer
# Configuration management utilities

# Define global configuration variables
$script:configFolder = Join-Path -Path $env:USERPROFILE -ChildPath ".dizzy"
$script:configFile = Join-Path -Path $script:configFolder -ChildPath "config.json"
$script:defaultOutputFolder = Join-Path -Path $env:USERPROFILE -ChildPath "Dizzy-Results"
$script:patEnvironmentVariable = "DIZZY_PAT"

# Function to initialize configuration
function Initialize-DizzyConfig {
    [CmdletBinding()]
    param()
    
    # Create config folder if it doesn't exist
    if (-not (Test-Path -Path $script:configFolder)) {
        try {
            New-Item -Path $script:configFolder -ItemType Directory -Force | Out-Null
            Write-Verbose "Created configuration folder: $($script:configFolder)"
        }
        catch {
            Write-Error "Failed to create configuration folder: $_"
            return $false
        }
    }
    
    # Create default config file if it doesn't exist
    if (-not (Test-Path -Path $script:configFile)) {
        $defaultConfig = @{
            OrganizationUrl = ""
            Project = ""
            Repository = ""
            PipelineId = ""
            OutputFolder = $script:defaultOutputFolder
            LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        try {
            $defaultConfig | ConvertTo-Json | Out-File -FilePath $script:configFile -Force
            Write-Verbose "Created default configuration file: $($script:configFile)"
        }
        catch {
            Write-Error "Failed to create configuration file: $_"
            return $false
        }
    }
    
    return $true
}

# Function to get current configuration
function Get-DizzyConfig {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Path -Path $script:configFile)) {
        if (-not (Initialize-DizzyConfig)) {
            Write-Error "Failed to initialize configuration."
            return $null
        }
    }
    
    try {
        $config = Get-Content -Path $script:configFile -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Error "Failed to read configuration file: $_"
        return $null
    }
}

# Function to update configuration
function Set-DizzyConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OrganizationUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$Project,
        
        [Parameter(Mandatory = $false)]
        [string]$Repository = "",
        
        [Parameter(Mandatory = $false)]
        [string]$PipelineId = "",
        
        [Parameter(Mandatory = $false)]
        [string]$OutputFolder = $script:defaultOutputFolder
    )
    
    # Ensure configuration is initialized
    if (-not (Test-Path -Path $script:configFile)) {
        if (-not (Initialize-DizzyConfig)) {
            Write-Error "Failed to initialize configuration."
            return $false
        }
    }
    
    try {
        $config = @{
            OrganizationUrl = $OrganizationUrl
            Project = $Project
            Repository = $Repository
            PipelineId = $PipelineId
            OutputFolder = $OutputFolder
            LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        $config | ConvertTo-Json | Out-File -FilePath $script:configFile -Force
        Write-Verbose "Updated configuration file: $($script:configFile)"
        return $true
    }
    catch {
        Write-Error "Failed to update configuration: $_"
        return $false
    }
}

# Function to store PAT in environment variable
function Set-DizzyPAT {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PAT
    )
    
    try {
        # Store PAT in environment variable at User scope
        [Environment]::SetEnvironmentVariable($script:patEnvironmentVariable, $PAT, "User")
        Write-Verbose "Stored PAT in environment variable"
        return $true
    }
    catch {
        Write-Error "Failed to store PAT: $_"
        return $false
    }
}

# Function to retrieve PAT from environment variable
function Get-DizzyPAT {
    [CmdletBinding()]
    param()
    
    try {
        $pat = [Environment]::GetEnvironmentVariable($script:patEnvironmentVariable, "User")
        
        if ([string]::IsNullOrWhiteSpace($pat)) {
            Write-Error "PAT not found. Please set PAT using Set-DizzyPAT function."
            return $null
        }
        
        return $pat
    }
    catch {
        Write-Error "Failed to retrieve PAT: $_"
        return $null
    }
}

# Function to test Azure DevOps connection
function Test-DizzyConnection {
    [CmdletBinding()]
    param()
    
    $config = Get-DizzyConfig
    $pat = Get-DizzyPAT
    
    if ($null -eq $config -or [string]::IsNullOrWhiteSpace($config.OrganizationUrl) -or [string]::IsNullOrWhiteSpace($config.Project)) {
        Write-Error "Invalid configuration. Please set OrganizationUrl and Project."
        return $false
    }
    
    if ($null -eq $pat) {
        Write-Error "PAT not found. Please set PAT using Set-DizzyPAT function."
        return $false
    }
    
    try {
        # Create auth header
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
        }
        
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

# Function to create output folder
function New-DizzyOutputFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputFolder = ""
    )
    
    if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
        $config = Get-DizzyConfig
        
        if ($null -ne $config -and -not [string]::IsNullOrWhiteSpace($config.OutputFolder)) {
            $OutputFolder = $config.OutputFolder
        }
        else {
            $OutputFolder = $script:defaultOutputFolder
        }
    }
    
    try {
        if (-not (Test-Path -Path $OutputFolder)) {
            New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
            Write-Verbose "Created output folder: $OutputFolder"
        }
        
        # Add timestamp subfolder to keep results organized
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $timestampFolder = Join-Path -Path $OutputFolder -ChildPath $timestamp
        
        New-Item -Path $timestampFolder -ItemType Directory -Force | Out-Null
        Write-Verbose "Created timestamp folder: $timestampFolder"
        
        return $timestampFolder
    }
    catch {
        Write-Error "Failed to create output folder: $_"
        return $null
    }
}

# Function to validate PAT permissions
function Test-DizzyPatPermissions {
    [CmdletBinding()]
    param()
    
    $config = Get-DizzyConfig
    $pat = Get-DizzyPAT
    
    if ($null -eq $config -or [string]::IsNullOrWhiteSpace($config.OrganizationUrl) -or [string]::IsNullOrWhiteSpace($config.Project)) {
        Write-Error "Invalid configuration. Please set OrganizationUrl and Project."
        return @{Result = $false; Permissions = @{}}
    }
    
    if ($null -eq $pat) {
        Write-Error "PAT not found. Please set PAT using Set-DizzyPAT function."
        return @{Result = $false; Permissions = @{}}
    }
    
    try {
        # Create auth header
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
        }
        
        $permissions = @{
            Code = $false
            Build = $false
            Release = $false
            Pipeline = $false
        }
        
        # Test code access
        try {
            $codeApiUrl = "$($config.OrganizationUrl)/$($config.Project)/_apis/git/repositories?api-version=6.0"
            $codeResponse = Invoke-RestMethod -Uri $codeApiUrl -Headers $headers -Method Get -ErrorAction Stop
            $permissions.Code = $true
        }
        catch {
            Write-Verbose "PAT does not have code repository access: $_"
        }
        
        # Test build access
        try {
            $buildApiUrl = "$($config.OrganizationUrl)/$($config.Project)/_apis/build/definitions?api-version=6.0"
            $buildResponse = Invoke-RestMethod -Uri $buildApiUrl -Headers $headers -Method Get -ErrorAction Stop
            $permissions.Build = $true
        }
        catch {
            Write-Verbose "PAT does not have build definition access: $_"
        }
        
        # Test release access
        try {
            $releaseApiUrl = "$($config.OrganizationUrl)/$($config.Project)/_apis/release/definitions?api-version=6.0"
            $releaseResponse = Invoke-RestMethod -Uri $releaseApiUrl -Headers $headers -Method Get -ErrorAction Stop
            $permissions.Release = $true
        }
        catch {
            Write-Verbose "PAT does not have release definition access: $_"
        }
        
        # Test pipeline access
        try {
            $pipelineApiUrl = "$($config.OrganizationUrl)/$($config.Project)/_apis/pipelines?api-version=6.0"
            $pipelineResponse = Invoke-RestMethod -Uri $pipelineApiUrl -Headers $headers -Method Get -ErrorAction Stop
            $permissions.Pipeline = $true
        }
        catch {
            Write-Verbose "PAT does not have pipeline access: $_"
        }
        
        $allPermissions = $permissions.Code -and $permissions.Build -and $permissions.Release -and $permissions.Pipeline
        
        return @{
            Result = $allPermissions
            Permissions = $permissions
        }
    }
    catch {
        Write-Error "Failed to test PAT permissions: $_"
        return @{Result = $false; Permissions = @{}}
    }
}

# Export functions
Export-ModuleMember -Function Initialize-DizzyConfig, Get-DizzyConfig, Set-DizzyConfig, 
                              Set-DizzyPAT, Get-DizzyPAT, Test-DizzyConnection,
                              New-DizzyOutputFolder, Test-DizzyPatPermissions