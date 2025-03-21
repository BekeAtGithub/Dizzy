# Dizzy - Azure DevOps Analyzer
# Repository scanner module for detecting secrets, keys, and security issues

# Import authentication module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$authModulePath = Join-Path -Path $scriptPath -ChildPath "ADO-Authentication.ps1"
. $authModulePath

# Create a global variable to store scan results
$script:repositoryScanResults = @()

# Patterns for detecting secrets in code
$secretPatterns = @{
    # API Keys & Tokens
    "AWS Access Key" = "(?<![A-Za-z0-9])AKIA[0-9A-Z]{16}(?![A-Za-z0-9])"
    "AWS Secret Key" = "(?<![A-Za-z0-9])[0-9a-zA-Z/+]{40}(?![A-Za-z0-9])"
    "Azure Storage Account Key" = "(?<![A-Za-z0-9])[A-Za-z0-9+/=]{88}(?![A-Za-z0-9])"
    "Azure Connection String" = "DefaultEndpointsProtocol=https?;AccountName=[^;]+;AccountKey=[^;]+"
    "GitHub Token" = "(?i)(?<![A-Za-z0-9])github[_\-\s]*(pat|token|key)[_\-\s]*[`'`"]?[0-9a-zA-Z]{35,40}[`'`"]?"
    "Generic API Key" = "(?i)(api[_\-\s]*(key|token)|access[_\-\s]*(key|token))[_\-\s]*[`'`"]?[0-9a-zA-Z]{16,64}[`'`"]?"
    
    # Credentials
    "Password in Assignment" = "(?i)(password|passwd|pwd)\s*=\s*[`'`"][^`'`"]{4,}[`'`"]"
    "Connection String with Password" = "(?i)(?:connection[_\-\s]*string|conn[_\-\s]*str)[_\-\s]*[`'`"]?.*password=[^;`']+"
    "Connection String with User ID" = "(?i)(?:connection[_\-\s]*string|conn[_\-\s]*str)[_\-\s]*[`'`"]?.*user id=[^;`']+"
    
    # Private Keys
    "RSA Private Key" = "-----BEGIN RSA PRIVATE KEY-----"
    "SSH Private Key" = "-----BEGIN (OPENSSH|SSH2) PRIVATE KEY-----" 
    "PGP Private Key" = "-----BEGIN PGP PRIVATE KEY BLOCK-----"
    
    # Other Sensitive Data
    "Certificate" = "-----BEGIN CERTIFICATE-----"
    "PFX Data" = "-----BEGIN PKCS12-----"
}

# File extensions to check (add more as needed)
$fileExtensionsToCheck = @(
    ".cs", ".java", ".py", ".js", ".ts", ".php", ".rb", 
    ".xml", ".json", ".yaml", ".yml", ".config", ".tf", 
    ".properties", ".ini", ".env", ".ps1", ".psm1", ".psd1",
    ".sh", ".bash", ".txt", ".md"
)

# File names to specifically check
$fileNamesToCheck = @(
    "appsettings.json", "web.config", "app.config", ".env", "settings.json",
    "terraform.tfvars", "variables.tf", "config.xml", "secrets.json", "credentials.json",
    "azure-pipelines.yml", "Jenkinsfile", "docker-compose.yml", "Dockerfile",
    ".npmrc", ".gradle", "pom.xml", "package.json", "nuget.config"
)

# Function to get all repositories or a specific repository
function Get-AzureDevOpsRepositories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryName
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $reposUrl = $endpoints.Git.Repositories
    $repos = Invoke-AzureDevOpsApi -Uri $reposUrl
    
    if ($null -eq $repos -or $null -eq $repos.value) {
        Write-Error "Failed to get repositories."
        return $null
    }
    
    # Filter by name if specified
    if (-not [string]::IsNullOrWhiteSpace($RepositoryName)) {
        $repos.value = $repos.value | Where-Object { $_.name -eq $RepositoryName }
    }
    
    Write-Host "Found $($repos.value.Count) repositories" -ForegroundColor Cyan
    return $repos.value
}

