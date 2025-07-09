# Dizzy - Diagnostics Tool 
# This script tests API connections and data retrieval 

# Get the script's directory
$scriptPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}

# Define paths to utility scripts - adjust these paths to match your environment
$corePath = Join-Path -Path $scriptPath -ChildPath "Core"
$authModulePath = Join-Path -Path $corePath -ChildPath "ADO-Authentication.ps1"

# Load authentication module
Write-Host "Loading authentication module from: $authModulePath"
if (Test-Path $authModulePath) {
    . $authModulePath
    Write-Host "Successfully loaded ADO-Authentication.ps1" -ForegroundColor Green
}
else {
    Write-Error "Critical module not found: ADO-Authentication.ps1 at $authModulePath"
    exit
}

Write-Host @"

╔═════════════════════════════════════════════════════╗
║             DIZZY DIAGNOSTICS TOOL                  ║
║        Azure DevOps API Connection Tester           ║
╚═════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Test basic connection
Write-Host "[TEST 1] Basic connection test..." -ForegroundColor Yellow
$config = Get-DizzyConfig
if ($null -eq $config) {
    Write-Error "Configuration not found. Please run setup first."
    exit
}

Write-Host "Organization URL: $($config.OrganizationUrl)" -ForegroundColor White
Write-Host "Project: $($config.Project)" -ForegroundColor White

$headers = Get-AzureDevOpsAuthHeader
if ($null -eq $headers) {
    Write-Error "Failed to get authentication headers. Check your PAT."
    exit
}

# Test project API
Write-Host "`n[TEST 2] Project API test..." -ForegroundColor Yellow
try {
    $endpoints = Get-AzureDevOpsApiEndpoints
    $projectApiUrl = $endpoints.ProjectApi.Info
    
    Write-Host "API URL: $projectApiUrl" -ForegroundColor White
    
    $response = Invoke-RestMethod -Uri $projectApiUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Host "Success! Retrieved $($response.count) projects" -ForegroundColor Green
    foreach ($proj in $response.value) {
        Write-Host "  - Project: $($proj.name) (ID: $($proj.id))" -ForegroundColor White
    }
}
catch {
    Write-Error "Failed to connect to Azure DevOps Projects API: $_"
}

# Test Git repositories API
Write-Host "`n[TEST 3] Git repositories API test..." -ForegroundColor Yellow
try {
    $reposUrl = $endpoints.Git.Repositories
    
    Write-Host "API URL: $reposUrl" -ForegroundColor White
    
    $response = Invoke-RestMethod -Uri $reposUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Host "Success! Retrieved $($response.count) repositories" -ForegroundColor Green
    Write-Host "Raw response type: $($response.GetType().FullName)" -ForegroundColor White
    
    if ($response.value.Count -eq 0) {
        Write-Host "No repositories found in the organization." -ForegroundColor Yellow
    }
    else {
        foreach ($repo in $response.value) {
            Write-Host "  - Repository: $($repo.name) (ID: $($repo.id))" -ForegroundColor White
        }
    }
    
    # Check if repositories response has expected properties
    $firstRepo = $response.value | Select-Object -First 1
    if ($firstRepo) {
        Write-Host "`nSample repository properties:" -ForegroundColor Cyan
        $firstRepo.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
        }
    }
}
catch {
    Write-Error "Failed to connect to Azure DevOps Git API: $_"
}

# Test Project-specific repositories
Write-Host "`n[TEST 4] Project-specific repositories test..." -ForegroundColor Yellow
try {
    $projectReposUrl = "$($config.OrganizationUrl)/$($config.Project)/_apis/git/repositories?api-version=6.0"
    
    Write-Host "API URL: $projectReposUrl" -ForegroundColor White
    
    $response = Invoke-RestMethod -Uri $projectReposUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Host "Success! Retrieved $($response.count) repositories in project $($config.Project)" -ForegroundColor Green
    if ($response.value.Count -eq 0) {
        Write-Host "No repositories found in this project." -ForegroundColor Yellow
    }
    else {
        foreach ($repo in $response.value) {
            Write-Host "  - Repository: $($repo.name) (ID: $($repo.id))" -ForegroundColor White
        }
    }
}
catch {
    Write-Error "Failed to connect to Project Git API: $_"
}

# Test Pipelines API
Write-Host "`n[TEST 5] Pipelines API test..." -ForegroundColor Yellow
try {
    $pipelinesUrl = $endpoints.Pipeline.Pipelines
    
    Write-Host "API URL: $pipelinesUrl" -ForegroundColor White
    
    $response = Invoke-RestMethod -Uri $pipelinesUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Host "Success! Retrieved $($response.count) pipelines" -ForegroundColor Green
    Write-Host "Raw response type: $($response.GetType().FullName)" -ForegroundColor White
    
    if ($response.value.Count -eq 0) {
        Write-Host "No pipelines found in the project." -ForegroundColor Yellow
    }
    else {
        foreach ($pipeline in $response.value) {
            Write-Host "  - Pipeline: $($pipeline.name) (ID: $($pipeline.id))" -ForegroundColor White
        }
    }
    
    # Check if pipeline response has expected properties
    $firstPipeline = $response.value | Select-Object -First 1
    if ($firstPipeline) {
        Write-Host "`nSample pipeline properties:" -ForegroundColor Cyan
        $firstPipeline.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
        }
    }
}
catch {
    Write-Error "Failed to connect to Azure DevOps Pipelines API: $_"
}

# Test direct API calls with cleaner URLs
Write-Host "`n[TEST 6] Direct API calls test..." -ForegroundColor Yellow
try {
    $baseApiUrl = if ($config.OrganizationUrl -match "dev\.azure\.com") {
        "$($config.OrganizationUrl)/$($config.Project)/_apis"
    } else {
        "$($config.OrganizationUrl)/$($config.Project)/_apis"
    }
    
    $directReposUrl = "$baseApiUrl/git/repositories?api-version=6.0"
    $directPipelinesUrl = "$baseApiUrl/pipelines?api-version=6.0"
    
    Write-Host "Direct Repositories URL: $directReposUrl" -ForegroundColor White
    $repoResponse = Invoke-RestMethod -Uri $directReposUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Host "Direct Pipelines URL: $directPipelinesUrl" -ForegroundColor White
    $pipelineResponse = Invoke-RestMethod -Uri $directPipelinesUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Host "Direct API results:" -ForegroundColor Green
    Write-Host "  - Repositories: $($repoResponse.count)" -ForegroundColor White
    Write-Host "  - Pipelines: $($pipelineResponse.count)" -ForegroundColor White
}
catch {
    Write-Error "Failed direct API calls: $_"
}

Write-Host "`nDiagnostics completed!" -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Add these additional tests to your Dizzy-Diagnostics.ps1 file
# or create a new script with these tests focused on repositories

