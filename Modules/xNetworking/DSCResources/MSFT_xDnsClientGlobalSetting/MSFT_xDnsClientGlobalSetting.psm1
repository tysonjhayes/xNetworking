# Import Localized Data
$script:localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDnsClientGlobalSetting' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

<#
    This is an array of all the parameters used by this resource.
#>
data ParameterList
{
    @(
        @{ Name = 'SuffixSearchList'; Type = 'String'  },
        @{ Name = 'UseDevolution';    Type = 'Boolean' },
        @{ Name = 'DevolutionLevel';  Type = 'Uint32'  }
    )
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.GettingDnsClientGlobalSettingsMessage)
        ) -join '' )

    # Get the current Dns Client Global Settings
    $DnsClientGlobalSetting = Get-DnsClientGlobalSetting `
        -ErrorAction Stop

    # Generate the return object.
    $ReturnValue = @{
        IsSingleInstance = 'Yes'
    }
    foreach ($parameter in $ParameterList)
    {
        $ReturnValue += @{ $parameter.Name = $DnsClientGlobalSetting.$($parameter.name) }
    } # foreach

    return $ReturnValue
} # Get-TargetResource

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance,

        [String[]]
        $SuffixSearchList,

        [Boolean]
        $UseDevolution,

        [Uint32]
        $DevolutionLevel
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.SettingDnsClientGlobalSettingMessage)
        ) -join '' )

    # Get the current Dns Client Global Settings
    $DnsClientGlobalSetting = Get-DnsClientGlobalSetting `
        -ErrorAction Stop

    # Generate a list of parameters that will need to be changed.
    $ChangeParameters = @{}
    foreach ($parameter in $ParameterList)
    {
        $ParameterSource = $DnsClientGlobalSetting.$($parameter.name)
        $ParameterNew = (Invoke-Expression -Command "`$$($parameter.name)")
        if ($PSBoundParameters.ContainsKey($parameter.Name) `
            -and (Compare-Object -ReferenceObject $ParameterSource -DifferenceObject $ParameterNew -SyncWindow 0))
        {
            $ChangeParameters += @{
                $($parameter.name) = $ParameterNew
            }
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.DnsClientGlobalSettingUpdateParameterMessage) `
                    -f $parameter.Name,$ParameterNew
                ) -join '' )
        } # if
    } # foreach
    if ($ChangeParameters.Count -gt 0)
    {
        # Update any parameters that were identified as different
        $null = Set-DnsClientGlobalSetting `
            @ChangeParameters `
            -ErrorAction Stop

        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.DnsClientGlobalSettingUpdatedMessage)
            ) -join '' )
    } # if
} # Set-TargetResource

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance,

        [String[]]
        $SuffixSearchList,

        [Boolean]
        $UseDevolution,

        [Uint32]
        $DevolutionLevel
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.TestingDnsClientGlobalSettingMessage)
        ) -join '' )

    # Flag to signal whether settings are correct
    [Boolean] $DesiredConfigurationMatch = $true

    # Get the current Dns Client Global Settings
    $DnsClientGlobalSetting = Get-DnsClientGlobalSetting `
        -ErrorAction Stop

    # Check each parameter
    foreach ($parameter in $ParameterList)
    {
        $ParameterSource = $DnsClientGlobalSetting.$($parameter.name)
        $ParameterNew = (Invoke-Expression -Command "`$$($parameter.name)")
        if ($PSBoundParameters.ContainsKey($parameter.Name) `
            -and (Compare-Object -ReferenceObject $ParameterSource -DifferenceObject $ParameterNew -SyncWindow 0)) {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.DnsClientGlobalSettingParameterNeedsUpdateMessage) `
                    -f $parameter.Name,$ParameterSource,$ParameterNew
                ) -join '' )
            $desiredConfigurationMatch = $false
        } # if
    } # foreach

    return $DesiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource
