# Dizzy - Azure DevOps Analyzer GUI .
# Provides a GUI interface for setting up and running Azure DevOps analysis

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Dizzy - Azure DevOps Analyzer"
$form.Size = New-Object System.Drawing.Size(600, 450)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSHOME\powershell.exe")

# Add title label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(560, 30)
$titleLabel.Text = "Dizzy"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$form.Controls.Add($titleLabel)

# Add subtitle label
$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Location = New-Object System.Drawing.Point(20, 50)
$subtitleLabel.Size = New-Object System.Drawing.Size(560, 20)
$subtitleLabel.Text = "Azure DevOps Security & Analysis Tool"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Italic)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$form.Controls.Add($subtitleLabel)

# Add description
$descriptionLabel = New-Object System.Windows.Forms.Label
$descriptionLabel.Location = New-Object System.Drawing.Point(20, 80)
$descriptionLabel.Size = New-Object System.Drawing.Size(560, 40)
$descriptionLabel.Text = "Scan Azure DevOps pipelines, repositories, and artifacts for security issues and performance insights."
$descriptionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($descriptionLabel)

# Create tabControl for Setup and Run
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(20, 130)
$tabControl.Size = New-Object System.Drawing.Size(560, 250)
$form.Controls.Add($tabControl)

# Create Setup tab
$setupTab = New-Object System.Windows.Forms.TabPage
$setupTab.Text = "Setup"
$tabControl.Controls.Add($setupTab)

# Create Run tab
$runTab = New-Object System.Windows.Forms.TabPage
$runTab.Text = "Run Analysis"
$tabControl.Controls.Add($runTab)

# ---- SETUP TAB CONTROLS ----

# Organization URL Label and TextBox
$orgUrlLabel = New-Object System.Windows.Forms.Label
$orgUrlLabel.Location = New-Object System.Drawing.Point(10, 20)
$orgUrlLabel.Size = New-Object System.Drawing.Size(150, 20)
$orgUrlLabel.Text = "Azure DevOps URL:"
$orgUrlLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$setupTab.Controls.Add($orgUrlLabel)

$orgUrlTextbox = New-Object System.Windows.Forms.TextBox
$orgUrlTextbox.Location = New-Object System.Drawing.Point(160, 20)
$orgUrlTextbox.Size = New-Object System.Drawing.Size(380, 20)
$orgUrlTextbox.Text = "https://dev.azure.com/your-organization"
$setupTab.Controls.Add($orgUrlTextbox)

# PAT Token Label and TextBox
$patLabel = New-Object System.Windows.Forms.Label
$patLabel.Location = New-Object System.Drawing.Point(10, 50)
$patLabel.Size = New-Object System.Drawing.Size(150, 20)
$patLabel.Text = "Personal Access Token:"
$patLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$setupTab.Controls.Add($patLabel)

$patTextbox = New-Object System.Windows.Forms.TextBox
$patTextbox.Location = New-Object System.Drawing.Point(160, 50)
$patTextbox.Size = New-Object System.Drawing.Size(380, 20)
$patTextbox.PasswordChar = '*'
$setupTab.Controls.Add($patTextbox)

# Project Label and TextBox
$projectLabel = New-Object System.Windows.Forms.Label
$projectLabel.Location = New-Object System.Drawing.Point(10, 80)
$projectLabel.Size = New-Object System.Drawing.Size(150, 20)
$projectLabel.Text = "Project Name:"
$projectLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$setupTab.Controls.Add($projectLabel)

$projectTextbox = New-Object System.Windows.Forms.TextBox
$projectTextbox.Location = New-Object System.Drawing.Point(160, 80)
$projectTextbox.Size = New-Object System.Drawing.Size(380, 20)
$setupTab.Controls.Add($projectTextbox)

# Repository Label and TextBox
$repoLabel = New-Object System.Windows.Forms.Label
$repoLabel.Location = New-Object System.Drawing.Point(10, 110)
$repoLabel.Size = New-Object System.Drawing.Size(150, 20)
$repoLabel.Text = "Repository (optional):"
$repoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$setupTab.Controls.Add($repoLabel)

