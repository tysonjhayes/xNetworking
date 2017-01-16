# Import Localized Data
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDNSServerAddress' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

######################################################################################
# The Get-TargetResource cmdlet.
# This function will get the present list of DNS ServerAddress DSC Resource
# schema variables on the system
######################################################################################
function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Address,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $InterfaceAlias,

        [Parameter(Mandatory)]
        [ValidateSet('IPv4', 'IPv6')]
        [String] $AddressFamily
    )

    Write-Verbose -Message ( @( "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingDNSServerAddressesMessage)
        ) -join '')

    $returnValue = @{
        Address = (Get-DnsClientServerAddress `
            -InterfaceAlias $InterfaceAlias `
            -AddressFamily $AddressFamily).ServerAddresses
        AddressFamily = $AddressFamily
        InterfaceAlias = $InterfaceAlias
    }

    $returnValue
}

######################################################################################
# The Set-TargetResource cmdlet.
# This function will set a new Server Address in the current node
######################################################################################
function Set-TargetResource
{
    param
    (
        #IP Address that has to be set
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Address,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $InterfaceAlias,

        [Parameter(Mandatory)]
        [ValidateSet('IPv4', 'IPv6')]
        [String] $AddressFamily,

        [Boolean] $Validate = $false
    )

    Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
        $($LocalizedData.ApplyingDNSServerAddressesMessage)
        ) -join '')

    #Get the current DNS Server Addresses based on the parameters given.
    $PSBoundParameters.Remove('Address')
    $PSBoundParameters.Remove('Validate')
    $currentAddress = (Get-DnsClientServerAddress @PSBoundParameters `
        -ErrorAction Stop).ServerAddresses

    #Check if the Server addresses are the same as the desired addresses.
    [Boolean] $addressDifferent = (@(Compare-Object `
            -ReferenceObject $currentAddress `
            -DifferenceObject $Address `
            -SyncWindow 0).Length -gt 0)

    if ($addressDifferent)
    {
        # Set the DNS settings as well
        $Splat = @{
            InterfaceAlias = $InterfaceAlias
            Address = $Address
            Validate = $Validate
        }
        Set-DnsClientServerAddress @Splat `
            -ErrorAction Stop

        Write-Verbose -Message ( @( "$($MyInvocation.MyCommand): "
            $($LocalizedData.DNSServersHaveBeenSetCorrectlyMessage)
            ) -join '' )
    }
    else
    {
        #Test will return true in this case
        Write-Verbose -Message ( @( "$($MyInvocation.MyCommand): "
            $($LocalizedData.DNSServersAlreadySetMessage)
            ) -join '' )
    }
}

######################################################################################
# The Test-TargetResource cmdlet.
# This will test if the given Server Address is among the current node's Server Address collection
######################################################################################
function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Address,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $InterfaceAlias,

        [Parameter(Mandatory)]
        [ValidateSet('IPv4', 'IPv6')]
        [String] $AddressFamily,

        [Boolean] $Validate = $false
    )
    # Flag to signal whether settings are correct
    [Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @( "$($MyInvocation.MyCommand): "
        $($LocalizedData.CheckingDNSServerAddressesMessage)
        ) -join '' )

    #Validate the Settings passed
    Foreach ($ServerAddress in $Address) {
        Test-ResourceProperty `
            -Address $ServerAddress `
            -AddressFamily $AddressFamily `
            -InterfaceAlias $InterfaceAlias
    }

    #Get the current DNS Server Addresses based on the parameters given.
    $currentAddress = (Get-DnsClientServerAddress `
        -InterfaceAlias $InterfaceAlias `
        -AddressFamily $AddressFamily `
        -ErrorAction Stop).ServerAddresses

    #Check if the Server addresses are the same as the desired addresses.
    [Boolean] $addressDifferent = (@(Compare-Object `
            -ReferenceObject $currentAddress `
            -DifferenceObject $Address `
            -SyncWindow 0).Length -gt 0)

    if ($addressDifferent)
    {
        $desiredConfigurationMatch = $false
        Write-Verbose -Message ( @( "$($MyInvocation.MyCommand): "
            $($LocalizedData.DNSServersNotCorrectMessage) `
                -f ($Address -join ','),($currentAddress -join ',')
            ) -join '' )
    }
    else
    {
        #Test will return true in this case
        Write-Verbose -Message ( @( "$($MyInvocation.MyCommand): "
            $($LocalizedData.DNSServersSetCorrectlyMessage)
            ) -join '' )
    }
    return $desiredConfigurationMatch
}

#######################################################################################
#  Helper functions
#######################################################################################

#######################################################################################

#  FUNCTIONS TO BE EXPORTED
Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource
