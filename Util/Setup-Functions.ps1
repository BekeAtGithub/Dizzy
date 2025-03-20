# Dizzy - Azure DevOps Analyzer
# Setup and environment validation utility functions

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$utilPath = $scriptPath
$configModulePath = Join-Path -Path $utilPath -ChildPath "Config-Management.ps1"

# Import config module if it exists
if (Test-Path $configModulePath) {
    . $configModulePath
} else {
    Write-Error "Required module not found: Config-Management.ps1"
    exit
}

# Function to check for required PowerShell modules
function Test-RequiredModules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Install
    )
    
    # List of required modules
    $requiredModules = @()
    
    # No external modules required yet, but easy to add here if needed
    # Uncomment and add module names if required in future
    # $requiredModules = @('ModuleName1', 'ModuleName2')
    
    $missingModules = @()
    
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            $missingModules += $module
        }
    }
    
    # Return success if no modules are missing
    if ($missingModules.Count -eq 0) {
        Write-Verbose "All required modules are installed."
        return $true
    }
    
    # If install switch is specified, try to install missing modules
    if ($Install) {
        Write-Host "Installing required modules: $($missingModules -join ', ')" -ForegroundColor Yellow
        
        foreach ($module in $missingModules) {
            try {
                Write-Host "Installing module: $module" -ForegroundColor Cyan
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
                Write-Host "Successfully installed module: $module" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to install module: $module. Error: $_"
                return $false
            }
        }
        
        return $true
    }
    else {
        Write-Warning "Missing required modules: $($missingModules -join ', ')"
        Write-Warning "Run with -Install switch to automatically install missing modules."
        return $false
    }
}

# Function to verify PowerShell version
function Test-PowerShellVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [version]$MinimumVersion = "5.1"
    )
    
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion -ge $MinimumVersion) {
        Write-Verbose "PowerShell version $currentVersion meets the minimum requirement of $MinimumVersion."
        return $true
    }
    else {
        Write-Warning "PowerShell version $currentVersion does not meet the minimum requirement of $MinimumVersion."
        Write-Warning "Please update to PowerShell $MinimumVersion or later: https://github.com/PowerShell/PowerShell"
        return $false
    }
}

# Function to validate PAT format
function Test-PatFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PAT
    )
    
    # Azure DevOps PATs are typically all numbers and letters
    # This is a basic format check, not a full validation
    if ($PAT -match "^[a-zA-Z0-9]{52}$") {
        return $true
    }
    else {
        Write-Warning "The provided PAT doesn't match the expected format."
        Write-Warning "Azure DevOps PATs are typically 52 characters long and contain only letters and numbers."
        return $false
    }
}

# Function to validate Azure DevOps URL format
function Test-AzureDevOpsUrlFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    # Check if the URL matches expected format
    if ($Url -match "^https://dev\.azure\.com/[a-zA-Z0-9_-]+/?$") {
        return $true
    }
    elseif ($Url -match "^https://[a-zA-Z0-9_-]+\.visualstudio\.com/?$") {
        return $true
    }
    else {
        Write-Warning "The provided URL doesn't match the expected Azure DevOps format."
        Write-Warning "Expected format: https://dev.azure.com/{organization} or https://{organization}.visualstudio.com"
        return $false
    }
}

# Function to prompt for and validate Azure DevOps URL
function Get-ValidAzureDevOpsUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DefaultUrl = ""
    )
    
    $url = $DefaultUrl
    $isValid = $false
    
    while (-not $isValid) {
        if ([string]::IsNullOrWhiteSpace($url)) {
            $url = Read-Host "Enter Azure DevOps organization URL (e.g., https://dev.azure.com/your-organization)"
        }
        
        $isValid = Test-AzureDevOpsUrlFormat -Url $url
        
        if (-not $isValid) {
            $url = ""  # Reset URL to prompt again
        }
    }
    
    # Ensure URL doesn't end with a trailing slash
    $url = $url.TrimEnd('/')
    
    return $url
}