$repoTextbox = New-Object System.Windows.Forms.TextBox
$repoTextbox.Location = New-Object System.Drawing.Point(160, 110)
$repoTextbox.Size = New-Object System.Drawing.Size(380, 20)
$setupTab.Controls.Add($repoTextbox)

# Pipeline Label and TextBox
$pipelineLabel = New-Object System.Windows.Forms.Label
$pipelineLabel.Location = New-Object System.Drawing.Point(10, 140)
$pipelineLabel.Size = New-Object System.Drawing.Size(150, 20)
$pipelineLabel.Text = "Pipeline ID (optional):"
$pipelineLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$setupTab.Controls.Add($pipelineLabel)

$pipelineTextbox = New-Object System.Windows.Forms.TextBox
$pipelineTextbox.Location = New-Object System.Drawing.Point(160, 140)
$pipelineTextbox.Size = New-Object System.Drawing.Size(380, 20)
$setupTab.Controls.Add($pipelineTextbox)

# Save Connection Button
$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Location = New-Object System.Drawing.Point(390, 180)
$saveButton.Size = New-Object System.Drawing.Size(150, 30)
$saveButton.Text = "Save Configuration"
$saveButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$saveButton.ForeColor = [System.Drawing.Color]::White
$saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$setupTab.Controls.Add($saveButton)

# Test Connection Button
$testButton = New-Object System.Windows.Forms.Button
$testButton.Location = New-Object System.Drawing.Point(230, 180)
$testButton.Size = New-Object System.Drawing.Size(150, 30)
$testButton.Text = "Test Connection"
$testButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$testButton.ForeColor = [System.Drawing.Color]::White
$testButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$setupTab.Controls.Add($testButton)

# ---- RUN TAB CONTROLS ----

# Scan Options GroupBox
$scanOptionsGroup = New-Object System.Windows.Forms.GroupBox
$scanOptionsGroup.Location = New-Object System.Drawing.Point(10, 10)
$scanOptionsGroup.Size = New-Object System.Drawing.Size(530, 150)
$scanOptionsGroup.Text = "Scan Options"
$runTab.Controls.Add($scanOptionsGroup)

# Repository Scan Checkbox
$repoScanCheckbox = New-Object System.Windows.Forms.CheckBox
$repoScanCheckbox.Location = New-Object System.Drawing.Point(20, 30)
$repoScanCheckbox.Size = New-Object System.Drawing.Size(240, 20)
$repoScanCheckbox.Text = "Scan repositories for secrets/API keys"
$repoScanCheckbox.Checked = $true
$scanOptionsGroup.Controls.Add($repoScanCheckbox)

# Pipeline Scan Checkbox
$pipelineScanCheckbox = New-Object System.Windows.Forms.CheckBox
$pipelineScanCheckbox.Location = New-Object System.Drawing.Point(20, 55)
$pipelineScanCheckbox.Size = New-Object System.Drawing.Size(240, 20)
$pipelineScanCheckbox.Text = "Analyze pipeline definitions"
$pipelineScanCheckbox.Checked = $true
$scanOptionsGroup.Controls.Add($pipelineScanCheckbox)

# Build Scan Checkbox
$buildScanCheckbox = New-Object System.Windows.Forms.CheckBox
$buildScanCheckbox.Location = New-Object System.Drawing.Point(20, 80)
$buildScanCheckbox.Size = New-Object System.Drawing.Size(240, 20)
$buildScanCheckbox.Text = "Analyze build history and artifacts"
$buildScanCheckbox.Checked = $true
$scanOptionsGroup.Controls.Add($buildScanCheckbox)

# Release Scan Checkbox
$releaseScanCheckbox = New-Object System.Windows.Forms.CheckBox
$releaseScanCheckbox.Location = New-Object System.Drawing.Point(20, 105)
$releaseScanCheckbox.Size = New-Object System.Drawing.Size(240, 20)
$releaseScanCheckbox.Text = "Analyze release definitions and history"
$releaseScanCheckbox.Checked = $true
$scanOptionsGroup.Controls.Add($releaseScanCheckbox)

