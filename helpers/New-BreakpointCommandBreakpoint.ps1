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

function New-BreakpointCommandBreakpoint {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandBreakpoint])]
    param()
    try {
        #region Create a new breakpoint that will activate when the breakpoint command is invoked.

        # This also activates when the bp command or the Enter-Debugger command are invoked.
        $breakpoint = Set-PSBreakpoint -Command breakpoint -Action {
            [System.Diagnostics.DebuggerHidden()]
            param()
            if ([DebugPx.EnterDebuggerCommand]::BreakpointConditionMet) {
                break
            }
        }

        #endregion

        #region Set the breakpoint that will be monitored by the Enter-Debugger command.

        [DebugPx.EnterDebuggerCommand]::SetBreakpoint($breakpoint -as [System.Management.Automation.CommandBreakpoint])

        #endregion

        #region Return the breakpoint to the caller.

        $breakpoint

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}