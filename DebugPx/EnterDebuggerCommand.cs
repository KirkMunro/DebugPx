using System;
using System.Collections;
using System.Management.Automation;
using System.Management.Automation.Language;

namespace DebugPx
{
    [Cmdlet(
        VerbsCommon.Enter,
        "Debugger"
    )]
    [OutputType(typeof(PSObject))]
    public class EnterDebuggerCommand : PSCmdlet
    {
        [Parameter(
            Position = 0,
            HelpMessage = "The condition under which PowerShell will enter the debugger at a breakpoint at the current location."
        )]
        [ValidateNotNull()]
        [Alias("ScriptBlock", "sb")]
        public ScriptBlock ConditionScript = ScriptBlock.Create("$true");

        [Parameter(
            HelpMessage = "A message that you want output to the host when the breakpoint is triggered."
        )]
        [ValidateNotNullOrEmpty()]
        public string Message;

        [Parameter(
            ValueFromPipeline = true,
            HelpMessage = "The object that was input to the command, either by value (using this parameter) or through the pipeline."
        )]
        [ValidateNotNull()]
        public PSObject InputObject;

        protected static int? BreakpointId = null;
        public static bool BreakpointConditionMet = false;

        public static void SetBreakpoint(CommandBreakpoint bp)
        {
            // If the breakpoint is for the breakpoint command, update the internal id we watch
            if (String.Compare(bp.Command, "breakpoint", true) == 0)
            {
                BreakpointId = bp.Id;
            }
        }