# Scan Depth Options
$scanDepthLabel = New-Object System.Windows.Forms.Label
$scanDepthLabel.Location = New-Object System.Drawing.Point(280, 30)
$scanDepthLabel.Size = New-Object System.Drawing.Size(100, 20)
$scanDepthLabel.Text = "Scan Depth:"
$scanOptionsGroup.Controls.Add($scanDepthLabel)

$scanDepthCombo = New-Object System.Windows.Forms.ComboBox
$scanDepthCombo.Location = New-Object System.Drawing.Point(380, 30)
$scanDepthCombo.Size = New-Object System.Drawing.Size(130, 20)
$scanDepthCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$scanDepthCombo.Items.Add("Light (Faster)")
[void]$scanDepthCombo.Items.Add("Medium")
[void]$scanDepthCombo.Items.Add("Deep (Slower)")
$scanDepthCombo.SelectedIndex = 1
$scanOptionsGroup.Controls.Add($scanDepthCombo)

# Day Limit Options
$dayLimitLabel = New-Object System.Windows.Forms.Label
$dayLimitLabel.Location = New-Object System.Drawing.Point(280, 60)
$dayLimitLabel.Size = New-Object System.Drawing.Size(100, 20)
$dayLimitLabel.Text = "History (days):"
$scanOptionsGroup.Controls.Add($dayLimitLabel)

$dayLimitNumeric = New-Object System.Windows.Forms.NumericUpDown
$dayLimitNumeric.Location = New-Object System.Drawing.Point(380, 60)
$dayLimitNumeric.Size = New-Object System.Drawing.Size(130, 20)
$dayLimitNumeric.Minimum = 1
$dayLimitNumeric.Maximum = 365
$dayLimitNumeric.Value = 30
$scanOptionsGroup.Controls.Add($dayLimitNumeric)

# Run Scan Button
$runScanButton = New-Object System.Windows.Forms.Button
$runScanButton.Location = New-Object System.Drawing.Point(390, 180)
$runScanButton.Size = New-Object System.Drawing.Size(150, 30)
$runScanButton.Text = "Run Analysis"
$runScanButton.BackColor = [System.Drawing.Color]::FromArgb(0, 153, 0)
$runScanButton.ForeColor = [System.Drawing.Color]::White
$runScanButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$runTab.Controls.Add($runScanButton)

# Add status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 390)
$statusLabel.Size = New-Object System.Drawing.Size(560, 20)
$statusLabel.Text = "Ready"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($statusLabel)

# Get the script path
$scriptPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}

