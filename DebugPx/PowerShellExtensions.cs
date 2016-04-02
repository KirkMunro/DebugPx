using System.Management.Automation;

namespace DebugPx
{
    internal static class PowerShellExtensions
    {
        internal static object Unwrap(this object value)
        {
            return value is PSObject ? ((PSObject)value).BaseObject : value;
        }
    }
}