# Function to get repository items (files)
function Get-RepositoryItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryId
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $itemsUrl = $endpoints.Git.Items -replace "{repositoryId}", $RepositoryId
    $items = Invoke-AzureDevOpsApi -Uri $itemsUrl
    
    if ($null -eq $items -or $null -eq $items.value) {
        Write-Error "Failed to get repository items."
        return $null
    }
    
    # Get only files (not directories)
    $files = $items.value | Where-Object { $_.isFolder -eq $false }
    
    Write-Host "Found $($files.Count) files in repository $RepositoryId" -ForegroundColor Cyan
    return $files
}

# Function to get file content
function Get-FileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryId,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $endpoints = Get-AzureDevOpsApiEndpoints
    
    if ($null -eq $endpoints) {
        Write-Error "Failed to get API endpoints."
        return $null
    }
    
    $itemsUrl = ($endpoints.Git.Items -replace "{repositoryId}", $RepositoryId) + "&path=$FilePath&includeContent=true"
    $file = Invoke-AzureDevOpsApi -Uri $itemsUrl
    
    if ($null -eq $file) {
        Write-Error "Failed to get file content for $FilePath."
        return $null
    }
    
    return $file.content
}

# Function to scan file content for secrets
function Find-Secrets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $findings = @()
    
    foreach ($pattern in $secretPatterns.GetEnumerator()) {
        $matches = [regex]::Matches($Content, $pattern.Value)
        
        foreach ($match in $matches) {
            # Extract some context around the match to help with analysis
            $startIndex = [Math]::Max(0, $match.Index - 20)
            $length = [Math]::Min(40 + $match.Length, $Content.Length - $startIndex)
            $context = $Content.Substring($startIndex, $length)
            
            # Replace the actual secret with asterisks in the context
            $maskedContext = $context -replace $match.Value, "**********"
            
            $findings += [PSCustomObject]@{
                FilePath = $FilePath
                LineNumber = ($Content.Substring(0, $match.Index).Split("`n")).Count
                PatternName = $pattern.Key
                Context = $maskedContext
                Severity = "High"
            }
        }
    }
    
    return $findings
}

# Function to determine if a file should be scanned based on extension or name
function Should-ScanFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $fileName = Split-Path -Leaf $FilePath
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    # Check if the file is in the specific list to check
    if ($fileNamesToCheck -contains $fileName) {
        return $true
    }
    
    # Check if the file extension is in our list
    if ($fileExtensionsToCheck -contains $extension) {
        return $true
    }
    
    return $false
}

# Function to scan a single repository
function Scan-Repository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Repository,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxFilesToScan = 1000,
        
        [Parameter(Mandatory = $false)]
        [string]$ScanDepth = "Medium"
    )
    
    Write-Host "Scanning repository: $($Repository.name)" -ForegroundColor Green
    
    $repoFiles = Get-RepositoryItems -RepositoryId $Repository.id
    
    if ($null -eq $repoFiles) {
        Write-Warning "No files found in repository $($Repository.name)"
        return
    }
    
    $filesToScan = @()
    
    # Filter files based on scan depth
    switch ($ScanDepth) {
        "Light" {
            # Only scan specific high-risk files
            $filesToScan = $repoFiles | Where-Object { 
                $fileName = Split-Path -Leaf $_.path
                $fileNamesToCheck -contains $fileName
            }
        }
        "Medium" {
            # Scan high-risk files and files with specific extensions
            $filesToScan = $repoFiles | Where-Object { Should-ScanFile -FilePath $_.path }
        }
        "Deep" {
            # Scan all text-based files
            $filesToScan = $repoFiles | Where-Object { 
                $extension = [System.IO.Path]::GetExtension($_.path).ToLower()
                $extension -notin @(".exe", ".dll", ".pdb", ".jpg", ".png", ".gif", ".ico", ".pdf", ".zip", ".rar", ".7z")
            }
        }
        default {
            # Default to Medium
            $filesToScan = $repoFiles | Where-Object { Should-ScanFile -FilePath $_.path }
        }
    }
    
    # Limit the number of files to scan
    if ($filesToScan.Count -gt $MaxFilesToScan) {
        Write-Warning "Limiting scan to $MaxFilesToScan files out of $($filesToScan.Count) potential files in $($Repository.name)"
        $filesToScan = $filesToScan | Select-Object -First $MaxFilesToScan
    }
    
    Write-Host "Scanning $($filesToScan.Count) files in repository $($Repository.name)" -ForegroundColor Cyan
    
    $repositoryFindings = @{
        RepositoryName = $Repository.name
        RepositoryId = $Repository.id
        DefaultBranch = $Repository.defaultBranch
        Url = $Repository.webUrl
        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ScannedFilesCount = $filesToScan.Count
        TotalFilesCount = $repoFiles.Count
        Findings = @()
    }
    
    $fileCounter = 0
    foreach ($file in $filesToScan) {
        $fileCounter++
        
        # Show progress
        Write-Progress -Activity "Scanning Repository: $($Repository.name)" `
                       -Status "Scanning file $fileCounter of $($filesToScan.Count): $($file.path)" `
                       -PercentComplete (($fileCounter / $filesToScan.Count) * 100)
        
        $content = Get-FileContent -RepositoryId $Repository.id -FilePath $file.path
        
        if ($null -eq $content) {
            Write-Verbose "Skipping file $($file.path) - could not retrieve content"
            continue
        }
        
        $fileFindings = Find-Secrets -Content $content -FilePath $file.path
        
        if ($fileFindings.Count -gt 0) {
            Write-Host "Found $($fileFindings.Count) secrets in $($file.path)" -ForegroundColor Yellow
            $repositoryFindings.Findings += $fileFindings
        }
    }
    
    Write-Progress -Activity "Scanning Repository: $($Repository.name)" -Completed
    
    if ($repositoryFindings.Findings.Count -gt 0) {
        Write-Host "Found a total of $($repositoryFindings.Findings.Count) secrets in repository $($Repository.name)" -ForegroundColor Red
    }
    else {
        Write-Host "No secrets found in repository $($Repository.name)" -ForegroundColor Green
    }
    
    return $repositoryFindings
}

# Add this to ADO-RepositoryScanner.ps1 to ensure repositories are collected even if no scan is performed

# Modified function to get repositories without scanning
# Add this function to ADO-RepositoryScanner.ps1
# Make sure it fully replaces any existing Get-RepositoriesOnly function

function Get-RepositoriesOnly {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryName = ""
    )
    
    Write-Host "Retrieving repository list..." -ForegroundColor Cyan
    
    # Get config
    $config = Get-DizzyConfig
    if ($null -eq $config) {
        Write-Error "Configuration not found. Please run setup first."
        return @()
    }
    
    # Get auth headers
    $headers = Get-AzureDevOpsAuthHeader
    if ($null -eq $headers) {
        Write-Error "Failed to get authentication headers. Check your PAT."
        return @()
    }
    
    # Get repositories directly using the URL format we know works
    $reposUrl = "$($config.OrganizationUrl)/$($config.Project)/_apis/git/repositories?api-version=6.0"
    
    try {
        Write-Host "Calling API: $reposUrl" -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $reposUrl -Headers $headers -Method Get -ErrorAction Stop
        
        Write-Host "API returned $($response.count) repositories" -ForegroundColor Green
        
        # Filter by name if specified
        $repositories = $response.value
        if (-not [string]::IsNullOrWhiteSpace($RepositoryName)) {
            $repositories = $repositories | Where-Object { $_.name -eq $RepositoryName }
            Write-Host "Filtered to $($repositories.Count) repositories with name: $RepositoryName" -ForegroundColor Cyan
        }
        
        # Create result objects
        $repoResults = @()
        foreach ($repo in $repositories) {
            Write-Host "Processing repository: $($repo.name)" -ForegroundColor Cyan
            
            $repoInfo = [PSCustomObject]@{
                RepositoryName = $repo.name
                RepositoryId = $repo.id
                DefaultBranch = $repo.defaultBranch
                Url = $repo.webUrl
                ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                ScannedFilesCount = 0
                TotalFilesCount = 0
                Findings = @()
            }
            
            $repoResults += $repoInfo
        }
        
        Write-Host "Returning $($repoResults.Count) repository objects" -ForegroundColor Green
        
        # Ensure we're returning an array
        return @($repoResults)
    }
    catch {
        Write-Error "Error retrieving repositories: $_"
        return @()
    }
}

