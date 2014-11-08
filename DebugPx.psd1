<#############################################################################
The DebugPx module provides a set of commands that make it easier to debug
PowerShell scripts, functions and modules. These commands leverage the native
debugging capabilities in PowerShell (the callstack, breakpoints, error output
and the -Debug common parameter) and provide additional functionality that
these features do not provide, enabling a richer debugging experience.

Copyright 2014 Kirk Munro

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

@{
      ModuleToProcess = 'DebugPx.psm1'

        ModuleVersion = '1.0.0.5'

                 GUID = '161b91e7-ca3d-40e2-8d0e-e00b31740f90'

               Author = 'Kirk Munro'

          CompanyName = 'Poshoholic Studios'

            Copyright = 'Copyright 2014 Kirk Munro'

          Description = 'The DebugPx module provides a set of commands that make it easier to debug PowerShell scripts, functions and modules. These commands leverage the native debugging capabilities in PowerShell (the callstack, breakpoints, error output and the -Debug common parameter) and provide additional functionality that these features do not provide, enabling a richer debugging experience.'

    PowerShellVersion = '3.0'
    
        NestedModules = @(
                        'DebugPx.dll'
                        'SnippetPx'
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
                        'LICENSE'
                        'NOTICE'
                        'en-us\DebugPx.dll-Help.xml'
                        'functions\Disable-BreakpointCommand.ps1'
                        'functions\Enable-BreakpointCommand.ps1'
                        'helpers\New-BreakpointCommandBreakpoint.ps1'
                        'scripts\Export-BinaryModule.ps1'
                        'scripts\Install-DebugPxModule.ps1'
                        'scripts\Uninstall-DebugPxModule.ps1'
                        )

          PrivateData = @{
                            PSData = @{
                                Tags = 'breakpoint debug debugger write-debug set-psbreakpoint'
                                LicenseUri = 'http://apache.org/licenses/LICENSE-2.0.txt'
                                ProjectUri = 'https://github.com/KirkMunro/DebugPx'
                                IconUri = ''
                                ReleaseNotes = ''
                            }
                        }
}