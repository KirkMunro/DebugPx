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

# Export the cmdlets that are defined in the nested module
Export-ModuleMember -Cmdlet Invoke-IfDebug,Suspend-Execution

# Define an ifdebug alias so that using conditional debug blocks is more natural.
Set-Alias -Force -Name ifdebug -Value Invoke-IfDebug
Export-ModuleMember -Alias ifdebug

# Define a breakpoint alias so that setting breakpoints is more natural.
Set-Alias -Force -Name breakpoint -Value Suspend-Execution
Export-ModuleMember -Alias breakpoint

# Define a bp alias so that setting breakpoints is even easier.
if (-not (Get-Alias -Name bp -ErrorAction Ignore)) {
    New-Alias -Name bp -Value breakpoint
    Export-ModuleMember -Alias bp
}