# Function to prompt for and validate PAT
function Get-ValidPAT {
    [CmdletBinding()]
    param()
    
    $isValid = $false
    $pat = ""
    
    while (-not $isValid) {
        $secureString = Read-Host "Enter Personal Access Token (PAT)" -AsSecureString
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
        $pat = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        
        $isValid = Test-PatFormat -PAT $pat
        
        if (-not $isValid) {
            # Give option to continue anyway
            $continue = Read-Host "PAT format validation failed. Continue anyway? (Y/N)"
            if ($continue -eq "Y") {
                $isValid = $true
            }
        }
    }
    
    return $pat
}

# Function to log PAT permissions when connecting
function Get-PatPermissionsInfo {
    [CmdletBinding()]
    param()
    
    $permissions = Test-DizzyPatPermissions
    
    if (-not $permissions.Result) {
        Write-Host "PAT permissions summary:" -ForegroundColor Yellow
        
        foreach ($perm in $permissions.Permissions.GetEnumerator()) {
            $status = if ($perm.Value) { "✓" } else { "✗" }
            $color = if ($perm.Value) { "Green" } else { "Red" }
            Write-Host "  $status $($perm.Key) access" -ForegroundColor $color
        }
        
        # Provide guidance on minimum required permissions
        Write-Host "`nMinimum required PAT scopes:" -ForegroundColor Cyan
        Write-Host "  - Code (Read)"
        Write-Host "  - Build (Read)"
        Write-Host "  - Release (Read)"
        Write-Host "  - Pipeline Resources (Read)"
        
        Write-Host "`nRecommended PAT creation steps:" -ForegroundColor Cyan
        Write-Host "1. Go to Azure DevOps > User settings > Personal access tokens"
        Write-Host "2. Create a new token with the name 'Dizzy Analysis'"
        Write-Host "3. Set the organization to your organization"
        Write-Host "4. Set the expiration as needed"
        Write-Host "5. Select Custom defined scope"
        Write-Host "6. Check the following permissions:"
        Write-Host "   - Code: Read"
        Write-Host "   - Build: Read"
        Write-Host "   - Release: Read"
        Write-Host "   - Pipeline Resources: Read"
        Write-Host "7. Create the token and copy it"
        
        return $permissions.Permissions
    }
    
    Write-Host "PAT has all the required permissions." -ForegroundColor Green
    return $permissions.Permissions
}

# Function to set up Dizzy configuration interactively
function Initialize-DizzySetup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    Write-Host @"
    
    ╔═══════════════════════════════════════════════════════════╗
    ║                       DIZZY                               ║
    ║           Azure DevOps Security & Analysis Tool           ║
    ║                      SETUP WIZARD                         ║
    ╚═══════════════════════════════════════════════════════════╝
    
