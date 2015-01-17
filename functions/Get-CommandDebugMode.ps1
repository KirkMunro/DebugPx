<#############################################################################
The DebugPx module provides a set of commands that make it easier to debug
PowerShell scripts, functions and modules. These commands leverage the native
debugging capabilities in PowerShell (the callstack, breakpoints, error output
and the -Debug common parameter) and provide additional functionality that
these features do not provide, enabling a richer debugging experience.

Copyright 2015 Kirk Munro

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
    Gets the current debug mode for a command.
.DESCRIPTION
    The Get-CommandDebugMode command gets the current debug mode for a command. Debug modes include DebuggerHidden and DebuggerStepThrough.
.INPUTS
    String
.OUTPUTS
    DebugPx.CommandDebugMode
.NOTES
    The Get-/Set-CommandDebugMode commands are used to manage the debug mode settings on Windows PowerShell functions and filters. They have no effect on other types of commands.

    When a command is in DebuggerHidden mode, the debugger will not step into that command. When a command is in DebuggerStepThrough mode, the debugger will step through that command into other commands that it invoked that are not hidden from the debugger, without stepping into the lines within that command.

    To enable DebuggerHidden or DebuggerStepThrough on a function or script block, set the System.Diagnostics.DebuggerHidden or System.Diagnostics.DebuggerStepThrough attributes for that function or script block, respectively.
.EXAMPLE
    PS C:\> Get-CommandDebugMode

    This command returns the current debug mode for all functions and filters that are available in PowerShell.
.EXAMPLE
    PS C:\> Get-CommandDebugMode -Module DebugPx

    This command returns the current debug mode for all functions and filters that are exported by the DebugPx module.
.LINK
    Set-CommandDebugMode
.LINK
    Get-Command
#>
function Get-CommandDebugMode {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType('DebugPx.CommandDebugMode')]
    [System.Diagnostics.DebuggerHidden()]
    param(
        # Gets the debug mode for commands with the specified name. Enter a name or name pattern. Wildcards are permitted.
        [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name = '*',

        # Gets the debug mode for commands that came from the specified modules. Enter the names of modules, or pass in module objects.
        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Module
    )
    begin {
        try {
            $debuggerHiddenProperty = [System.Management.Automation.ScriptBlock].GetProperty('DebuggerHidden',[System.Reflection.BindingFlags]'Public,NonPublic,Instance')
            $debuggerStepThroughProperty = [System.Management.Automation.ScriptBlock].GetProperty('DebuggerStepThrough',[System.Reflection.BindingFlags]'Public,NonPublic,Instance')
            $moduleParameter = @{}
            $exportedModuleFunctions = @{}
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Module')) {
                $moduleParameter['Module'] = $Module
                foreach ($item in Get-Module -Name $Module -ListAvailable) {
                    $exportedModuleFunctions[$item.Name] = $item.ExportedFunctions.Keys
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {

            foreach ($command in Get-Command -CommandType Function,Filter -Name $Name -ErrorAction Ignore @moduleParameter) {
                # When processing modules, skip non-exported functions.
                if (-not [System.String]::IsNullOrEmpty($command.ModuleName) -and
                    $exportedModuleFunctions.ContainsKey($command.ModuleName) -and
                    ($exportedModuleFunctions[$command.ModuleName] -notcontains $command.Name)) {
                    continue
                }
                # You must "prime the pump" by walking through the Attributes collection before you check
                # the values of DebuggerHidden or DebuggerStepThrough properties. Otherwise, the value of
                # the boolean properties may report incorrectly (bug in PowerShell?).
                foreach ($attribute in $command.ScriptBlock.Attributes) {}
                # Once the pump is primed, we can return objects containing command debug mode information.
                [pscustomobject]@{
                             PSTypeName = 'DebugPx.CommandDebugMode'
                                   Name = $command.Name
                         DebuggerHidden = $debuggerHiddenProperty.GetValue($command.ScriptBlock)
                    DebuggerStepThrough = $debuggerStepThroughProperty.GetValue($command.ScriptBlock)
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Get-CommandDebugMode

if (-not (Get-Alias -Name gcmdm -ErrorAction Ignore)) {
    New-Alias -Name gcmdm -Value Get-CommandDebugMode
    Export-ModuleMember -Alias gcmdm
}