        protected override void ProcessRecord()
        {
            // Create the object used to invoke PowerShell commands in the current runspace
            PowerShell ps = PowerShell.Create(RunspaceMode.CurrentRunspace);

            // If the breakpoint command breakpoint does not exist, return immediately
            if (BreakpointId == null)
            {
                return;
            }

            // Get the breakpoint command breakpoint
            ps.Commands.Clear();
            ps.AddCommand("Get-PSBreakpoint");
            ps.AddParameter("Id", BreakpointId);
            var results = ps.Invoke();
            if (ps.HadErrors)
            {
                foreach (ErrorRecord error in ps.Streams.Error)
                {
                    WriteError(error);
                }
            }
            // If the breakpoint command breakpoint was not found, return immediately
            if (results.Count == 0)
            {
                return;
            }

            // If we received something other than a command breakpoint, throw a terminating error
            CommandBreakpoint bp = results[0].BaseObject as CommandBreakpoint;
            if (bp == null)
            {
                ErrorRecord errorRecord = new ErrorRecord(
                    new CmdletInvocationException("Received an object from the Get-PSBreakpoint call that was not of type System.Management.Automation.CommandBreakpoint."),
                    "InvalidType",
                    ErrorCategory.InvalidType,
                    results[0].BaseObject.GetType()
                );
                ThrowTerminatingError(errorRecord);
            }
            
            // If we have a breakpoint and it is enabled, process the breakpoint
            if (bp.Enabled)
            {
                // Get the DebugPx module.
                ps.Commands.Clear();
                ps.AddCommand("Get-Module", false);
                ps.AddParameter("Name", "DebugPx");
                results = ps.Invoke();
                if (ps.HadErrors)
                {
                    foreach (ErrorRecord error in ps.Streams.Error)
                    {
                        WriteError(error);
                    }
                }

                // If the DebugPx module is not loaded, throw a terminating error
                if (results.Count != 1)
                {
                    ErrorRecord errorRecord = new ErrorRecord(
                        new InvalidOperationException("The DebugPx script module must be loaded before you invoke the breakpoint command."),
                        "InvalidOperation",
                        ErrorCategory.InvalidOperation,
                        results
                    );
                    ThrowTerminatingError(errorRecord);
                }

                // If we received something other than a PSModuleInfo object, throw a terminating error
                PSModuleInfo moduleInfo = results[0].BaseObject as PSModuleInfo;
                if (moduleInfo == null)
                {
                    ErrorRecord errorRecord = new ErrorRecord(
                        new CmdletInvocationException("Received an object from the Get-Module call that was not of type System.Management.Automation.PSModuleInfo."),
                        "InvalidType",
                        ErrorCategory.InvalidType,
                        results[0].BaseObject.GetType()
                    );
                    ThrowTerminatingError(errorRecord);
                }

                // If we didn't get back the script module, throw a terminating error
                if (moduleInfo.ModuleType != ModuleType.Script)
                {
                    ErrorRecord errorRecord = new ErrorRecord(
                        new InvalidOperationException("The DebugPx script module must be loaded before you invoke the breakpoint command."),
                        "InvalidOperation",
                        ErrorCategory.InvalidOperation,
                        moduleInfo
                    );
                    ThrowTerminatingError(errorRecord);
                }

                // If we're in the nested Enter-Debugger call, do nothing and let the breakpoint handle it
                if (EnterDebuggerCommand.BreakpointConditionMet)
                {
                    // We only pass pipeline input through from the outer invocation of this cmdlet
                    return;
                }

                // If we received pipeline input, we must set up the _ and PSItem variables as if using a process block
                if (MyInvocation.BoundParameters.ContainsKey("InputObject"))
                {
                    SessionState.PSVariable.Set("_", InputObject);
                    SessionState.PSVariable.Set("PSItem", InputObject);
                }

                // Ensure that we don't debug into the condition script by forcing the DebuggerHidden attribute if it is not already set
                string conditionScript;
                ScriptBlockAst conditionScriptAst = ConditionScript.Ast as ScriptBlockAst;
                if (conditionScriptAst.ParamBlock == null)
                {
                    conditionScript = "[System.Diagnostics.DebuggerHidden()]\nparam()\n" + ConditionScript.ToString();
                }
                else if (conditionScriptAst.ParamBlock.Find(ast => (ast is AttributeAst) && (string.Compare((ast as AttributeAst).TypeName.FullName, "System.Diagnostics.DebuggerHidden", true) == 0), true) == null)
                {
                    conditionScript = "[System.Diagnostics.DebuggerHidden()]`n" + ConditionScript.ToString();
                }
                else
                {
                    conditionScript = ConditionScript.ToString();
                }

                // Invoke the condition Script Block to see if we're going to enter the debugger at a breakpoint
                ps.Commands.Clear();
                ps.AddScript(conditionScript, false);
                results = ps.Invoke();
                if (ps.HadErrors)
                {
                    foreach (ErrorRecord error in ps.Streams.Error)
                    {
                        WriteError(error);
                    }
                }

                // If the script block condition passed, invoke our nested breakpoint command (the debugger will stop on it)
                if ((bool)LanguagePrimitives.ConvertTo(results, typeof(Boolean)))
                {
                    try
                    {
                        // Set a flag so that the debugger knows to stop on the breakpoint command
                        EnterDebuggerCommand.BreakpointConditionMet = true;

                        // If the breakpoint comes with a message, output the message to the host using warning colors and a special prefix
                        if (MyInvocation.BoundParameters.ContainsKey("Message"))
                        {
                            ps.Commands.Clear();
                            ps.AddCommand("Write-Host", false);
                            ps.AddParameter("Object", "BREAKPOINT: " + Message);
                            ps.Invoke();
                        }

                        // Now invoke the nested command with the same parameters, but throw away all output (this is only done to trigger a breakpoint)
                        ps.Commands.Clear();
                        ps.AddCommand("breakpoint", false);
                        foreach (string parameterName in MyInvocation.BoundParameters.Keys)
                        {
                            ps.AddParameter(parameterName, MyInvocation.BoundParameters[parameterName]);
                        }
                        ps.Invoke();
                    }
                    finally
                    {
                        // Remove the flag so that the debugger only stops when the command is invoked internally
                        EnterDebuggerCommand.BreakpointConditionMet = false;
                    }
                }
            }

            // If the caller used the InputObject parameter, pass that down the pipeline if we got this far
            if (MyInvocation.BoundParameters.ContainsKey("InputObject"))
            {
                WriteObject(InputObject);
            }
        }
    }
}