# Save Configuration button click event
$saveButton.Add_Click({
    $statusLabel.Text = "Saving configuration..."
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $form.Refresh()
    
    try {
        # Create configuration folder if it doesn't exist
        $configFolder = Join-Path -Path $env:USERPROFILE -ChildPath ".dizzy"
        if (-not (Test-Path $configFolder)) {
            New-Item -Path $configFolder -ItemType Directory -Force | Out-Null
        }
        
        # Save configuration to file (excluding PAT)
        $configFile = Join-Path -Path $configFolder -ChildPath "config.json"
        $config = @{
            OrganizationUrl = $orgUrlTextbox.Text
            Project = $projectTextbox.Text
            Repository = $repoTextbox.Text
            PipelineId = $pipelineTextbox.Text
            LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        $config | ConvertTo-Json | Out-File -FilePath $configFile -Force
        
        # Store PAT in Windows Credential Manager or environment variable
        # For simplicity, using environment variable, but Credential Manager would be more secure
        [Environment]::SetEnvironmentVariable("DIZZY_PAT", $patTextbox.Text, "User")
        
        $statusLabel.Text = "Configuration saved successfully!"
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
    }
    catch {
        $statusLabel.Text = "Error saving configuration: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# Test Connection button click event
$testButton.Add_Click({
    $statusLabel.Text = "Testing connection to Azure DevOps..."
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $form.Refresh()
    
    try {
        # Get values from form
        $orgUrl = $orgUrlTextbox.Text
        $pat = $patTextbox.Text
        $project = $projectTextbox.Text
        
        if ([string]::IsNullOrWhiteSpace($orgUrl) -or [string]::IsNullOrWhiteSpace($pat) -or [string]::IsNullOrWhiteSpace($project)) {
            throw "Organization URL, PAT, and Project Name are required!"
        }
        
        # Build basic auth header
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
        }
        
        # Test connection by getting project info
        $projectApiUrl = "$orgUrl/$project/_apis/projects?api-version=6.0"
        
        $response = Invoke-RestMethod -Uri $projectApiUrl -Headers $headers -Method Get -ErrorAction Stop
        
        $statusLabel.Text = "Connection successful! Project verified."
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
    }
    catch {
        $statusLabel.Text = "Connection failed: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# Run Analysis button click event
$runScanButton.Add_Click({
    $statusLabel.Text = "Starting Azure DevOps analysis..."
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 153, 0)
    $form.Refresh()
    
    try {
        # Check if config file exists
        $configFolder = Join-Path -Path $env:USERPROFILE -ChildPath ".dizzy"
        $configFile = Join-Path -Path $configFolder -ChildPath "config.json"
        
        if (-not (Test-Path $configFile)) {
            throw "Configuration not found. Please set up Azure DevOps connection first!"
        }
        
        # Get PAT from environment variable
        $pat = [Environment]::GetEnvironmentVariable("DIZZY_PAT", "User")
        if ([string]::IsNullOrWhiteSpace($pat)) {
            throw "Personal Access Token not found. Please set up Azure DevOps connection first!"
        }
        
        # Get scan options
        $scanOptions = @{
            ScanRepositories = $repoScanCheckbox.Checked
            ScanPipelines = $pipelineScanCheckbox.Checked
            ScanBuilds = $buildScanCheckbox.Checked
            ScanReleases = $releaseScanCheckbox.Checked
            ScanDepth = $scanDepthCombo.SelectedItem
            HistoryDays = $dayLimitNumeric.Value
        }
        
        # Start the execution process in a new window
        $scriptName = Join-Path -Path $scriptPath -ChildPath "Dizzy-Analyzer.ps1"
        
        if (Test-Path $scriptName) {
            # Convert scan options to parameters
            $scanOptionsJson = $scanOptions | ConvertTo-Json -Compress
            $encodedOptions = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($scanOptionsJson))
            
            # Start the script in a new PowerShell window
            Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -Command `"& '$scriptName' -EncodedOptions '$encodedOptions'`""
            
            $statusLabel.Text = "Analysis started in new window!"
            $statusLabel.ForeColor = [System.Drawing.Color]::Green
        }
        else {
            throw "Analysis script not found at: $scriptName"
        }
    }
    catch {
        $statusLabel.Text = "Error starting analysis: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# Load existing configuration if available
try {
    $configFolder = Join-Path -Path $env:USERPROFILE -ChildPath ".dizzy"
    $configFile = Join-Path -Path $configFolder -ChildPath "config.json"
    
    if (Test-Path $configFile) {
        $config = Get-Content -Path $configFile | ConvertFrom-Json
        
        $orgUrlTextbox.Text = $config.OrganizationUrl
        $projectTextbox.Text = $config.Project
        
        if (-not [string]::IsNullOrWhiteSpace($config.Repository)) {
            $repoTextbox.Text = $config.Repository
        }
        
        if (-not [string]::IsNullOrWhiteSpace($config.PipelineId)) {
            $pipelineTextbox.Text = $config.PipelineId
        }
        
        # Get PAT from environment variable (don't display it for security)
        $pat = [Environment]::GetEnvironmentVariable("DIZZY_PAT", "User")
        if (-not [string]::IsNullOrWhiteSpace($pat)) {
            $patTextbox.Text = "********************"
        }
        
        $statusLabel.Text = "Configuration loaded. Last updated: $($config.LastUpdated)"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    }
}
catch {
    # Silently fail if config can't be loaded
    $statusLabel.Text = "No existing configuration found. Please configure Azure DevOps connection."
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
}

# Show the form
$form.ShowDialog()

