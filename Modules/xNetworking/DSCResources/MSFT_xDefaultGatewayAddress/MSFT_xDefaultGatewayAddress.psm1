# Import Localized Data
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDefaultGatewayAddress' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

######################################################################################
# The Get-TargetResource cmdlet.
# This function will get the current Default Gateway Address
######################################################################################
function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (        
        [String]$Address,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$InterfaceAlias,

        [Parameter(Mandatory)]
        [ValidateSet('IPv4', 'IPv6')]
        [String]$AddressFamily
    )
    
    Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingDefaultGatewayAddressMessage)
        ) -join '' )
    
    # Use $AddressFamily to select the IPv4 or IPv6 destination prefix
    $DestinationPrefix = '0.0.0.0/0'
    if ($AddressFamily -eq 'IPv6')
    {
        $DestinationPrefix = '::/0'
    }
    # Get all the default routes
    $defaultRoutes = Get-NetRoute -InterfaceAlias $InterfaceAlias -AddressFamily `
        $AddressFamily -ErrorAction Stop | `
        Where-Object { $_.DestinationPrefix -eq $DestinationPrefix }

    $returnValue = @{
        AddressFamily = $AddressFamily
        InterfaceAlias = $InterfaceAlias
    }
    # If there is a Default Gateway defined for this interface/address family add it
    # to the return value.
    if ($defaultRoutes) {
        $returnValue += @{ Address = $DefaultRoutes.NextHop }
    } else {
        $returnValue += @{ Address = $null }
    }

    $returnValue
}

######################################################################################
# The Set-TargetResource cmdlet.
# This function will set the Default Gateway Address for the Interface/Family in the
# current node
######################################################################################
function Set-TargetResource
{
    param
    (
        [String]$Address,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$InterfaceAlias,

        [Parameter(Mandatory)]
        [ValidateSet('IPv4', 'IPv6')]
        [String]$AddressFamily
    )
    # Validate the parameters
    
    Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
        $($LocalizedData.ApplyingDefaultGatewayAddressMessage)
        ) -join '' )

    # Use $AddressFamily to select the IPv4 or IPv6 destination prefix
    $DestinationPrefix = '0.0.0.0/0'
    if ($AddressFamily -eq 'IPv6')
    {
        $DestinationPrefix = '::/0'
    }

    # Get all the default routes
    $defaultRoutes = @(Get-NetRoute `
        -InterfaceAlias $InterfaceAlias `
        -AddressFamily $AddressFamily `
        -ErrorAction Stop).Where( { $_.DestinationPrefix -eq $DestinationPrefix } )

    # Remove any existing default route
    foreach ($defaultRoute in $defaultRoutes) {
        Remove-NetRoute `
            -DestinationPrefix $defaultRoute.DestinationPrefix `
            -NextHop $defaultRoute.NextHop `
            -InterfaceIndex $defaultRoute.InterfaceIndex `
            -AddressFamily $defaultRoute.AddressFamily `
            -Confirm:$false -ErrorAction Stop
    }

    if ($Address)
    {
        # Set the correct Default Route
        # Build parameter hash table
        $parameters = @{
            DestinationPrefix = $DestinationPrefix
            InterfaceAlias = $InterfaceAlias
            AddressFamily = $AddressFamily
            NextHop = $Address
        }

        New-NetRoute @Parameters -ErrorAction Stop

        Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
            $($LocalizedData.DefaultGatewayAddressSetToDesiredStateMessage)
            ) -join '' )
    }
    else
    {
        Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
            $($LocalizedData.DefaultGatewayRemovedMessage)
            ) -join '' )
    }
}

######################################################################################
# The Test-TargetResource cmdlet.
# This will test if the given Address is set as the Gateway Server address for the
# Interface/Family in the current node
######################################################################################
function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [String]$Address,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$InterfaceAlias,

        [Parameter(Mandatory)]
        [ValidateSet('IPv4', 'IPv6')]
        [String]$AddressFamily
    )
    # Flag to signal whether settings are correct
    [Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
        $($LocalizedData.CheckingDefaultGatewayAddressMessage)
        ) -join '' )

    Test-ResourceProperty @PSBoundParameters

    # Use $AddressFamily to select the IPv4 or IPv6 destination prefix
    $DestinationPrefix = '0.0.0.0/0'
    if ($AddressFamily -eq 'IPv6')
    {
        $DestinationPrefix = '::/0'
    }
    # Get all the default routes
    $defaultRoutes = @(Get-NetRoute `
        -InterfaceAlias $InterfaceAlias `
        -AddressFamily $AddressFamily `
        -ErrorAction Stop).Where( { $_.DestinationPrefix -eq $DestinationPrefix } )

    # Test if the Default Gateway passed is equal to the current default gateway
    if ($Address)
    {
        if ($defaultRoutes) {
            if (-not $defaultRoutes.Where( { $_.NextHop -eq $Address } ))
            {
                Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
                     $($LocalizedData.DefaultGatewayNotMatchMessage) -f $Address,$defaultRoutes.NextHop
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
            else
            {
                Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
                     $($LocalizedData.DefaultGatewayCorrectMessage)
                    ) -join '' )
            }
        }
        else
        {
            Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
                $($LocalizedData.DefaultGatewayDoesNotExistMessage) -f $Address
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    }
    else
    {
        # Is a default gateway address set?
        if ($defaultRoutes)
        {
            Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
                $($LocalizedData.DefaultGatewayExistsButShouldNotMessage)
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
        else
        {
            Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
                $($LocalizedData.DefaultGatewayExistsAndShouldMessage)
                'Default Gateway does not exist which is correct.'
                ) -join '' )
        }
    }

    return $desiredConfigurationMatch
}

#######################################################################################
#  Helper functions
#######################################################################################
function Test-ResourceProperty {
    # Function will check the Address details are valid and do not conflict with
    # Address family. Ensures interface exists.
    # If any problems are detected an exception will be thrown.
    [CmdletBinding()]
    param
    (
        [String]$Address,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$InterfaceAlias,

        [ValidateSet('IPv4', 'IPv6')]
        [String]$AddressFamily = 'IPv4'
    )

    if (-not (Get-NetAdapter | Where-Object -Property Name -EQ $InterfaceAlias ))
    {
        $errorId = 'InterfaceNotAvailable'
        $errorCategory = [System.Management.Automation.ErrorCategory]::DeviceError
        $errorMessage = $($LocalizedData.InterfaceNotAvailableError) -f $InterfaceAlias
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    if ($Address)
    {
        if (-not ([System.Net.IPAddress]::TryParse($Address, [ref]0)))
        {
            New-InvalidArgumentException `
                -Message $($LocalizedData.AddressFormatError) -f $Address `
                -ArgumentName 'AddressFormatError'
        }

        $detectedAddressFamily = ([System.Net.IPAddress]$Address).AddressFamily.ToString()
        if (($detectedAddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork.ToString()) `
            -and ($AddressFamily -ne 'IPv4'))
        {
            New-InvalidArgumentException `
                -Message $($LocalizedData.AddressIPv4MismatchError) -f $Address,$AddressFamily `
                -ArgumentName 'AddressMismatchError'
        }

        if (($detectedAddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6.ToString()) `
            -and ($AddressFamily -ne 'IPv6'))
        {
            New-InvalidArgumentException `
                -Message $($LocalizedData.AddressIPv6MismatchError) -f $Address,$AddressFamily `
                -ArgumentName 'AddressMismatchError'
        }
    }
} # Test-ResourceProperty
#######################################################################################

#  FUNCTIONS TO BE EXPORTED 
Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource
