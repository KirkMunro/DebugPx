## DebugPx

### Overview

This is a module that everyone using PowerShell 3.0 or later should use.

The DebugPx module provides a set of commands that make it easier to debug
PowerShell scripts, functions and modules. These commands leverage the native
debugging capabilities in PowerShell (the callstack, breakpoints, error output
and the -Debug common parameter) and provide additional functionality that
these features do not provide, enabling a richer debugging experience.

### Minimum requirements

PowerShell 3.0
SnippetPx module

### License and Copyright

Copyright (c) 2014 Kirk Munro.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License in the
license folder that is included in the ScsmPx module. If not, see
<https://www.gnu.org/licenses/gpl.html>.

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
Enable-BreakpointCommand or Disable-BreakpointCommand commands. By default the
breakpoint command is enabled when DebugPx is loaded in an interactive session.

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