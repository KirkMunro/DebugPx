using System.Collections;
using System.Collections.Generic;
using System.Linq;
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

        IScriptExtent commandExtent = null;
        Hashtable breakpointCommandMetadata = null;

        const string enterDebuggerCommandBreakpointMetadataId = "EnterDebuggerCommandBreakpointMetadata";

        protected override void BeginProcessing()
        {
            // Look up the extent for the invocation of this command
            commandExtent = MyInvocation.GetScriptPosition();

            // Determine which session state to use for script-scope variable management
            var sessionState = this.GetLoadedModule("DebugPx").Where(x => x.ModuleType == ModuleType.Script).FirstOrDefault()?.SessionState ?? SessionState;

            // Get a reference to the breakpoint command metadata hashtable (from the script-scope for the module)
            breakpointCommandMetadata = sessionState.PSVariable.GetValue(enterDebuggerCommandBreakpointMetadataId)?.Unwrap() as Hashtable;

            // Let the base class method do its work
            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {

            // If the breakpoint command breakpoint does not exist, return immediately
            var breakpointBreakpoint = breakpointCommandMetadata["Breakpoint"]?.Unwrap() as CommandBreakpoint;
            if (breakpointBreakpoint == null)
            {
                return;
            }

            // If we have a breakpoint and it is enabled, process the breakpoint
            if (breakpointBreakpoint.Enabled)
            {
                // If we're in the nested Enter-Debugger call, do nothing and let the breakpoint handle it
                object value = breakpointCommandMetadata["ConditionMet"]?.Unwrap();
                if (value is bool && (bool)value)
                {
                    // We only pass pipeline input through from the outer invocation of this cmdlet
                    return;
                }

                // Invoke the condition script block using internal APIs; this is the only way that allows
                // us to support invocation as if it is part of this command (same scope) while supporting
                // the debugger quit ("q") command
                List<object> results = ConditionScript.BetterInvoke(false, true, InputObject, MyInvocation, new object[0]);

                // If the script block condition passed, invoke our nested breakpoint command (the debugger will stop on it)
                if (LanguagePrimitives.ConvertTo<bool>(results))
                {
                    try
                    {
                        // Set a flag so that the debugger knows to stop on the breakpoint command
                        breakpointCommandMetadata["ConditionMet"] = true;

                        // If the breakpoint comes with a message, output the message to the host using warning colors and a special prefix
                        if (MyInvocation.BoundParameters.ContainsKey("Message"))
                        {
                            Host.UI.WriteLine("BREAKPOINT: " + Message);
                        }

                        // The following commands are somewhat magical. The first set of commands makes it appear to the script debugger
                        // that the empty script block we are about to invoke is in fact the current command that is being invoked. It is
                        // necessary so that when the debugger shows information relative to the breakpoint that is hit, it is the information
                        // relative to the current invocation. After the instrumented script block is created, it is invoked using an
                        // internal API that allows the debugger to stop on the breakpoint command.

                        // Use instrumentation of an AST to create an empty script block that appears like it is the command being invoked.
                        // This ensures that the proper position message is displayed when the debugger stops on Enter-Debugger, and that
                        // the script debugger shows the proper position when the list ("l") command is issued.
                        ScriptBlockAst scriptBlockAst = new ScriptBlockAst(commandExtent, null, new StatementBlockAst(commandExtent, new List<StatementAst>(), null), false);
                        ScriptBlock emptyScriptBlock = scriptBlockAst.GetScriptBlock();

                        // Invoke the empty script block (this allows the breakpoint to trigger, and this invocation method allows the "q"
                        // debugger command to work properly)
                        emptyScriptBlock.BetterInvoke(false, false, InputObject, MyInvocation, new object[0]);
                    }
                    finally
                    {
                        // Remove the flag so that the debugger only stops when the command is invoked internally
                        breakpointCommandMetadata["ConditionMet"] = false;
                    }
                }
            }

            // If the caller used the InputObject parameter, pass that down the pipeline if we got this far
            if (MyInvocation.BoundParameters.ContainsKey("InputObject"))
            {
                WriteObject(InputObject);
            }

            // Let the base class method do its work
            base.ProcessRecord();
        }
    }
}