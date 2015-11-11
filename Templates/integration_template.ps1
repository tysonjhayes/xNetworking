# Template for Integration Testing

# Copy to Program Files for WMF 4.0 Compatability as it can only find resources in a few known places.
$DSCModuleName = 'xNetworking'
$DSCResourceName = 'x<ResourceName>'
$moduleRoot = "${env:ProgramFiles}\WindowsPowerShell\Modules\$DSCModuleName"

if(-not (Test-Path -Path $moduleRoot))
{
    $null = New-Item -Path $moduleRoot -ItemType Directory
}
else
{
    # Copy the existing folder out to the temp directory to hold until the end of the run
    # Delete the folder to remove the old files.
    $tempLocation = Join-Path -Path $env:Temp -ChildPath $DSCModuleName
    Copy-Item -Path $moduleRoot -Destination $tempLocation -Recurse -Force
    Remove-Item -Path $moduleRoot -Recurse -Force
    $null = New-Item -Path $moduleRoot -ItemType Directory
}

Copy-Item -Path $PSScriptRoot\..\..\* -Destination $moduleRoot -Recurse -Force -Exclude '.git'

# Remove all copies of the module from memory so an old one is not used.
if (Get-Module -Name $DSCModuleName -All)
{
    Get-Module -Name $DSCModuleName -All | Remove-Module
}

# Import the Module to test.
Import-Module -Name $(Get-Item -Path (Join-Path $moduleRoot -ChildPath "$DSCModuleName.psd1")) -Force

<#
  This is to fix a problem in AppVoyer where we have multiple copies of the resource
  in two different folders. This should probably be adjusted to be smarter about how
  it finds the resources.
#>
if (($env:PSModulePath).Split(';') -ccontains $pwd.Path)
{
    $script:tempPath = $env:PSModulePath
    $env:PSModulePath = ($env:PSModulePath -split ';' | Where-Object {$_ -ne $pwd.path}) -join ';'
}

# Using try/finally to always cleanup even if something awful happens.
try
{
    <#
      This file exists so we can load the test file without necessarily having xNetworking in
      the $env:PSModulePath. Otherwise PowerShell will throw an error when reading the Pester File.
    #>
    $fileName = "$DSCResourceName.ps1"
    . $PSScriptRoot\$fileName
    Describe "$DSCResourceName_Integration" {
        It 'Should compile without throwing' {
            {
                [System.Environment]::SetEnvironmentVariable('PSModulePath',
                    $env:PSModulePath,[System.EnvironmentVariableTarget]::Machine)
                $DSCResourceName -OutputPath $env:Temp\$DSCResourceName
                Start-DscConfiguration -Path $env:Temp\$DSCResourceName -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            {Get-DscConfiguration} | Should Not throw
        }

        It 'Should have set the firewall and all the parameters should match' {
            # Vaidate the config was set correctly
        }

    }
}
finally
{
    # Set PSModulePath back to previous settings
    $env:PSModulePath = $script:tempPath;

    # Cleanup DSC Configuration
    # ie: Remove-NetFirewallRule -Name 'b8df0af9-d0cc-4080-885b-6ed263aaed67'

    # Remove the DSC Config File
    if (Test-Path -Path $env:Temp\$DSCResourceName)
    {
        Remove-Item -Path $env:Temp\$DSCResourceName -Recurse -Force
    }

    # Clean up Program Files after the test completes.
    Remove-Item -Path $moduleRoot -Recurse -Force

    # Restore previous versions, if it exists.
    if ($tempLocation)
    {
        $null = New-Item -Path $moduleRoot -ItemType Directory
        Copy-Item -Path $tempLocation -Destination "${env:ProgramFiles}\WindowsPowerShell\Modules" -Recurse -Force
        Remove-Item -Path $tempLocation -Recurse -Force
    }
}