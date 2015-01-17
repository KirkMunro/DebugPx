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
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name,

        # Sets the debug mode for commands that came from the specified modules. Enter the names of modules, or pass in module objects.
        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
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
                # Update commands according to ShouldProcess
                if ($PSCmdlet.ShouldProcess($command)) {
                    $debuggerHiddenProperty.SetValue($command.ScriptBlock,$DebuggerHidden.IsPresent)
                    $debuggerStepThroughProperty.SetValue($command.ScriptBlock,$DebuggerStepThrough.IsPresent)
                }
            }
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