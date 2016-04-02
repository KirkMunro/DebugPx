<#############################################################################
The DebugPx module provides a set of commands that make it easier to debug
PowerShell scripts, functions and modules. These commands leverage the native
debugging capabilities in PowerShell (the callstack, breakpoints, error output
and the -Debug common parameter) and provide additional functionality that
these features do not provide, enabling a richer debugging experience.

Copyright 2016 Kirk Munro

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#############################################################################>

<#
.SYNOPSIS
    Sets the current debug mode for a command.
.DESCRIPTION
    The Set-CommandDebugMode command sets the current debug mode for a command. Debug modes include DebuggerHidden and DebuggerStepThrough.
.PARAMETER WhatIf
    Shows what would happen if the command was run unrestricted. The command is run, but any changes it would make are prevented, and text descriptions of those changes are written to the console instead.
.PARAMETER Confirm
    Prompts you for confirmation before any system changes are made using the command.
.INPUTS
    String
.OUTPUTS
    None
.NOTES
    The Get-/Set-CommandDebugMode commands are used to manage the debug mode settings on Windows PowerShell functions and filters. They have no effect on other types of commands.

    When a command is in DebuggerHidden mode, the debugger will not step into that command. When a command is in DebuggerStepThrough mode, the debugger will step through that command into other commands that it invoked that are not hidden from the debugger, without stepping into the lines within that command.

    To enable DebuggerHidden or DebuggerStepThrough on a function or script block, set the System.Diagnostics.DebuggerHidden or System.Diagnostics.DebuggerStepThrough attributes for that function or script block, respectively.
.EXAMPLE
    PS C:\> Set-CommandDebugMode -Module FormatPx -DebuggerHidden

    This command sets the debug mode for all functions in the FormatPx module to DebuggerHidden. By invoking this command, you're instructing the PowerShell debugger to keep these command internals hidden from the debugger, such that the debugger will not step into them.
.EXAMPLE
    PS C:\> function Invoke-ScriptBlock {param([ScriptBlock]$ScriptBlock) breakpoint; $ScriptBlock.Invoke()}
    PS C:\> Invoke-ScriptBlock {'When you run this, the debugger will stop inside the Invoke-ScriptBlock function on the breakpoint. Press c to let it finish executing.'}
    PS C:\> Set-CommandDebugMode -Name Invoke-ScriptBlock -DebuggerHidden
    PS C:\> Invoke-ScriptBlock {'This time the debugger will skip over any breakpoints in the Invoke-ScriptBlock function because the internals are hidden from the debugger, but it will still stop on breakpoints in the script block passed into the function because that script block is not hidden from the debugger. Press c to let it finish executing.'; breakpoint}

    The first command creates a function that invokes a script block that is passed into it. This function has a breakpoint set on the first line. The second command invokes that function, which stops on a breakpoint, as expected. After pressing c to continue, you can invoke the third command. The third command configures that function so that its internals are hidden from the debugger. The last command invokes the function again, but this time the breakpoint inside the function is ignored because it is hidden from the debugger. Note however that breakpoints in the script block that it invokes are not ignored unless those script blocks themselves have the debugger hidden attribute set on them.
.EXAMPLE
    PS C:\> function Test-Function {'Command 1'; 'Command 2'}
    PS C:\> function Test-DebuggerStepThrough {'Press s twice to step into the next command and note how you can only step into Test-Function when the DebuggerStepThrough attribute is not present or when that attribute is present and there is a breakpoint in that function. Press c to let it finish executing.'; breakpoint; Test-Function}
    PS C:\> Test-DebuggerStepThrough
    PS C:\> Set-CommandDebugMode -Name Test-Function -DebuggerStepThrough
    PS C:\> Test-DebuggerStepThrough
    PS C:\> function Test-Function {'Command 1'; breakpoint; 'Command 2'}
    PS C:\> Set-CommandDebugMode -Name Test-Function -DebuggerStepThrough
    PS C:\> Test-DebuggerStepThrough

    The first command creates a test function with two commands. The second command creates a test function to see how the DebuggerStepThrough attribute works. The third command invokes that function, and you can step into the first function using the debugger.

    The fourth command configures Test-Function such that the debugger will not step into it unless a breakpoint is set. The fifth command invokes the Test-DebuggerStepThrough function again, and this time stepping results in the debugger stepping over Test-Function.

    The sixth command redefines the test function with a breakpoint. The seventh command sets DebuggerStepThrough mode on that redefined function. When the last command is invoked, and you step through using the debugger, the debugger will step over the Test-Function however since there is a breakpoint, the debugger stops on the breakpoint in that function. From this point, stepping through the rest of the function works as normal.
.EXAMPLE
    PS C:\> Set-CommandDebugMode -Module DebugPx -DebuggerHidden:$false -DebuggerStepThrough:$false

    This command removes all debug mode options from all functions and filters that are exported by the DebugPx module. With these options removed, the debugger can then step into these functions if necessary.
.EXAMPLE
    PS C:\> Set-CommandDebugMode -Module DebugPx

    This command removes all debug mode options from all functions and filters that are exported by the DebugPx module. With these options removed, the debugger can then step into these functions if necessary.