"@ -ForegroundColor Cyan
    
    # Check if already configured
    $existingConfig = Get-DizzyConfig
    $configExists = ($null -ne $existingConfig -and 
                    -not [string]::IsNullOrWhiteSpace($existingConfig.OrganizationUrl) -and 
                    -not [string]::IsNullOrWhiteSpace($existingConfig.Project))
    
    $pat = Get-DizzyPAT
    $patExists = (-not [string]::IsNullOrWhiteSpace($pat))
    
    if ($configExists -and $patExists -and -not $Force) {
        Write-Host "Dizzy is already configured with the following settings:" -ForegroundColor Green
        Write-Host "  Organization URL: $($existingConfig.OrganizationUrl)" -ForegroundColor White
        Write-Host "  Project: $($existingConfig.Project)" -ForegroundColor White
        
        if (-not [string]::IsNullOrWhiteSpace($existingConfig.Repository)) {
            Write-Host "  Repository: $($existingConfig.Repository)" -ForegroundColor White
        }
        
        if (-not [string]::IsNullOrWhiteSpace($existingConfig.PipelineId)) {
            Write-Host "  Pipeline ID: $($existingConfig.PipelineId)" -ForegroundColor White
        }
        
        $reconfigure = Read-Host "Do you want to reconfigure these settings? (Y/N)"
        if ($reconfigure -ne "Y") {
            # Test the connection with existing settings
            Write-Host "Testing connection with existing settings..." -ForegroundColor Cyan
            if (Test-DizzyConnection) {
                Write-Host "Connection successful! Your configuration is valid." -ForegroundColor Green
                
                # Get PAT permissions info
                Get-PatPermissionsInfo
                
                return $true
            }
            else {
                Write-Warning "Connection test failed with existing settings."
                $retrySetup = Read-Host "Would you like to reconfigure anyway? (Y/N)"
                if ($retrySetup -ne "Y") {
                    return $false
                }
            }
        }
    }
    
    # Check prerequisites
    Write-Host "Checking prerequisites..." -ForegroundColor Cyan
    $prereqsOk = $true
    
    if (-not (Test-PowerShellVersion)) {
        $prereqsOk = $false
    }
    
    if (-not (Test-RequiredModules -Install)) {
        $prereqsOk = $false
    }
    
    if (-not $prereqsOk) {
        $continue = Read-Host "Some prerequisites checks failed. Continue anyway? (Y/N)"
        if ($continue -ne "Y") {
            Write-Warning "Setup canceled due to missing prerequisites."
            return $false
        }
    }
    
    # Get and validate Azure DevOps Organization URL
    $orgUrl = Get-ValidAzureDevOpsUrl -DefaultUrl $(if ($existingConfig) { $existingConfig.OrganizationUrl } else { "" })
    
    # Get project
    $project = ""
    while ([string]::IsNullOrWhiteSpace($project)) {
        $project = Read-Host "Enter Azure DevOps Project name"
    }
    
    # Get repository (optional)
    $repository = Read-Host "Enter Repository name (optional, press Enter to skip)"
    
    # Get pipeline ID (optional)
    $pipelineId = Read-Host "Enter Pipeline ID (optional, press Enter to skip)"
    
    # Get and validate PAT
    $pat = Get-ValidPAT
    
    # Set output folder
    $outputFolder = Read-Host "Enter output folder for reports (optional, press Enter for default)"
    if ([string]::IsNullOrWhiteSpace($outputFolder)) {
        $outputFolder = Join-Path -Path $env:USERPROFILE -ChildPath "Dizzy-Results"
    }
    
    # Save configuration
    Write-Host "Saving configuration..." -ForegroundColor Cyan
    $configResult = Set-DizzyConfig -OrganizationUrl $orgUrl -Project $project -Repository $repository -PipelineId $pipelineId -OutputFolder $outputFolder
    
    if (-not $configResult) {
        Write-Error "Failed to save configuration."
        return $false
    }
    
    # Save PAT
    $patResult = Set-DizzyPAT -PAT $pat
    
    if (-not $patResult) {
        Write-Error "Failed to save PAT."
        return $false
    }
    
    # Test connection
    Write-Host "Testing connection with new settings..." -ForegroundColor Cyan
    if (Test-DizzyConnection) {
        Write-Host "Connection successful! Your configuration is valid." -ForegroundColor Green
        
        # Get PAT permissions info
        Get-PatPermissionsInfo
        
        Write-Host "`nSetup completed successfully. Dizzy is now configured and ready to use." -ForegroundColor Green
        return $true
    }
    else {
        Write-Error "Connection test failed with new settings. Please check your organization URL, project name, and PAT."
        return $false
    }
}

# Function to validate output folder
function Test-OutputFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    # Check if path exists
    if (Test-Path -Path $Path) {
        # Check if it's a directory
        if (-not (Get-Item -Path $Path).PSIsContainer) {
            Write-Error "The specified path exists but is not a directory: $Path"
            return $false
        }
        
        # Check if we have write permissions
        try {
            $testFile = Join-Path -Path $Path -ChildPath "dizzy_test_$([Guid]::NewGuid().ToString()).tmp"
            [IO.File]::WriteAllText($testFile, "Test")
            Remove-Item -Path $testFile -Force
            return $true
        }
        catch {
            Write-Error "Cannot write to the specified directory: $Path. Error: $_"
            return $false
        }
    }
    else {
        # Try to create the directory
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            return $true
        }
        catch {
            Write-Error "Cannot create the specified directory: $Path. Error: $_"
            return $false
        }
    }
}

