<#############################################################################
The DebugPx module provides a set of commands that make it easier to debug
PowerShell scripts, functions and modules. These commands leverage the native
debugging capabilities in PowerShell (the callstack, breakpoints, error output
and the -Debug common parameter) and provide additional functionality that
these features do not provide, enabling a richer debugging experience.

Copyright © 2014 Kirk Munro.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License in the
license folder that is included in the DebugPx module. If not, see
<https://www.gnu.org/licenses/gpl.html>.
#############################################################################>

function New-BreakpointCommandBreakpoint {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandBreakpoint])]
    param()
    try {
        #region Create a new breakpoint that will activate when the breakpoint command is invoked.

        # This also activates when the bp command or the Suspend-Execution command are invoked.
        $breakpoint = Set-PSBreakpoint -Command breakpoint -Action {
            [System.Diagnostics.DebuggerHidden()]
            param()
            if ([DebugPx.SuspendExecutionCommand]::BreakpointConditionMet) {
                break
            }
        }

        #endregion

        #region Set the breakpoint that will be monitored by the Suspend-Execution command.

        [DebugPx.SuspendExecutionCommand]::SetBreakpoint($breakpoint -as [System.Management.Automation.CommandBreakpoint])

        #endregion

        #region Return the breakpoint to the caller.

        $breakpoint

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}