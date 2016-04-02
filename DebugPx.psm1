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

[System.Diagnostics.DebuggerHidden()]
param()

#region Set up a module scope trap statement so that terminating errors actually terminate.

trap {throw $_}

#endregion

#region Initialize the module.

Invoke-Snippet -Name Module.Initialize

#endregion

#region Import public function definitions.

Invoke-Snippet -Name ScriptFile.Import -Parameters @{
    Path = Join-Path -Path $PSModuleRoot -ChildPath functions
}

#endregion

#region Export commands defined in nested modules.

. $PSModuleRoot\scripts\Export-BinaryModule.ps1

#endregion

#region Set up a hashtable for module-local storage of Enter-Debugger command breakpoint metadata.

$EnterDebuggerCommandBreakpointMetadata = @{
    # A flag that tracks whether or not the condition was met (for conditional breakpointing)
    ConditionMet = $false

    # The action that will be invoked when the breakpoint is hit
    Action = {
        [System.Diagnostics.DebuggerHidden()]
        param()
        if ($script:EnterDebuggerCommandBreakpointMetadata['ConditionMet']) {
            break
        }
    }

    # An event handler that will re-create the breakpoints used by this script if they are manually removed
    OnBreakpointUpdated = {
        param(
            [System.Object]$sender,
            [System.Management.Automation.BreakpointUpdatedEventArgs]$eventArgs
        )
        if (($eventArgs.UpdateType -eq [System.Management.Automation.BreakpointUpdateType]::Removed) -and
            ($eventArgs.Breakpoint.Id -eq $script:EnterDebuggerCommandBreakpointMetadata['Breakpoint'].Id)) {
            #region If the breakpoint command breakpoint was removed, re-create it and warn the user about the requirement.

            $enabled = $eventArgs.Breakpoint.Enabled
            Write-Warning -Message "The breakpoint command breakpoint is required by the DebugPx module and cannot be manually removed. You can disable this breakpoint by invoking ""Disable-EnterDebuggerCommand"", or you can remove it by invoking ""Remove-Module -Name DebugPx"". This breakpoint is currently $(if ($enabled) {'enabled'} else {'disabled'})."
            $script:EnterDebuggerCommandBreakpointMetadata['Breakpoint'] = Set-PSBreakpoint -Command Enter-Debugger -Action $script:EnterDebuggerCommandBreakpointMetadata['Action'] -ErrorAction Stop
            if (-not $enabled) {
                Disable-EnterDebuggerCommand
            }

            #endregion
            break
        }
    }
}

# Add the breakpoint itself separately since it references the action which must already exist in the hashtable
$EnterDebuggerCommandBreakpointMetadata['Breakpoint'] = Set-PSBreakpoint -Command Enter-Debugger -Action $script:EnterDebuggerCommandBreakpointMetadata['Action'] -ErrorAction Stop

#endregion

#region If we are not in an interactive session, disable the breakpoints by default.

if (-not [System.Environment]::UserInteractive) {
    Disable-EnterDebuggerCommand
}

#endregion

#region Activate the OnBreakpointUpdated event handler.

$Host.Runspace.Debugger.add_BreakpointUpdated($EnterDebuggerCommandBreakpointMetadata['OnBreakpointUpdated'])

#endregion

#region Clean-up the module when it is removed.
    
$PSModule.OnRemove = {
    #region Deactivate the OnBreakpointUpdated event handler.

    $Host.Runspace.Debugger.remove_BreakpointUpdated($script:EnterDebuggerCommandBreakpointMetadata['OnBreakpointUpdated'])

    #endregion

    #region Remove the breakpoint that is used by this module.

    Remove-PSBreakpoint -Breakpoint $script:EnterDebuggerCommandBreakpointMetadata['Breakpoint'] -ErrorAction Ignore

    #endregion
}

#endregion