# Function to create a Dizzy shortcut on the desktop
function New-DizzyShortcut {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false)]
        [string]$ShortcutPath = "$env:USERPROFILE\Desktop\Dizzy.lnk"
    )
    
    # Determine script path if not provided
    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        $ScriptPath = Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "..\Dizzy.ps1"
        $ScriptPath = Resolve-Path $ScriptPath -ErrorAction SilentlyContinue
        
        if ([string]::IsNullOrWhiteSpace($ScriptPath) -or -not (Test-Path -Path $ScriptPath)) {
            Write-Error "Could not find Dizzy.ps1 script."
            return $false
        }
    }
    
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`""
        $Shortcut.WorkingDirectory = Split-Path -Parent $ScriptPath
        $Shortcut.IconLocation = "powershell.exe,0"
        $Shortcut.Description = "Dizzy - Azure DevOps Security & Analysis Tool"
        $Shortcut.Save()
        
        Write-Host "Shortcut created at: $ShortcutPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to create shortcut: $_"
        return $false
    }
}

# Function to show help with PAT creation
function Show-PatHelp {
    [CmdletBinding()]
    param()
    
    Write-Host @"
    
    ╔═══════════════════════════════════════════════════════════╗
    ║       Personal Access Token (PAT) Creation Guide          ║
    ╚═══════════════════════════════════════════════════════════╝
    
    To analyze Azure DevOps, Dizzy needs a Personal Access Token (PAT)
    with the following permissions:
    
    Required Scopes:
      - Code (Read)
      - Build (Read)
      - Release (Read)
      - Pipeline Resources (Read)
    
    Steps to create a PAT:
    
    1. Go to Azure DevOps portal: https://dev.azure.com
    
    2. Click on your profile icon in the top-right corner
    
    3. Select "Personal access tokens"
    
    4. Click "+ New Token"
    
    5. Enter the following details:
       - Name: Dizzy Analyzer
       - Organization: Select your organization
       - Expiration: Choose an appropriate expiration date
       - Scopes: Select "Custom defined"
    
    6. Check the following permissions:
       - Code: Read
       - Build: Read
       - Release: Read
       - Pipeline Resources: Read
    
    7. Click "Create" and copy the generated token
    
    8. Paste the token when prompted by Dizzy setup
    
    Note: The PAT is stored securely in your user environment variables
    and is never transmitted anywhere except to Azure DevOps API.
    
"@ -ForegroundColor Cyan
}

# Function to upgrade Dizzy components
function Update-DizzyComponents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $false)]
        [string]$DestinationPath
    )
    
    # If no source path provided, assume we're in the source directory
    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        $SourcePath = Split-Path -Parent $scriptPath
        $SourcePath = Split-Path -Parent $SourcePath  # Go up one more level
    }
    
    # If no destination path provided, use the current location
    if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
        $DestinationPath = $SourcePath
    }
    
    try {
        # Find all PS1 files in the source path
        $sourceFiles = Get-ChildItem -Path $SourcePath -Filter "*.ps1" -Recurse
        $totalFiles = $sourceFiles.Count
        $copiedFiles = 0
        
        foreach ($file in $sourceFiles) {
            # Determine relative path
            $relativePath = $file.FullName.Substring($SourcePath.Length)
            $targetPath = Join-Path -Path $DestinationPath -ChildPath $relativePath
            $targetDir = Split-Path -Parent $targetPath
            
            # Create target directory if it doesn't exist
            if (-not (Test-Path -Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }
            
            # Copy the file
            Copy-Item -Path $file.FullName -Destination $targetPath -Force
            $copiedFiles++
            
            Write-Progress -Activity "Updating Dizzy Components" -Status "Copying $relativePath" -PercentComplete (($copiedFiles / $totalFiles) * 100)
        }
        
        Write-Progress -Activity "Updating Dizzy Components" -Completed
        Write-Host "Successfully updated $copiedFiles files." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to update Dizzy components: $_"
        return $false
    }
}

# Export functions
#Export-ModuleMember -Function Test-RequiredModules, Test-PowerShellVersion, 
#                              Test-PatFormat, Test-AzureDevOpsUrlFormat, 
#                              Get-ValidAzureDevOpsUrl, Get-ValidPAT, 
#                              Get-PatPermissionsInfo, Initialize-DizzySetup,
#                              Test-OutputFolder, New-DizzyShortcut, 
#                              Show-PatHelp, Update-DizzyComponents
