## DebugPx

### Overview

This is a module that everyone using PowerShell 3.0 or later should use.

The DebugPx module provides a set of commands that make it easier to debug
PowerShell scripts, functions and modules. These commands leverage the native
debugging capabilities in PowerShell (the callstack, breakpoints, error output
and the -Debug common parameter) and provide additional functionality that
these features do not provide, enabling a richer debugging experience.

### Minimum requirements

- PowerShell 3.0
- SnippetPx module

### License and Copyright

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

### Installing the DebugPx module

DebugPx is dependent on the SnippetPx module. You can download and install the
latest versions of DebugPx and SnippetPx using any of the following methods:

#### PowerShellGet

If you don't know what PowerShellGet is, it's the way of the future for PowerShell
package management. If you're curious to find out more, you should read this:
<a href="http://blogs.msdn.com/b/mvpawardprogram/archive/2014/10/06/package-management-for-powershell-modules-with-powershellget.aspx" target="_blank">Package Management for PowerShell Modules with PowerShellGet</a>

Note that these commands require that you have the PowerShellGet module installed
on the system where they are invoked.

```powershell
# If you don’t have DebugPx installed already and you want to install it for all
# all users (recommended, requires elevation)
Install-Module DebugPx,SnippetPx

# If you don't have DebugPx installed already and you want to install it for the
# current user only
Install-Module DebugPx,SnippetPx -Scope CurrentUser

# If you have DebugPx installed and you want to update it
Update-Module
```

#### PowerShell 3.0 or Later

To install from PowerShell 3.0 or later, open a native PowerShell console (not ISE,
unless you want it to take longer), and invoke one of the following commands:

```powershell
# If you want to install DebugPx for all users or update a version already installed
# (recommended, requires elevation for new install for all users)
& ([scriptblock]::Create((iwr -uri http://bit.ly/Install-ModuleFromGitHub).Content)) -ModuleName DebugPx,SnippetPx

# If you want to install DebugPx for the current user
& ([scriptblock]::Create((iwr -uri http://bit.ly/Install-ModuleFromGitHub).Content)) -ModuleName DebugPx,SnippetPx -Scope CurrentUser
```

### Using the DebugPx module

The DebugPx module adds some core functionality to PowerShell version 3 or
later that really enriches the PowerShell debugging experience. In the current
release, there are two principle areas of focus for this module:

1. Breakpoints
2. Debug logging

PowerShell breakpoints have been available in PowerShell since version 2. There
are three types of breakpoints available in PowerShell: line breakpoints,
command breakpoints, and variable breakpoints. Unfortunately, each type of
breakpoint has usability challenges. Line breakpoints can only be set visually
if you are using PowerShell ISE, they can only be set on saved files, and they
will only be triggered if they are encountered as part of running a saved file.
Command breakpoints and variable breakpoints can only be set via the
Set-PSBreakpoint command, and they are not visible in scripts. Also, each of
these types of breakpoints are discarded between sessions, which can make
debugging difficult across reboots.

DebugPx attempts to fix these problems by providing a new breakpoint command in
PowerShell. The breakpoint command is an alias for Enter-Debugger. Personally,
even though I always recommend avoiding aliases in scripts, I recommend using
the breakpoint alias, or even the bp alias (bp is an alias for breakpoint),
because in practice I find them much easier to spot in scripts where they are
used. Regardless of which name you decide to use, these commands cause Windows
PowerShell to enter the debugger on the line where the command is used, even if
the script that is running is not saved, regardless of which PowerShell host you
are in. They can also be used in the middle of pipelines, they can be used
conditionally by providing an expression to evaluate, and they can display a
message about the breakpoint that is hit just before PowerShell enters the
debugger. Because you're actually adding lines to a script, they can be added
using any text editor (Sublime, Notepad++, etc.). This set of features makes
using breakpoints, and therefore debugging PowerShell, much, much easier. The
only type of breakpoint that this does not improve is variable breakpoints;
however, in my experience variable breakpoints are rarely used in practice, and
when they are used, Set-PSBreakpoint is sufficient.

The following examples help illustrate just how powerful the breakpoint command
can be. Give them a try and see how well they work for you. You can use them at
the interactive prompt or in a script you run (saved or not) or in a block of
script you invoke (for example, if you select a block in PowerShell ISE and press
F8 to invoke that block), and they will work in all of those scenarios. Here are
the examples:

```powershell
# Trigger a non-conditional breakpoint on the current line
breakpoint
# Trigger a conditional breakpoint on the current line
$x = 2
breakpoint {$x -eq 3} # this breakpoint will not trigger
# Trigger a non-conditional breakpoint in the middle of a pipeline
Get-Service u* | breakpoint | Stop-Service -WhatIf
# Trigger a conditional breakpoint in the middle of a pipeline
Get-Service w* | breakpoint {$_.Name -eq 'wuauserv'} | Start-Service -WhatIf
# Trigger a conditional breakpoint with a message to be written to the host
$x = -1
breakpoint {$x -lt 0} -Message '$x is less than 0! This is that obscure bug you were looking for!'
```

