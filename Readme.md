# Dizzy - Azure DevOps Analyzer

hey there! 👋 welcome to **Dizzy**, the tool that'll help you find security issues and performance insights in your Azure DevOps environment without making you tear your hair out. who needs hair anyway?

## What is this thing?

Dizzy is a PowerShell-based tool that scans your Azure DevOps pipelines, repositories, builds, and releases to find:

- Secrets and API keys accidentally committed to repos (we've all been there)
- Security misconfigurations in your pipelines and builds
- Performance insights to make your CI/CD run smoother than your coffee after forgetting to eat lunch
- Issues that would make your security team stay up at night (more than they already do)

## Getting Started

### Prerequisites

- PowerShell 5.1 or higher (this is already on most Windows machines)
- An Azure DevOps account with a Personal Access Token (PAT)
- Basic will to live (optional but recommended)

### Installation

1. download the zip file and extract it somewhere sensible on your computer
2. make sure all files maintain their directory structure (Core, HTML, and Util folders)
3. that's it. no really, that's all you need to do.

### First time setup

you've got two options to run Dizzy - through the GUI (for pointing and clicking enthusiasts) or via command line (for the keyboard warriors among us).

#### GUI Method

1. right-click `Dizzy-GUI.ps1` and select "Run with PowerShell"
   - If you get security warnings, run PowerShell as admin and type: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
2. the setup tab will appear where you can fill in:
   - Azure DevOps URL (like `https://dev.azure.com/your-organization` or `https://your-organization.visualstudio.com`)
   - Personal Access Token (get this from Azure DevOps)
   - Project Name (the project you want to analyze)
   - Repository and Pipeline ID (optional)
3. click "Test Connection" to... well, test the connection
4. if successful, click "Save Configuration"
5. switch to the "Run Analysis" tab to start scanning

#### Command Line Method

1. open PowerShell
2. navigate to the Dizzy folder
3. run `.\Dizzy.ps1`
4. follow the interactive prompts to set up your configuration
5. let the tool do its magic

## Creating a PAT Token

If "PAT" sounds like something you pet and not a security token, here's how to get one:

1. go to Azure DevOps and click on your profile icon in the top-right
2. select "Personal access tokens"
3. click "New Token"
4. name it something memorable like "Dizzy-Analyzer" or "Please-Dont-Hack-Me"
5. set the expiration date (I'd recommend not setting it to forever, but you do you)
6. select the following permissions:
   - Code (Read)
   - Build (Read)
   - Release (Read)
   - Pipeline Resources (Read)
7. create the token and copy it (you won't be able to see it again, just like my motivation on Monday mornings)

## Running a Scan

after setup is done, running a scan is straightforward:

1. choose what you want to scan (repositoires, pipelines, builds, releases)
2. pick your scan depth (light for quick scans, deep for thorough ones)
3. set how far back in history you want to look
4. click the "Run Analysis" button and grab a coffee/tea/energy drink of choice

## Understanding Results

once the scan completes, Dizzy will open a dashboard in your default browser with:

- an overview of all findings and issues
- detailed analysis of any security issues found
- performance metrics for your builds and releases
- repository findings including potential secrets

the results are also saved as HTML files in the output folder (default is %USERPROFILE%\Dizzy-Results).

## Troubleshooting

if something goes wrong (and let's be honest, when doesn't it?), try these steps:

### Connection Issues

- double-check your URL format - it should be `https://dev.azure.com/your-organization` or `https://your-organization.visualstudio.com`
- verify your PAT hasn't expired (they tend to do that at the most inconvenient times)
- ensure your PAT has the right permissions
- test the connection using the included test script:

```powershell
# Test your connection with this script
$organization = "your-organization" 
$project = "your-project"
$pat = "your-pat-token"

$baseUrl = "https://$organization.visualstudio.com"
# OR
# $baseUrl = "https://dev.azure.com/$organization"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
}

$projectApiUrl = "$baseUrl/$project/_apis/projects?api-version=6.0"
try {
    $response = Invoke-RestMethod -Uri $projectApiUrl -Headers $headers -Method Get
    Write-Host "Connection successful!" -ForegroundColor Green
} catch {
    Write-Host "Connection failed: $_" -ForegroundColor Red
}
```

### Scan Issues

- make sure you have read access to the resources you're trying to scan
- try running with a more limited scope (just repositories or just builds)
- check your output folder for partial results
- when all else fails, turn it off and on again (works for everything else, right?)

## Contributing

found a bug? have a feature request? want to contribute? great! please open an issue or submit a pull request. we're always looking for ways to make Dizzy better.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- coffee, energy drinks, and the occasional existential crisis
- everyone who's ever accidentally committed an API key to a public repo
- you, for reading this far into a readme file (seriously, don't you have actual work to do?)

now go forth and secure those Azure DevOps environments! 🚀