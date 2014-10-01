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

# This script should only be invoked when you want to download the latest
# version of DebugPx from the GitHub page where it is hosted.

[CmdletBinding(SupportsShouldProcess=$true)]
[OutputType([System.Void])]
param(
    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $RemovePersistentData
)
try {
    #region Get the currently installed module (if there is one).

    Write-Progress -Activity 'Uninstalling DebugPx' -Status 'Looking for an installed DebugPx module.'
    $module = Get-Module -ListAvailable | Where-Object {$_.Guid -eq [System.Guid]'161b91e7-ca3d-40e2-8d0e-e00b31740f90'}
    if ($module -is [System.Array]) {
        [System.String]$message = 'More than one version of DebugPx is installed on this system. This is not supported. Manually remove the versions you are not using and then try again.'
        [System.Management.Automation.SessionStateException]$exception = New-Object -TypeName System.Management.Automation.SessionStateException -ArgumentList $message
        [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'SessionStateException',([System.Management.Automation.ErrorCategory]::InvalidOperation),'Uninstall-DebugPxModule'
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    #endregion

    #region Remove the module.

    if ($module) {
        Write-Progress -Activity 'Uninstalling DebugPx' -Status 'Unloading and removing the installed DebugPx module.'
        # Unload the module if it is currently loaded.
        if ($loadedModule = Get-Module | Where-Object {$_.Guid -eq $module.Guid}) {
            $loadedModule | Remove-Module -ErrorAction Stop
        }
        # Remove the currently installed module.
        Remove-Item -LiteralPath $module.ModuleBase -Recurse -Force -ErrorAction Stop
    }

    #endregion

    #region Now remove the persistent data for the module if the caller requested it.

    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('RemovePersistentData') -and $RemovePersistentData) {
        $moduleConfigFolder = Join-Path -Path ([System.Environment]::GetFolderPath('ApplicationData')) -ChildPath PoshoholicStudios\DebugPx
        if (Test-Path -LiteralPath $moduleConfigFolder) {
            Remove-Item -LiteralPath $moduleConfigFolder -Recurse -Force -ErrorAction Stop
        }
    }

    #endregion
} catch {
    throw
}