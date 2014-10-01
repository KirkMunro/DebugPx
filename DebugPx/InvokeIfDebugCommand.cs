using System;
using System.Management.Automation;

namespace DebugPx
{
    [Cmdlet(
        VerbsLifecycle.Invoke,
        "IfDebug"
    )]
    [OutputType(typeof(PSObject))]
    public class InvokeIfDebugCommand : PSCmdlet
    {
        [Parameter(
            Position = 0,
			Mandatory = true,
            HelpMessage = "The debug script that will be invoked if DebugPreference is anything other than Ignore or SilentlyContinue."
        )]
        [ValidateNotNull()]
        [Alias("ScriptBlock", "sb")]
        public ScriptBlock DebugScript;

        [Parameter(
            ValueFromPipeline = true,
            HelpMessage = "The object that was input to the command, either by value (using this parameter) or through the pipeline."
        )]
        [ValidateNotNull()]
        public PSObject InputObject;

        protected override void ProcessRecord()
        {
			// Get the DebugPreference variable
			PSVariable debugPreferenceVariable = SessionState.PSVariable.Get("DebugPreference");

			// If the DebugPreference variable is not of type ActionPreference, send back a warning and return immediately
			if (!(debugPreferenceVariable.Value is ActionPreference))
            {
				WriteWarning("$DebugPreference is not of type System.Management.Automation.ActionPreference. The ifdebug command does not support this unexpected configuration.");
				return;
			}

			// If DebugPreference is set to SilentlyContinue or Ignore, return immediately
			ActionPreference debugPreference = (ActionPreference)debugPreferenceVariable.Value;
			if (ActionPreference.Ignore == debugPreference || ActionPreference.SilentlyContinue == debugPreference)
            {
                return;
            }

			// If DebugPreference is set to Inquire, temporarily set it to continue, and then invoke our script block
            ActionPreference originalDebugPreference = debugPreference;
			try
            {
				// Make sure the debug preference is not Inquire
				if (ActionPreference.Inquire == debugPreference)
                {
					debugPreference = ActionPreference.Continue;
					SessionState.PSVariable.Set("DebugPreference", debugPreference);
				}

				// Create the object used to invoke PowerShell commands in the current runspace
				PowerShell ps = PowerShell.Create(RunspaceMode.CurrentRunspace);

				// If we received pipeline input, we must set up the _ and PSItem variables as if using a process block
				if (MyInvocation.BoundParameters.ContainsKey("InputObject"))
				{
					SessionState.PSVariable.Set("_", InputObject);
					SessionState.PSVariable.Set("PSItem", InputObject);
				}

				// Invoke the debug Script Block and send all output in string format to Write-Debug
				ps.AddScript(DebugScript.ToString(), false);
                ps.AddCommand("Out-String");
                ps.AddParameter("Stream");
                ps.AddCommand("Write-Debug");
				ps.Invoke();
				if (ps.HadErrors)
				{
					foreach (ErrorRecord error in ps.Streams.Error)
					{
						WriteError(error);
					}
				}
			}
			finally
            {
				// Reset the DebugPreference value if necessary
				if (debugPreference != originalDebugPreference)
                {
					SessionState.PSVariable.Set("DebugPreference", originalDebugPreference);
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