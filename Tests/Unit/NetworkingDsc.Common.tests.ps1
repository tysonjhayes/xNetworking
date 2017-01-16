$script:ModuleName = 'NetworkingDsc.Common'

#region HEADER
# Unit Test Template Version: 1.1.0
[string] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\xNetworking'
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
Import-Module (Join-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'Modules' -ChildPath $script:ModuleName)) -ChildPath "$script:ModuleName.psm1") -Force
#endregion HEADER

# Begin Testing
try
{
    #region Pester Tests

    $LocalizedData = InModuleScope $script:ModuleName {
        $LocalizedData
    }

    #region Function Convert-CIDRToSubhetMask
    Describe "NetworkingDsc.Common\Convert-CIDRToSubhetMask" {
        Context 'Subnet Mask Notation Used "192.168.0.0/255.255.0.0"' {
            It 'Should Return "192.168.0.0/255.255.0.0"' {
                Convert-CIDRToSubhetMask -Address @('192.168.0.0/255.255.0.0') | Should Be '192.168.0.0/255.255.0.0'
            }
        }
        Context 'Subnet Mask Notation Used "192.168.0.10/255.255.0.0" resulting in source bits masked' {
            It 'Should Return "192.168.0.0/255.255.0.0" with source bits masked' {
                Convert-CIDRToSubhetMask -Address @('192.168.0.10/255.255.0.0') | Should Be '192.168.0.0/255.255.0.0'
            }
        }
        Context 'CIDR Notation Used "192.168.0.0/16"' {
            It 'Should Return "192.168.0.0/255.255.0.0"' {
                Convert-CIDRToSubhetMask -Address @('192.168.0.0/16') | Should Be '192.168.0.0/255.255.0.0'
            }
        }
        Context 'CIDR Notation Used "192.168.0.10/16" resulting in source bits masked' {
            It 'Should Return "192.168.0.0/255.255.0.0" with source bits masked' {
                Convert-CIDRToSubhetMask -Address @('192.168.0.10/16') | Should Be '192.168.0.0/255.255.0.0'
            }
        }
        Context 'Multiple Notations Used "192.168.0.0/16,10.0.0.24/255.255.255.0"' {
            $Result = Convert-CIDRToSubhetMask -Address @('192.168.0.0/16','10.0.0.24/255.255.255.0')
            It 'Should Return "192.168.0.0/255.255.0.0,10.0.0.0/255.255.255.0"' {
                $Result[0] | Should Be '192.168.0.0/255.255.0.0'
                $Result[1] | Should Be '10.0.0.0/255.255.255.0'
            }
        }
        Context 'Range Used "192.168.1.0-192.168.1.128"' {
            It 'Should Return "192.168.1.0-192.168.1.128"' {
                Convert-CIDRToSubhetMask -Address @('192.168.1.0-192.168.1.128') | Should Be '192.168.1.0-192.168.1.128'
            }
        }
        Context 'IPv6 Used "fe80::/112"' {
            It 'Should Return "fe80::/112"' {
                Convert-CIDRToSubhetMask -Address @('fe80::/112') | Should Be 'fe80::/112'
            }
        }
    }

 Describe "NetworkingDsc.Common\Test-ResourceProperty" {

            Mock Get-NetAdapter -MockWith { [PSObject]@{ Name = 'Ethernet' } }

            Context 'invoking with bad interface alias' {

                It 'should throw an InterfaceNotAvailable error' {
                    $Splat = @{
                        Address = '192.168.0.1'
                        InterfaceAlias = 'NotReal'
                        AddressFamily = 'IPv4'
                    }

                    $errorMessage = $($LocalizedData.InterfaceNotAvailableError) -f $Splat.InterfaceAlias

                    Mock -CommandName New-DeviceErrorException `
                        -MockWith {$true} `
                        -Verifiable `
                        -ParameterFilter {$Message -eq $errorMessage}

                    $null = Test-ResourceProperty @Splat

                    Assert-MockCalled -CommandName New-DeviceErrorException -Times 1 `
                        -ParameterFilter {$Message -eq $errorMessage}
                }
            }

            Context 'invoking with invalid IP Address' {

                It 'should throw an AddressFormatError error' {
                    $Splat = @{
                        Address = 'NotReal'
                        InterfaceAlias = 'Ethernet'
                        AddressFamily = 'IPv4'
                    }
                    # $errorId = 'AddressFormatError'
                    # $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    # $errorMessage = $($LocalizedData.AddressFormatError) -f $Splat.Address
                    # $exception = New-Object -TypeName System.InvalidOperationException `
                    #     -ArgumentList $errorMessage
                    # $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    #     -ArgumentList $exception, $errorId, $errorCategory, $null

                    # { Test-ResourceProperty @Splat } | Should Throw $ErrorRecord

                    $errorMessage = $($LocalizedData.AddressFormatError) -f $Splat.Address

                    Mock -CommandName New-InvalidArgumentException `
                        -MockWith {throw} `
                        -Verifiable `
                        -ParameterFilter {$Message -eq $errorMessage}

                    Mock -CommandName New-InvalidArgumentException `
                        -MockWith {$true} `
                        -Verifiable

                    $breakvar = $true;
                    $null = {Test-ResourceProperty @Splat -ErrorAction:SilentlyContinue}

                    Assert-MockCalled -CommandName New-InvalidArgumentException -Times 1 `
                        -ParameterFilter {$Message -eq $errorMessage}
                    Assert-MockCalled -CommandName New-InvalidArgumentException -Times 0
                        $breakvar = $true;
                }
            }

            Context 'invoking with IPv4 Address and family mismatch' {

                It 'should throw an AddressMismatchError error' {
                    $Splat = @{
                        Address = '192.168.0.1'
                        InterfaceAlias = 'Ethernet'
                        AddressFamily = 'IPv6'
                    }

                    $errorMessage = $($($LocalizedData.AddressIPv4MismatchError) -f $Splat.Address,$Splat.AddressFamily);

                    Mock -CommandName New-InvalidArgumentException `
                        -MockWith {$true} `
                        -Verifiable `
                        -ParameterFilter {$Message -eq $errorMessage}

                    $null = Test-ResourceProperty @Splat

                    Assert-MockCalled -CommandName New-InvalidArgumentException -Times 1 `
                        -ParameterFilter {$Message -eq $errorMessage}
                }
            }

            Context 'invoking with IPv6 Address and family mismatch' {

                It 'should throw an AddressMismatchError error' {
                    $Splat = @{
                        Address = 'fe80::'
                        InterfaceAlias = 'Ethernet'
                        AddressFamily = 'IPv4'
                    }

                    $errorMessage = $($($LocalizedData.AddressIPv6MismatchError) -f $Splat.Address,$Splat.AddressFamily);

                    Mock -CommandName New-InvalidArgumentException `
                        -MockWith {$true} `
                        -Verifiable `
                        -ParameterFilter {$Message -eq $errorMessage}

                    $null = Test-ResourceProperty @Splat

                    Assert-MockCalled -CommandName New-InvalidArgumentException -Times 1 `
                        -ParameterFilter {$Message -eq $errorMessage}
                }
            }

            Context 'invoking with valid IPv4 Addresses' {

                It 'should not throw an error' {
                    $Splat = @{
                        Address = '192.168.0.1'
                        InterfaceAlias = 'Ethernet'
                        AddressFamily = 'IPv4'
                    }
                    { Test-ResourceProperty @Splat } | Should Not Throw
                }
            }

            Context 'invoking with valid IPv6 Addresses' {

                It 'should not throw an error' {
                    $Splat = @{
                        Address = 'fe80:ab04:30F5:002b::1'
                        InterfaceAlias = 'Ethernet'
                        AddressFamily = 'IPv6'
                    }
                    { Test-ResourceProperty @Splat } | Should Not Throw
                }
            }
        }
    #endregion
}
finally
{
    #region FOOTER
    #endregion
}
