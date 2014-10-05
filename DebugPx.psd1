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

@{
      ModuleToProcess = 'DebugPx.psm1'

        ModuleVersion = '1.0.0.1'

                 GUID = '161b91e7-ca3d-40e2-8d0e-e00b31740f90'

               Author = 'Kirk Munro'

          CompanyName = 'Poshoholic Studios'

            Copyright = '© 2014 Kirk Munro'

          Description = 'The DebugPx module provides a set of commands that make it easier to debug PowerShell scripts, functions and modules. These commands leverage the native debugging capabilities in PowerShell (the callstack, breakpoints, error output and the -Debug common parameter) and provide additional functionality that these features do not provide, enabling a richer debugging experience.'

    PowerShellVersion = '3.0'
    
      RequiredModules = @(
                        'SnippetPx'
                        )

        NestedModules = @(
                        'DebugPx.dll'
                        )

      CmdletsToExport = @(
                        'Enter-Debugger'
                        'Invoke-IfDebug'
                        )

    FunctionsToExport = @(
                        'Disable-BreakpointCommand'
                        'Enable-BreakpointCommand'
                        )

      AliasesToExport = @(
                        'breakpoint'
                        'bp'
                        'dbpc'
                        'ebpc'
                        'ifdebug'
                        )

             FileList = @(
                        'DebugPx.psd1'
                        'DebugPx.psm1'
                        'DebugPx.dll'
                        'en-us\DebugPx.dll-Help.xml'
                        'functions\Disable-BreakpointCommand.ps1'
                        'functions\Enable-BreakpointCommand.ps1'
                        'helpers\New-BreakpointCommandBreakpoint.ps1'
                        'license\gpl-3.0.txt'
                        'scripts\Export-BinaryModule.ps1'
                        'scripts\Install-DebugPxModule.ps1'
                        'scripts\Uninstall-DebugPxModule.ps1'
                        )
}