# Now modify the Start-RepositoryScan function to use the new Get-RepositoriesOnly
# Make sure it correctly handles the SkipScan parameter

function Start-RepositoryScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryName = "",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Light", "Medium", "Deep")]
        [string]$ScanDepth = "Medium",
        
        [Parameter(Mandatory = $false)]
        [int]$MaxFilesPerRepo = 1000,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipScan
    )
    
    Write-Host "Starting repository scanner..." -ForegroundColor Cyan
    
    # Test connection first
    if (-not (Test-AzureDevOpsConnection)) {
        Write-Error "Failed to connect to Azure DevOps. Please check your configuration."
        return @()
    }
    
    # Get repository list without scanning if requested
    if ($SkipScan) {
        Write-Host "Skipping scan, just retrieving repository information" -ForegroundColor Yellow
        $repos = Get-RepositoriesOnly -RepositoryName $RepositoryName
        Write-Host "Retrieved $($repos.Count) repositories without scanning" -ForegroundColor Green
        return $repos
    }
    
    # The rest of your original Start-RepositoryScan function...
    # [Keep your existing scanning code here]
    
    # Clear previous results
    $script:repositoryScanResults = @()
    
    # Get all repositories or a specific one
    $repositories = Get-AzureDevOpsRepositories -RepositoryName $RepositoryName
    
    if ($null -eq $repositories -or $repositories.Count -eq 0) {
        Write-Error "No repositories found to scan."
        return @()
    }
    
    # [The rest of your repository scanning code]
    
    # Return results
    Write-Host "Returning $($script:repositoryScanResults.Count) repository scan results" -ForegroundColor Green
    return @($script:repositoryScanResults)
}

# Now modify the Start-RepositoryScan function to ensure it returns repository information even if scanning is skipped
# Locate the function Start-RepositoryScan and modify it to include this at the beginning:

function Start-RepositoryScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryName,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Light", "Medium", "Deep")]
        [string]$ScanDepth = "Medium",
        
        [Parameter(Mandatory = $false)]
        [int]$MaxFilesPerRepo = 1000,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipScan
    )
    
    Write-Host "Starting repository process..." -ForegroundColor Cyan
    
    # Test connection first
    if (-not (Test-AzureDevOpsConnection)) {
        Write-Error "Failed to connect to Azure DevOps. Please check your configuration."
        return @()
    }
    
    # If we're just getting repo info without scanning
    if ($SkipScan) {
        Write-Host "Skipping scan, just retrieving repository information" -ForegroundColor Yellow
        return Get-RepositoriesOnly -RepositoryName $RepositoryName
    }
    
    # Rest of the original function continues here...
    # [Rest of your existing code]
    
    # Make sure to return an empty array rather than null if no results
    return $script:repositoryScanResults
}

# Function to get the current scan results
function Get-RepositoryScanResults {
    return $script:repositoryScanResults
}

# Export functions
#Export-ModuleMember -Function Start-RepositoryScan, Get-RepositoryScanResults

