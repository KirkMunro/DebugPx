using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace DebugPx
{
    [Cmdlet(
        VerbsDiagnostic.Debug,
        "Module"
    )]
    [OutputType(typeof(void))]
    public class DebugModuleCommand : PSCmdlet
    {
        [Parameter(
            Position = 0,
            Mandatory = true,
            HelpMessage = "The name of a script module in whose scope you want to enter the debugger."
        )]
        [ValidateNotNullOrEmpty()]
        [Alias(new string[] { "ModuleName" })]
        public string Name;

        protected override void EndProcessing()
        {
            // If the debugger is already in use, terminate with an error
            if (Runspace.DefaultRunspace.Debugger.IsInBreakpoint())
            {
                ThrowTerminatingError(
                    new ErrorRecord(
                        new InvalidRunspaceStateException("You cannot enter the debugger inside of a script module when you are already debugging."),
                        "DebuggerInUse",
                        ErrorCategory.ResourceBusy,
                        Runspace.DefaultRunspace.Debugger
                    )
                );
            }

            // Get the loaded module
            var matchingLoadedModules = this.GetLoadedModule(Name);

            // If the module is not loaded, load it into the global scope
            if (matchingLoadedModules == null || matchingLoadedModules.Count == 0)
            {
                using (var ps = PowerShell.Create(RunspaceMode.CurrentRunspace))
                {
                    string script = $"[System.Diagnostics.DebuggerHidden()]param(); Import-Module -Name {Name} -Global -PassThru -ErrorAction Stop";
                    matchingLoadedModules = ps.AddScript(script, false).Invoke<PSModuleInfo>().ToList();
                    if (ps.HadErrors)
                    {
                        foreach (ErrorRecord error in ps.Streams.Error)
                        {
                            WriteError(error);
                        }
                    }
                }
            }

            // Terminate with an error if the module is not a loaded script module
            if (matchingLoadedModules == null || !matchingLoadedModules.Any(x => x.ModuleType == ModuleType.Script))
            {
                ThrowTerminatingError(
                    new ErrorRecord(
                        new ItemNotFoundException(string.Format("Unable to find or load a script module by the name of {0}.", Name)),
                        "ModuleNotFound",
                        ErrorCategory.ObjectNotFound,
                        Name
                    )
                );
            }

            // Invoke the Enter-Debugger command to enter the debugger in the script module scope of the Name module
            using (var ps = PowerShell.Create(RunspaceMode.CurrentRunspace))
            {
                string script = $@"$module = . {{
    [System.Diagnostics.DebuggerHidden()]
    param()
    $module = Get-Module -Name {Name} -ErrorAction Stop | Where-Object {{$_.ModuleType -eq 'Script'}}
    if (-not $module) {{
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList @(
            New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList @(""Unable to find or load a script module by the name of {Name}."")
            'ModuleNotFound'
            [System.Management.Automation.ErrorCategory]::ObjectNotFound
            '{Name}'
        )
        throw $errorRecord
    }}
    Push-Location $module.ModuleBase -ErrorAction Stop
    $module
}}
try {{
    . ($module) Enter-Debugger
}} finally {{
    . {{
        [System.Diagnostics.DebuggerHidden()]
        param()
        Pop-Location
    }}
}}";
                ps.AddScript(script, false).Invoke();
                if (ps.HadErrors)
                {
                    foreach (ErrorRecord error in ps.Streams.Error)
                    {
                        WriteError(error);
                    }
                }
            }

            // Let the base class method do its work
            base.ProcessRecord();
        }
    }
}