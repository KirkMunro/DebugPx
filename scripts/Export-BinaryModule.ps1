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

# Export the cmdlets that are defined in the nested module
Export-ModuleMember -Cmdlet Invoke-IfDebug,Enter-Debugger

# Define an ifdebug alias so that using conditional debug blocks is more natural.
Set-Alias -Force -Name ifdebug -Value Invoke-IfDebug
Export-ModuleMember -Alias ifdebug

# Define a breakpoint alias so that setting breakpoints is more natural.
Set-Alias -Force -Name breakpoint -Value Enter-Debugger
Export-ModuleMember -Alias breakpoint

# Define a bp alias so that setting breakpoints is even easier.
if (-not (Get-Alias -Name bp -ErrorAction Ignore)) {
    New-Alias -Name bp -Value breakpoint
    Export-ModuleMember -Alias bp
}