Write-Host "`n[TEST 7] Detailed repository analysis..." -ForegroundColor Yellow
try {
    $config = Get-DizzyConfig
    $headers = Get-AzureDevOpsAuthHeader
    
    # Test project-specific repositories call
    $projectReposUrl = "$($config.OrganizationUrl)/$($config.Project)/_apis/git/repositories?api-version=6.0"
    Write-Host "Testing project repositories: $projectReposUrl" -ForegroundColor White
    
    $repoResponse = Invoke-RestMethod -Uri $projectReposUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Host "Success! Found $($repoResponse.count) repositories in project $($config.Project)" -ForegroundColor Green
    foreach ($repo in $repoResponse.value) {
        Write-Host "  - $($repo.name) (ID: $($repo.id))" -ForegroundColor White
    }
    
    # Now test how repositories would be processed
    $repoResults = @()
    foreach ($repo in $repoResponse.value) {
        $repoInfo = @{
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
    
    Write-Host "Successfully processed $($repoResults.Count) repositories into result objects" -ForegroundColor Green
    
    # Check what the Get-RepositoriesOnly function would return
    if (Get-Command -Name Get-RepositoriesOnly -ErrorAction SilentlyContinue) {
        Write-Host "`nTesting Get-RepositoriesOnly function..." -ForegroundColor Yellow
        $functionResults = Get-RepositoriesOnly
        
        if ($null -eq $functionResults) {
            Write-Host "Function returned NULL" -ForegroundColor Red
        } elseif ($functionResults.Count -eq 0) {
            Write-Host "Function returned empty array (0 items)" -ForegroundColor Red
        } else {
            Write-Host "Function returned $($functionResults.Count) repositories" -ForegroundColor Green
            foreach ($repo in $functionResults) {
                Write-Host "  - $($repo.RepositoryName) (ID: $($repo.RepositoryId))" -ForegroundColor White
            }
        }
    } else {
        Write-Host "Get-RepositoriesOnly function not found, skipping test" -ForegroundColor Yellow
    }
    
    # Check what the Start-RepositoryScan function would return with SkipScan
    if (Get-Command -Name Start-RepositoryScan -ErrorAction SilentlyContinue) {
        Write-Host "`nTesting Start-RepositoryScan function with SkipScan..." -ForegroundColor Yellow
        $scanResults = Start-RepositoryScan -SkipScan
        
        if ($null -eq $scanResults) {
            Write-Host "Function returned NULL" -ForegroundColor Red
        } elseif ($scanResults.Count -eq 0) {
            Write-Host "Function returned empty array (0 items)" -ForegroundColor Red
        } else {
            Write-Host "Function returned $($scanResults.Count) repositories" -ForegroundColor Green
            foreach ($repo in $scanResults) {
                Write-Host "  - $($repo.RepositoryName) (ID: $($repo.RepositoryId))" -ForegroundColor White
            }
        }
    } else {
        Write-Host "Start-RepositoryScan function not found, skipping test" -ForegroundColor Yellow
    }
    
    # Test how these would be processed in Start-AllAnalysis
    if (Get-Command -Name Start-AllAnalysis -ErrorAction SilentlyContinue) {
        Write-Host "`nTesting Start-AllAnalysis function with EnsureBaselineData..." -ForegroundColor Yellow
        $analysisResults = Start-AllAnalysis -EnsureBaselineData
        
        if ($null -eq $analysisResults) {
            Write-Host "Function returned NULL" -ForegroundColor Red
        } else {
            Write-Host "Analysis results object created successfully" -ForegroundColor Green
            
            if ($null -eq $analysisResults.RepositoryResults) {
                Write-Host "RepositoryResults is NULL" -ForegroundColor Red
            } elseif ($analysisResults.RepositoryResults.Count -eq 0) {
                Write-Host "RepositoryResults is empty (0 items)" -ForegroundColor Red
            } else {
                Write-Host "RepositoryResults contains $($analysisResults.RepositoryResults.Count) repositories" -ForegroundColor Green
                foreach ($repo in $analysisResults.RepositoryResults) {
                    Write-Host "  - $($repo.RepositoryName) (ID: $($repo.RepositoryId))" -ForegroundColor White
                }
            }
        }
    } else {
        Write-Host "Start-AllAnalysis function not found, skipping test" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Repository analysis failed: $_"
}

# Test Dashboard HTML Generation
Write-Host "`n[TEST 8] Dashboard HTML generation test..." -ForegroundColor Yellow
try {
    # Create a test repository array
    $testRepos = @()
    foreach ($repo in $repoResponse.value) {
        $repoInfo = @{
            RepositoryName = $repo.name
            RepositoryId = $repo.id
            DefaultBranch = $repo.defaultBranch
            Url = $repo.webUrl
            ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ScannedFilesCount = 0
            TotalFilesCount = 0
            Findings = @()
        }
        
        $testRepos += $repoInfo
    }
    
    # Test if we can generate dashboard HTML with these repositories
    if (Get-Command -Name New-DashboardSummaryHtml -ErrorAction SilentlyContinue) {
        Write-Host "Testing dashboard HTML generation with $($testRepos.Count) repositories..." -ForegroundColor Yellow
        
        # Create test object
        $testScanInfo = @{
            OrganizationUrl = $config.OrganizationUrl
            Project = $config.Project
            Repository = ""
            ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ScanDuration = 0.1
            ScanDepth = "Deep"
            HistoryDays = 30
        }
        
        # Try to generate HTML
        $htmlContent = New-DashboardSummaryHtml -ScanInfo $testScanInfo -RepoResults $testRepos
        
        if ($null -eq $htmlContent) {
            Write-Host "HTML generation returned NULL" -ForegroundColor Red
        } else {
            Write-Host "Successfully generated HTML content" -ForegroundColor Green
            
            # Check if HTML contains repository count
            $repoCountPattern = '<div class=.stat-value.>\s*' + $testRepos.Count + '\s*</div>\s*<div class=.stat-label.>\s*Repositories\s*</div>'
            if ($htmlContent -match $repoCountPattern) {
                Write-Host "HTML contains correct repository count: $($testRepos.Count)" -ForegroundColor Green
            } else {
                Write-Host "HTML does NOT contain correct repository count!" -ForegroundColor Red
                
                # Extract what it does contain
                if ($htmlContent -match '<div class=.stat-value.>\s*(\d+)\s*</div>\s*<div class=.stat-label.>\s*Repositories\s*</div>') {
                    Write-Host "HTML shows repository count as: $($Matches[1])" -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "New-DashboardSummaryHtml function not found, skipping test" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Dashboard HTML generation test failed: $_"
}
