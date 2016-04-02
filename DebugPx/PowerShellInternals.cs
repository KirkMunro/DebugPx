using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Management.Automation;
using PSDebugger = System.Management.Automation.Debugger;
using System.Reflection;
using System.Management.Automation.Language;
using System.Collections;

namespace DebugPx
{
    internal static class PowerShellInternals
    {
        private static BindingFlags publicOrPrivateInstance = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;

        private enum ErrorHandlingBehaviour
        {
            WriteToCurrentErrorPipe = 1,
            WriteToExternalErrorPipe = 2,
            SwallowErrors = 3
        }

        internal static CommandInfo GetCommandInfo(this PSCmdlet psCmdlet)
        {
            return typeof(Cmdlet).GetProperty("CommandInfo", publicOrPrivateInstance)
                                ?.GetValue(psCmdlet) as CommandInfo;
        }

        internal static List<PSModuleInfo> GetLoadedModule(this PSCmdlet psCmdlet, string name)
        {
            var executionContext = typeof(PSCmdlet).GetProperty("Context", publicOrPrivateInstance)
                                                  ?.GetValue(psCmdlet, null);

            var modules = executionContext?.GetType()
                                           .GetProperty("Modules", publicOrPrivateInstance)
                                          ?.GetValue(executionContext, null);

            return modules?.GetType()
                           .GetMethod("GetModules", publicOrPrivateInstance, null, new Type[] { typeof(string[]), typeof(bool) }, null)
                          ?.Invoke(modules, new object[] { new string[] { name }, false }) as List<PSModuleInfo>;
        }

        internal static IScriptExtent GetScriptPosition(this InvocationInfo invocationInfo)
        {
            return typeof(InvocationInfo).GetProperty("ScriptPosition", publicOrPrivateInstance)
                                        ?.GetValue(invocationInfo) as IScriptExtent;
        }

        private static PSObject automationNull = new PSObject();

        internal static List<object> BetterInvoke(this ScriptBlock scriptBlock, bool useLocalScope, bool hideFromDebugger, object pipelineInput, InvocationInfo invocationInfo, params object[] args)
        {
            List<object> results = new List<object>();
            ArrayList legacyResults = new ArrayList();

            DebuggerHiddenAttribute addedAttribute = null;
            try
            {
                if (hideFromDebugger && !scriptBlock.Attributes.Exists(x => x is DebuggerHiddenAttribute))
                {
                    addedAttribute = new DebuggerHiddenAttribute();
                    scriptBlock.Attributes.Add(addedAttribute);
                }

                Assembly smaAssembly = typeof(PowerShell).Assembly;

                // For performance reasons, the constructor changed between PowerShell 3.0 and 5.0. To compensate for this change,
                // we try the new constructor first, and then try the old one if the new one wasn't there
                var internalPipeType = smaAssembly.GetType("System.Management.Automation.Internal.Pipe");
                var outputPipe = internalPipeType?.GetConstructor(publicOrPrivateInstance, null, new Type[] { typeof(List<object>) }, null)
                                                 ?.Invoke(new object[] { results });
                if (outputPipe == null)
                {
                    outputPipe = internalPipeType?.GetConstructor(publicOrPrivateInstance, null, new Type[] { typeof(ArrayList) }, null)
                                                 ?.Invoke(new object[] { legacyResults });
                }

                MethodInfo invokeWithPipeMethod = typeof(ScriptBlock).GetMethod("InvokeWithPipe", publicOrPrivateInstance);
                if (invokeWithPipeMethod == null)
                {
                    return null;
                }

                try
                {
                    // The InvokeWithPipe method had additional parameters added between PowerShell 3.0 and 5.0. To compensate for this
                    // change, we check the parameter count and invoke the method accordingly
                    int parameterCount = invokeWithPipeMethod.GetParameters().Length;
                    invokeWithPipeMethod.Invoke(
                        scriptBlock, 
                        parameterCount == 11 ? new object[] { useLocalScope, ErrorHandlingBehaviour.WriteToCurrentErrorPipe, pipelineInput, new object[] { pipelineInput }, automationNull, outputPipe, invocationInfo, true, null, null, args }
                                             : new object[] { useLocalScope, ErrorHandlingBehaviour.WriteToCurrentErrorPipe, pipelineInput, new object[] { pipelineInput }, automationNull, outputPipe, invocationInfo, args }
                    );
                }
                catch (Exception e)
                {
                    Type terminateExceptionType = smaAssembly.GetType("System.Management.Automation.TerminateException");
                    if (terminateExceptionType.IsInstanceOfType(e.InnerException))
                    {
                        // In order for PowerShell to properly terminate if a user quits the debugger by invoking
                        // the "q" command, we need to unwrap the outer reflection exception and throw the inner
                        // TerminateException exception back to the caller. PowerShell will handle the rest for us.
                        throw e.InnerException;
                    }

                    throw;
                }

                // If we retrieved pipeline output the legacy way, convert that to our List<object> result set
                if (legacyResults.Count > 0)
                {
                    foreach (var entry in legacyResults)
                    {
                        results.Add(entry);
                    }
                }

                return results;
            }
            finally
            {
                if (addedAttribute != null)
                {
                    scriptBlock.Attributes.Remove(addedAttribute);
                }
            }
        }

        internal static bool IsInBreakpoint(this PSDebugger debugger)
        {
            var result = typeof(PSDebugger).GetProperty("InBreakpoint", publicOrPrivateInstance)
                                          ?.GetValue(debugger);
            if (result != null)
            {
                return (bool)result;
            }

            return false;
        }
    }
}