Note that the breakpoint command will only trigger breakpoints in interactive
sessions. It will not trigger breakpoints in background jobs, scheduled tasks,
etc. Also note that even when working interactively, you can choose when you
want to trigger on the breakpoint command and when you do not, by invoking the
Enable-EnterDebuggerCommand or Disable-EnterDebuggerCommand commands. By default
the breakpoint command is enabled when DebugPx is loaded in an interactive
session.

Another cmdlet that enhances debugging with breakpoints is Debug-Module. The
Debug-Module command will enter the debugger at the root of the specified
module scope (the script scope for the module). It will also change the current
location to the module base folder on disk. This allows inspection of any
internal script variables, invocation of commands internal to the module,
and quick inspection/modification of the files associated with the module.

To give Debug-Module a try, simply invoke the following command in PowerShell:

```powershell
# Change to the DebugPx base module folder and enter the debugger in the root
# "script" scope inside of DebugPx
Debug-Module -Name DebugPx
```

For more advanced debugging scenarios, you can look at the Get-CommandDebugMode
and Set-CommandDebugMode functions. These two functions allow you to turn on
or off the DebuggerHidden and DebuggerStepThrough attributes for individual
commands or for entire modules. When working with command breakpoints and
stepping through code, you may want to skip over entire script modules or
functions that you are not debugging. This can be controlled with these two
commands. To remove either of the DebuggerHidden and DebuggerStepThrough
attributes for any command, either pass $false to the associated switch
parameter or omit the switch parameter altogether (which defaults to false).

The other focus area for this module is debug logging. Since version 1,
PowerShell has had a command for debug logging: Write-Debug. Write-Debug will
write a message to the debug stream on the host when it is used in advanced
functions or cmdlets that are invoked with -Debug. It will also write its
message to the debug stream on the host if $DebugPreference is set to any
value other than SilentlyContinue or Ignore. The trouble with this is the
implementation. When you invoke a command with -Debug, PowerShell will set
the value of $DebugPreference to Inquire while it is invoking that command.
That means that you will be prompted each time Write-Debug is invoked to see
if you want to continue, stop, or suspend execution. In PowerShell version 1
that was useful since breakpoint support was missing back then, but since
PowerShell version 2, this behaviour has remained the same and its usefulness
is questionable. Also, even if $DebugPreference is set to SilentlyContinue or
Ignore, Write-Debug is still invoked and since Write-Debug is invoked, that
means the string parameter it accepts is always evaluated, whether you want
to see that information or not. That means you cannot have sections of script
that are only invoked when debugging, which discourages scripters from taking
extra steps to really get good debug information from the scripts, functions,
or modules they write.

The DebugPx module addresses these problems by adding an ifdebug command to
PowerShell. The ifdebug command is an alias for Invoke-IfDebug. Again, like
the breakpoint (or bp) commands, I recommend in this instance using the alias
because it is easier to spot in scripts (and because these commands seem to
work more like keywords than like functions). The ifdebug command allows a
PowerShell scripter to identify a block of script that will only be invoked
if DebugPreference is set to anything other than SilentlyContinue or Ingore,
and all regular (non-debug, non-verbose, etc.) output from that block of
script will automatically be sent to the debug stream, whether Write-Debug is
used or not.

Here is an example showing the ifdebug command in action:

```powershell
function Test-Something {
    [CmdletBinding()]
    param()
    ifdebug {
        # When gathering debug output, we may want much more information
        # relative to what a command is doing to be sent to the debug
        # stream for troubleshooting. We wouldn't want that information
        # gathered and then discarded though, because that would affect
        # performance.
        'Environment variables:'
        Get-ChildItem env:
        'Running processes:'
        Get-Process | Format-List *
        'Windows update service status:'
        Get-Service wuauserv | Format-List *
    }
}
# Invoke the command without actually gathering any debug information.
Measure-Command {Test-Something}
# Now invoke the command with debug information (this takes much longer)
Measure-Command {Test-Something -Debug}
```

This capability allows scripters to ship scripts that perform very well
normally, but that can also gather detailed debug information by simply
having them invoked with the Debug parameter. This can go a long way in
troubleshooting issues in customer environments, and being able to have
access to that debug information on demand without confusing users with
prompts asking them if they want to suspend execution or not makes it
much easier to troubleshoot issues when working with others.

There are more features already planned for this module, but it's off to
a great start already, and it has become the module I use more than any
other module I have. Please share your feedback and contribute if you
want to help this continue to evolve into something even greater!