.LINK
    Get-CommandDebugMode
.LINK
    Get-Command
#>
function Set-CommandDebugMode {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([System.Void])]
    [System.Diagnostics.DebuggerHidden()]
    param(
        # Sets the debug mode for commands with the specified name. Enter a name or name pattern. Wildcards are permitted.
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name = '*',

        # Sets the debug mode for commands that came from the specified modules. Enter the names of modules, or pass in module objects.
        [Parameter(Position=1, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('ModuleName')]
        [System.String[]]
        $Module,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $DebuggerHidden = $false,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $DebuggerStepThrough = $false
    )
    begin {
        try {
            #region Find the DebuggerHidden and DebuggerStepThrough properties, whether they are public or not.

            $debuggerHiddenProperty = [System.Management.Automation.ScriptBlock].GetProperty('DebuggerHidden',[System.Reflection.BindingFlags]'Public,NonPublic,Instance')
            $debuggerStepThroughProperty = [System.Management.Automation.ScriptBlock].GetProperty('DebuggerStepThrough',[System.Reflection.BindingFlags]'Public,NonPublic,Instance')

            #endregion

            #region Define a hashtable to store exported module functions.

            $exportedModuleFunctions = @{}

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            #region If the Module parameter is used, look up the list of exported functions in the module and prepare to splat the parameter later.

            $moduleParameter = @{}
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Module')) {
                $moduleParameter['Module'] = $Module
                if (-not $exportedModuleFunctions.ContainsKey($Module)) {
                    foreach ($item in Get-Module -Name $Module -ListAvailable) {
                        $exportedModuleFunctions[$item.Name] = $item.ExportedFunctions.Keys
                    }
                }
            }

            #endregion

            #region Process any functions or filters that match our search criteria.

            foreach ($command in Get-Command -CommandType Function,Filter -Name $Name -ErrorAction Ignore @moduleParameter) {
                #region Skip any non-exported functions when processing modules.

                if (-not [System.String]::IsNullOrEmpty($command.ModuleName) -and
                    $exportedModuleFunctions.ContainsKey($command.ModuleName) -and
                    ($exportedModuleFunctions[$command.ModuleName] -notcontains $command.Name)) {
                    continue
                }

                #endregion

                #region Now update the debug mode for commands acccording to whether or not ShouldProcess allows it.

                if ($PSCmdlet.ShouldProcess($command)) {
                    # You must "prime the pump" by walking through the Attributes collection before you check
                    # the values of DebuggerHidden or DebuggerStepThrough properties. Otherwise, the value of
                    # the boolean properties may report incorrectly (bug in PowerShell?).
                    foreach ($attribute in $command.ScriptBlock.Attributes) {}
                    # Once the pump is primed, you can set the values and they will stick.
                    $debuggerHiddenProperty.SetValue($command.ScriptBlock,$DebuggerHidden.IsPresent)
                    $debuggerStepThroughProperty.SetValue($command.ScriptBlock,$DebuggerStepThrough.IsPresent)
                }

                #endregion
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Set-CommandDebugMode

if (-not (Get-Alias -Name scmdm -ErrorAction Ignore)) {
    New-Alias -Name scmdm -Value Set-CommandDebugMode
    Export-ModuleMember -Alias scmdm
}
# SIG # Begin signature block
# MIIXyQYJKoZIhvcNAQcCoIIXujCCF7YCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/byYklc53Pd9OevzX47yVidK
# 2YGgghL8MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUrMIIEE6ADAgECAhAMazN+7i4fWwlOi2uN0bz4MA0GCSqGSIb3DQEBCwUAMHIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJ
# RCBDb2RlIFNpZ25pbmcgQ0EwHhcNMTUwNzA5MDAwMDAwWhcNMTYxMTEwMTIwMDAw
# WjBoMQswCQYDVQQGEwJDQTEQMA4GA1UECBMHT250YXJpbzEPMA0GA1UEBxMGT3R0
# YXdhMRowGAYDVQQKExFLaXJrIEFuZHJldyBNdW5ybzEaMBgGA1UEAxMRS2lyayBB
# bmRyZXcgTXVucm8wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQChKHoG
# aabXPO+dzyq2VCIkuIUJj5zHfIGqyRGD2OWtUUSrbZ5lbl4cIXgzCn2PUxVROeoo
# mAAUAQzEhG35QPHsGvvAA24kn/JvXL/2RcQBtoWroIyzo28UpYIwcgzaou9odfeb
# jkIwgRmmY9oc+agutOGE9ZFQ9VUOq24ZDW3sCcUY1f5d91bawRctqvD4SRJhd9cc
# 6ICEw5rsr1kMs1YlEdr/3QHahlrTkjukRPEMxbThzp5K28H7xyNDYTiSDSKuUABi
# J0rZ8QGN8lElt6g4omJ1+2/4hPmuwk16J+RPwZKE9JgP+xkP3nzoLxNh9H/+47TV
# 3n8X9pk4LtQZe64LAgMBAAGjggHFMIIBwTAfBgNVHSMEGDAWgBRaxLl7Kgqjpepx
# A8Bg+S32ZXUOWDAdBgNVHQ4EFgQU84QR229qzy+aB5XNBzCXkzdkqdswDgYDVR0P
# AQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGG
# L2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3Js
# MDWgM6Axhi9odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNz
# LWcxLmNybDBMBgNVHSAERTBDMDcGCWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxo
# dHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUH
# AQEEeDB2MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYI
# KwYBBQUHMAKGQmh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNI
# QTJBc3N1cmVkSURDb2RlU2lnbmluZ0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqG
# SIb3DQEBCwUAA4IBAQD1CbyvOZ3FjxiHimw8mwcNEMn74GinkGi+f2aCGRwH01Jj
# lJvjkkRKHezaAMhrK0xDmuQIanKMoJvWKi+JuzJHNhH1ZMUK7AoXjBhBmQuoqqtf
# KLbl+b5UK/iBeZX2IgUWYUaE33mr8mK/fJcQIzFrZKPY/eTRencOw8ioxLyRlp18
# mzHMV/1CH5BelGx7bBxXRXSNkLoeRy79ElPa85swSI8zI3ZMXTr6SPCZii4o/Stz
# EIK66lEVh0OGBTQWtbsWB7hqyKX1ja2PIQB6ycMgy4y5zbKzhjyX71TysyY5lgXE
# XmWCKeOqDUhbeMD0uMPNBZnnCJIlEOLhFe1aejSKMIIFMDCCBBigAwIBAgIQBAkY
# G1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQw
# IgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIw
# MDAwWhcNMjgxMDIyMTIwMDAwWjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhE
# aWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrb
# RPV/5aid2zLXcep2nQUut4/6kkPApfmJ1DcZ17aq8JyGpdglrA55KDp+6dFn08b7
# KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0sSgmuyRpwsJS8hRniolF1C2ho+mILCCV
# rhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6scKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXp
# dOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4TzrGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWO
# D8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IB
# zTCCAckwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1Ud
# HwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwTwYDVR0gBEgwRjA4BgpghkgB
# hv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9D
# UFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYEFFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8G
# A1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IB
# AQA+7A1aJLPzItEVyCx8JSl2qB1dHC06GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew
# 4fbRknUPUbRupY5a4l4kgU4QpO4/cY5jDhNLrddfRHnzNhQGivecRk5c/5CxGwcO
# kRX7uq+1UcKNJK4kxscnKqEpKBo6cSgCPC6Ro8AlEeKcFEehemhor5unXCBc2XGx
# DI+7qPjFEmifz0DLQESlE/DmZAwlCEIysjaKJAL+L3J+HNdJRZboWR3p+nRka7Lr
# ZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4GbT8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiF
# LpKR6mhsRDKyZqHnGKSaZFHvMYIENzCCBDMCAQEwgYYwcjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmlu
# ZyBDQQIQDGszfu4uH1sJTotrjdG8+DAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU3ju0sy+YbIcT
# 81GIQUDpEjy8ew4wDQYJKoZIhvcNAQEBBQAEggEASIySZY9VjhT8c7Nw/AFblwOB
# s+xUAM10GKwPoFMZmp6TCfSmgmlPv1nFfLsu16shYhjquww10an792So+MelOi98
# 8/c8ICVORFLqaAMBO/EL2AEmAvOekMb1EPAyGfI/bXvljIn9KiIprg+pBU+jqIPm
# +Pjhzavf9Xy/lBG5EzBFyu7IFof7ejh92pi40TmhwjzWoN0dFYk7fZ4sN0dR1GGj
# qqS/a7Nn93JpMpBTTi9aQchk6DlNmB9CF2Ime0O4nU0w9vuroU5jOK+p171OM8hD
# LfaFXiIgN7/9EttVnjFc8yAScqbIcm83HT9Lf26s6vuTbLjGLnac7LKEDf5hHKGC
# AgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIBATByMF4xCzAJBgNVBAYTAlVTMR0w
# GwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMg
# VGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcyAhAOz/Q4yP6/NW4E2GqYGxpQ
# MAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3
# DQEJBTEPFw0xNjA0MDIwMTMxMjdaMCMGCSqGSIb3DQEJBDEWBBTNXENcQNvYn1iI
# lQD0n5aPRlVrXjANBgkqhkiG9w0BAQEFAASCAQBeNKgFSxFX55fz81A6WeW+Dqmk
# AE80fvyzA7JNkxHw4UNRhpKORCCrGWw9pKloggdjFyxlyjzm1GnZTnS17TO3c1Vn
# KAEOOLyw7wzKe+QOj/Kmi3aTLnQCE2uANMGEzblTgDvYZgKD7vdZY8CFZK8b8mKK
# N+Dz9h5kUATTnVOhkGEz+pIjJiWFsHKhoNmv9I3dtuFs/gdjvf7Edj2i5CDjElW9
# hSai55FH3fETx8LaSnDMpwqkUBWW8hm3L8pWUjSp15hkJLtigMN0c0nPrx/f97++
# tPuotrx2sQDNQqX3Ta3Be47lTRwWhycJgTYhjur/z8qJ9R1veFzVMyUGtQEX
# SIG # End signature block
