// Switching the default playback device.
//
// Windows has no public API for this. The IPolicyConfig interface below is undocumented and was worked out
// by the community over the years, so it may change in a future Windows version. Everything that depends on
// it is kept in this file. Only SetDefaultEndpoint is used; the other methods are declared because the
// vtable order must match.

using System;
using System.Runtime.InteropServices;

namespace Mixdock
{
    [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")]
    class PolicyConfigClientCom { }

    [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPolicyConfig
    {
        [PreserveSig] int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string device, out IntPtr format);
        [PreserveSig] int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string device, [MarshalAs(UnmanagedType.Bool)] bool getDefault, out IntPtr format);
        [PreserveSig] int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string device);
        [PreserveSig] int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string device, IntPtr endpointFormat, IntPtr mixFormat);
        [PreserveSig] int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string device, [MarshalAs(UnmanagedType.Bool)] bool getDefault, IntPtr defaultPeriod, IntPtr minimumPeriod);
        [PreserveSig] int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string device, IntPtr period);
        [PreserveSig] int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string device, IntPtr mode);
        [PreserveSig] int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string device, IntPtr mode);
        [PreserveSig] int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string device, [MarshalAs(UnmanagedType.Bool)] bool fxStore, ref PropertyKey key, IntPtr value);
        [PreserveSig] int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string device, [MarshalAs(UnmanagedType.Bool)] bool fxStore, ref PropertyKey key, IntPtr value);
        [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string device, int role);
        [PreserveSig] int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string device, [MarshalAs(UnmanagedType.Bool)] bool visible);
    }

    static class DefaultDevice
    {
        // Roles: 0 console (games, system), 1 multimedia (music, video), 2 communications (calls).
        // Setting all three is what the Windows sound settings do when you pick a device as default.
        public static void Set(string deviceId)
        {
            var policy = (IPolicyConfig)new PolicyConfigClientCom();
            try
            {
                for (int role = 0; role < 3; role++)
                {
                    int hr = policy.SetDefaultEndpoint(deviceId, role);
                    if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                }
            }
            finally { Marshal.ReleaseComObject(policy); }
        }
    }
}
